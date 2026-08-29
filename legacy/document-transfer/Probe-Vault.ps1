<#
.SYNOPSIS
    Read-only reconnaissance of a Vault, so the bulk-action settings can be filled in
    from fact rather than guesswork. Writes nothing to Vault and nothing to Vault's
    file staging - it only reads.

.DESCRIPTION
    Answers the questions that decide whether Invoke-VaultDocumentAction.ps1 will work
    in this vault, all of which are vault-specific and cannot be looked up in the API
    documentation:

      1. Who am I, and what is my user id? (File Staging user folders are /u{user_id},
         and Admin vs non-Admin changes what a staging path has to look like.)
      2. What does my File Staging root and user folder actually contain?
      3. Which document fields exist, and which are editable?
      4. What are the document types, by label AND by name?
      5. What product records exist, with their ids?
      6. Does "Binder: No" have a working VQL equivalent here?
      7. How many documents does the view's filter set actually match?

    Everything lands in probe-output.txt, which is meant to be pasted back verbatim,
    plus the full field/type/product listings as CSVs alongside it.

.NOTES
    Windows PowerShell 5.1 compatible. Read-only: GET, plus POST /query and POST /auth.
    Reads VaultDNS / SessionId / ApiVersion / OutputRoot from documents.ini by default.
#>

[CmdletBinding()]
param(
    [string] $ConfigFile = '',
    [string] $VaultDNS   = '',
    [string] $OutputRoot = '',
    [ValidatePattern('^v\d+\.\d+$')]
    [string] $ApiVersion = 'v26.2',
    [string] $SessionId  = '',
    [pscredential] $Credential,

    # The view's filters, so the probe can count what they match before anything is
    # changed. Left blank, the counting section is skipped.
    [string]   $Product      = '',
    [string]   $ProductField = 'product__v',
    [string[]] $IncludeTypes = @(),
    [string[]] $ExcludeTypes = @(),
    [string]   $Where        = '',

    # How many product records and staging entries to print inline. The CSVs hold all.
    [int] $ListLimit = 40
)

$ScriptVersion = '2026.08.29-16'

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Field {
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

function ConvertTo-VqlLiteral {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return $Value.Replace('\', '\\').Replace("'", "\'")
}

function ConvertTo-StagingUrlPath {
    param([Parameter(Mandatory)][string]$Path)
    $clean = $Path.Replace('\', '/').Trim('/')
    if (-not $clean) { return '' }
    return (($clean -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}

# ---- configuration: same documents.ini, only the keys this script cares about --------

$ListKeys = @('IncludeTypes', 'ExcludeTypes')
if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
    $ConfigFile = Join-Path $here 'documents.ini'
}
if (Test-Path -LiteralPath $ConfigFile) {
    foreach ($line in (Get-Content -LiteralPath $ConfigFile)) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';') -or $t.StartsWith('[')) { continue }
        $eq = $t.IndexOf('='); if ($eq -lt 1) { continue }
        $k = $t.Substring(0, $eq).Trim(); $v = $t.Substring($eq + 1).Trim()
        if ($v -notmatch '^["'']') { $v = ($v -split '\s+[#;]', 2)[0].TrimEnd() }
        $v = [Environment]::ExpandEnvironmentVariables($v.Trim('"', "'"))
        if ([string]::IsNullOrWhiteSpace($v)) { continue }
        if ($PSBoundParameters.ContainsKey($k)) { continue }
        if (-not (Get-Variable -Name $k -Scope Script -ErrorAction SilentlyContinue)) { continue }
        if ($ListKeys -contains $k) { Set-Variable -Name $k -Value ([string[]]($v -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) -WhatIf:$false }
        else                        { Set-Variable -Name $k -Value $v -WhatIf:$false }
    }
}
if ([string]::IsNullOrWhiteSpace($VaultDNS))   { throw "VaultDNS is not set. Add it to $ConfigFile, or pass -VaultDNS." }
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = '.' }
$VaultDNS   = $VaultDNS -replace '^https?://', '' -replace '/+$', ''
$OutputRoot = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $OutputRoot))
# Trim the trailing separator, except on a drive root - "C:\" trimmed to "C:" means
# "the current directory on C:", which is not what anyone typing C:\ meant.
if ($OutputRoot.Length -gt 3) { $OutputRoot = $OutputRoot.TrimEnd('\') }
if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force -WhatIf:$false | Out-Null }

$OutFile     = Join-Path $OutputRoot 'probe-output.txt'
$FieldsCsv   = Join-Path $OutputRoot 'document-fields.csv'
$TypesCsv    = Join-Path $OutputRoot 'document-types.csv'
$ProductsCsv = Join-Path $OutputRoot 'products.csv'

$report = New-Object System.Collections.ArrayList
function Say {
    param([string]$Text = '')
    Write-Host $Text
    [void]$report.Add($Text)
}
function Save-Report { Set-Content -LiteralPath $OutFile -Value ($report -join "`r`n") -Encoding UTF8 -WhatIf:$false }

# ---- session ------------------------------------------------------------------------

$script:BaseUrl     = "https://$VaultDNS/api/$ApiVersion"
$script:SessionId   = $SessionId
$script:SessionFile = ''

# session.txt: written by login.bat / Get-VaultSession.ps1 so a run does not have to
# prompt again. Only consulted when SessionId is blank; an explicit SessionId wins.
if ([string]::IsNullOrWhiteSpace($script:SessionId)) {
    $sessionHere = $PSScriptRoot
    if (-not $sessionHere) { $sessionHere = (Get-Location).ProviderPath }
    $sessionFile = Join-Path $sessionHere 'session.txt'
    if (Test-Path -LiteralPath $sessionFile) {
        $cached = ("$(Get-Content -LiteralPath $sessionFile -Raw)").Trim()
        if ($cached) { $script:SessionId = $cached; $script:SessionFile = $sessionFile }
    }
}

function Invoke-Api {
    # Deliberately simpler than the main script's helper: no retry, no re-auth. A probe
    # that quietly retried would hide exactly the failures it exists to surface.
    param(
        [ValidateSet('GET','POST')][string]$Method = 'GET',
        [Parameter(Mandatory)][string]$Path,
        $Body,
        [string]$ContentType
    )
    $uri = if ($Path -match '^https?://') { $Path } elseif ($Path -match '^/api/') { "https://$VaultDNS$Path" } else { "$script:BaseUrl$Path" }
    $req = @{ Method = $Method; Uri = $uri; UseBasicParsing = $true; TimeoutSec = 300
              Headers = @{ Authorization = $script:SessionId; Accept = 'application/json' } }
    if ($null -ne $Body) { $req['Body'] = $Body }
    if ($ContentType)    { $req['ContentType'] = $ContentType }
    $resp = Invoke-WebRequest @req
    $json = $resp.Content | ConvertFrom-Json
    if ((Get-Field $json 'responseStatus') -eq 'FAILURE') {
        $errs = @(Get-Field $json 'errors' @())
        throw (($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; ')
    }
    return $json
}

function Try-Api {
    # Returns the response, or $null after printing why it failed. Used for every
    # optional probe so one 403 does not end the run.
    param([string]$Method = 'GET', [Parameter(Mandatory)][string]$Path, $Body, [string]$ContentType)
    try { return Invoke-Api -Method $Method -Path $Path -Body $Body -ContentType $ContentType }
    catch {
        $m = "$_"
        if ($m.Length -gt 300) { $m = $m.Substring(0, 300) + '...' }
        Say "      ERROR: $m"
        return $null
    }
}

Say "=============================================================================="
Say " VEEVA VAULT PROBE - read only"
Say " Vault : $VaultDNS"
Say " API   : $ApiVersion"
Say " Script: Probe-Vault.ps1 $ScriptVersion"
Say " When  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') local"
Say "=============================================================================="
Say ''

# ---- 1. who am I --------------------------------------------------------------------

Say '[1] AUTHENTICATION'
if (-not $script:SessionId) {
    if (-not $Credential) { $Credential = Get-Credential -Message "Vault credentials for $VaultDNS" }
    try {
        $auth = Invoke-RestMethod -Method Post -Uri "$script:BaseUrl/auth" `
                    -Body @{ username = $Credential.UserName; password = $Credential.GetNetworkCredential().Password } `
                    -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' }
        if ((Get-Field $auth 'responseStatus') -ne 'SUCCESS') { throw ($auth | ConvertTo-Json -Depth 5 -Compress) }
        $sid = "$(Get-Field $auth 'sessionId' '')"
        if (-not $sid) { throw "no sessionId returned. Vault said: $($auth | ConvertTo-Json -Depth 5 -Compress)" }
        $script:SessionId = $sid
        Say "      logged in OK   vaultId=$(Get-Field $auth 'vaultId' '?')  userId=$(Get-Field $auth 'userId' '?')"
        Say '      tip: run login.bat once to cache the session and stop the prompts'
    }
    catch { Say "      LOGIN FAILED: $_"; Save-Report; exit 1 }
}
elseif ($script:SessionFile) { Say '      using the cached session from session.txt' }
else { Say '      using the session id from documents.ini' }

$userId = ''; $isAdmin = $null
$me = Try-Api -Path '/objects/users/me'
if ($me) {
    $u = Get-Field (@(Get-Field $me 'users' @()) | Select-Object -First 1) 'user' $null
    $userId  = "$(Get-Field $u 'id' '')"
    $profile = "$(Get-Field $u 'security_profile__v' '')"
    $isAdmin = ($profile -match 'vault_owner|system_admin')
    Say "      user_name__v       : $(Get-Field $u 'user_name__v' '')"
    Say "      id                 : $userId"
    Say "      security_profile__v: $profile"
    Say "      license_type__v    : $(Get-Field $u 'license_type__v' '')"
    Say ''
    Say "      -> File Staging user folder is /u$userId"
    if ($isAdmin) { Say '      -> Admin profile: staging paths must be absolute from the ROOT, e.g. /u{id}/wave1/f.pdf' }
    else          { Say '      -> Non-Admin: staging paths are relative to your own user folder, e.g. /wave1/f.pdf' }
}
Say ''

# ---- 2. file staging ----------------------------------------------------------------

function Show-Staging {
    param([string]$Path, [string]$Label)
    Say "      $Label"
    $p = ConvertTo-StagingUrlPath $Path
    $r = Try-Api -Path "/services/file_staging/items/$p`?recursive=false&limit=$ListLimit"
    if (-not $r) { return }
    $items = @(Get-Field $r 'data' @())
    if ($items.Count -eq 0) { Say '        (empty)'; return }
    foreach ($it in ($items | Select-Object -First $ListLimit)) {
        Say ('        {0,-6} {1,-46} {2}' -f "$(Get-Field $it 'kind' '')", "$(Get-Field $it 'name' '')", "$(Get-Field $it 'path' '')")
    }
    if ($items.Count -ge $ListLimit) { Say "        ... $ListLimit shown" }
}

Say '[2] FILE STAGING'
Show-Staging -Path '/' -Label 'root "/" :'
if ($userId) { Show-Staging -Path "/u$userId" -Label "user folder /u$userId :" }
Say ''

# ---- 3. document fields -------------------------------------------------------------

Say '[3] DOCUMENT FIELDS'
$props = Try-Api -Path '/metadata/objects/documents/properties'
if ($props) {
    $fields = @(Get-Field $props 'properties' @()) |
        Select-Object @{n='Name';e={Get-Field $_ 'name'}},
                      @{n='Label';e={Get-Field $_ 'label'}},
                      @{n='Type';e={Get-Field $_ 'type'}},
                      @{n='Editable';e={Get-Field $_ 'editable' $false}},
                      @{n='Required';e={Get-Field $_ 'required' $false}},
                      @{n='Repeating';e={Get-Field $_ 'repeating' $false}},
                      @{n='Queryable';e={Get-Field $_ 'queryable' $false}}
    $fields | Export-Csv -LiteralPath $FieldsCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    $editable = @($fields | Where-Object { $_.Editable }).Count
    Say "      $($fields.Count) field(s), $editable editable   [full list: document-fields.csv]"
}
Say ''

Say '[4] DOCUMENT TYPES'
$types = Try-Api -Path '/metadata/objects/documents/types'
if ($types) {
    $rows = @(Get-Field $types 'types' @()) |
        Select-Object @{n='Label';e={Get-Field $_ 'label'}},
                      @{n='Name';e={ ("$(Get-Field $_ 'value' '')" -split '/')[-1] }}
    $rows | Export-Csv -LiteralPath $TypesCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Say "      $($rows.Count) top-level type(s)"
    Say ''

    # The UI's "Document Types" filter lists types AND subtypes together, but
    # /metadata/objects/documents/types returns only the top level. Walk each type for
    # its subtypes, otherwise a subtype in ExcludeTypes reads as a typo when it is not.
    Say '      Reading subtypes...'
    $all = New-Object System.Collections.ArrayList
    foreach ($r in $rows) {
        [void]$all.Add([pscustomobject]@{ Level = 'type'; Label = $r.Label; Name = $r.Name; Parent = '' })
        $d = Try-Api -Path "/metadata/objects/documents/types/$($r.Name)"
        if (-not $d) { continue }
        foreach ($st in @(Get-Field $d 'subtypes' @())) {
            [void]$all.Add([pscustomobject]@{
                Level  = 'subtype'
                Label  = "$(Get-Field $st 'label' '')"
                Name   = ("$(Get-Field $st 'value' '')" -split '/')[-1]
                Parent = $r.Label
            })
        }
    }
    $all | Export-Csv -LiteralPath $TypesCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    $subCount = @($all | Where-Object { $_.Level -eq 'subtype' }).Count
    Say "      $($rows.Count) type(s) + $subCount subtype(s)   [full list: document-types.csv]"
    Say ''
    $check = if ($IncludeTypes.Count) { $IncludeTypes } else { $ExcludeTypes }
    $word  = if ($IncludeTypes.Count) { 'keeps' } else { 'excludes' }
    Say "      The ones the view $word - confirm every one of these is spelled right:"
    foreach ($want in $check) {
        $hit = @($all | Where-Object { $_.Label -eq $want })
        if ($hit.Count) {
            $h = $hit[0]
            if ($h.Level -eq 'type') { Say ('        OK       "{0}"  type, name {1}' -f $want, $h.Name) }
            else {
                Say ('        SUBTYPE  "{0}"  subtype of "{1}", name {2}' -f $want, $h.Parent, $h.Name)
                Say ('                 -> filter this with subtype__v, NOT type__v' )
            }
        }
        else {
            $near = @($all | Where-Object { $_.Label -like "*$want*" -or $want -like "*$($_.Label)*" } | Select-Object -First 3)
            $hint = if ($near.Count) { '  did you mean: ' + (($near | ForEach-Object { '"' + $_.Label + '"' }) -join ', ') } else { '' }
            Say ('        NO MATCH "{0}"{1}' -f $want, $hint)
        }
    }
    if (@($check | Where-Object { $t = $_; @($all | Where-Object { $_.Label -eq $t -and $_.Level -eq 'subtype' }).Count }).Count) {
        Say ''
        Say '      Subtypes cannot go in ExcludeTypes - that builds type__v != ... clauses.'
        Say '      Put them in Where instead, e.g.  Where = subtype__v != ''Label One'' AND subtype__v != ''Label Two'''
    }
}
Say ''

# ---- 5. products --------------------------------------------------------------------

Say '[5] PRODUCT RECORDS'
$prod = Try-Api -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
            -Body @{ q = 'SELECT id, name__v FROM product__v'; pagesize = 1000 }
if ($prod) {
    $rows = @(Get-Field $prod 'data' @()) | Select-Object @{n='Id';e={Get-Field $_ 'id'}}, @{n='Name';e={Get-Field $_ 'name__v'}}
    $rows | Export-Csv -LiteralPath $ProductsCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Say "      $($rows.Count) product record(s)   [full list: products.csv]"
    foreach ($r in ($rows | Select-Object -First $ListLimit)) { Say ('        {0,-22} {1}' -f $r.Id, $r.Name) }
    if ($rows.Count -gt $ListLimit) { Say "        ... $($rows.Count - $ListLimit) more in products.csv" }
}
Say ''

# ---- 6. does the binder filter work here --------------------------------------------

Say '[6] BINDER FILTER'
Say '      The UI Binder: No filter has no documented VQL equivalent - binder__v is a'
Say '      pseudo-field on Retrieve Documents. Testing whether it is queryable here:'
$b = Try-Api -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
         -Body @{ q = 'SELECT id FROM documents WHERE binder__v = false'; pagesize = 1 }
if ($b) {
    $t = Get-Field (Get-Field $b 'responseDetails' $null) 'total' '?'
    Say "      WORKS - 'binder__v = false' is queryable ($t non-binder document(s))"
    Say '      -> put  Where = binder__v = false  in documents.ini'
}
else {
    Say '      -> the query did not come back. If the error above is a VQL error, this'
    Say '         vault cannot filter on binder__v: exclude binder document types via'
    Say '         ExcludeTypes instead. If it is a network or session error, fix that'
    Say '         and re-run - this section proves nothing until the query actually runs.'
}
Say ''

# ---- 7. what the view matches -------------------------------------------------------

Say '[7] THE VIEW, AS VQL'
$clauses = New-Object System.Collections.ArrayList
if ($Product) { [void]$clauses.Add("$ProductField = '$(ConvertTo-VqlLiteral $Product)'") }
if ($IncludeTypes.Count) {
    $list = ($IncludeTypes | Where-Object { $_ } | ForEach-Object { "'$(ConvertTo-VqlLiteral $_)'" }) -join ', '
    [void]$clauses.Add("type__v CONTAINS ($list)")
}
else { foreach ($t in $ExcludeTypes) { if ($t) { [void]$clauses.Add("type__v != '$(ConvertTo-VqlLiteral $t)'") } } }
if ($Where) { [void]$clauses.Add("($Where)") }

$q = 'SELECT id FROM documents'
if ($clauses.Count) { $q += " WHERE $($clauses -join ' AND ')" }
Say "      $q"
$c = Try-Api -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' -Body @{ q = $q; pagesize = 1 }
if ($c) {
    $t = Get-Field (Get-Field $c 'responseDetails' $null) 'total' '?'
    Say ''
    Say "      MATCHES: $t document(s)"
    Say '      -> compare this against the count the saved view shows in the Library.'
    Say '         If they disagree, the filters are not yet equivalent - do not run UPDATE.'
}
if (-not $Product) {
    Say ''
    Say '      NOTE: Product is blank in documents.ini, so this count is NOT product-scoped.'
    Say '            Take the Acthar id from section [5] and set it, then re-run this probe.'
}
Say ''

Say '=============================================================================='
Say ' END OF PROBE'
Say "=============================================================================="
Save-Report

Write-Host ''
Write-Host "Written to: $OutFile" -ForegroundColor Green
$alsoWrote = @($FieldsCsv, $TypesCsv, $ProductsCsv | Where-Object { Test-Path -LiteralPath $_ } |
                ForEach-Object { [IO.Path]::GetFileName($_) })
if ($alsoWrote.Count) { Write-Host "Also      : $($alsoWrote -join ', ')" -ForegroundColor Green }
else { Write-Host 'No CSVs were written - every lookup failed. Check the errors above.' -ForegroundColor Red }
Write-Host ''
Write-Host 'Paste the contents of probe-output.txt back. It contains no passwords and no' -ForegroundColor Yellow
Write-Host 'session id - but it does list document type, product and folder names, so give' -ForegroundColor Yellow
Write-Host 'it a read before sending it anywhere.' -ForegroundColor Yellow
