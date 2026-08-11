<#
.SYNOPSIS
    Imports exported submission dossiers into Veeva Vault RIM Submissions Archive,
    entirely on the File Staging server. Nothing is downloaded or uploaded.

.DESCRIPTION
    Bulk Submission Export leaves its output on File Staging, under
        /u{UserID}/Submissions Archive Export/{JobID}/...
    Import Submission can only read from one of two places:
        /SubmissionsArchive/{app}/{submission}                    folder, .zip or .tar.gz
        /u{ID}/Submissions Archive Import/{app}/{submission}      folder only, no archives
    so the exported dossiers are already on the server, just in the wrong location.

    For each dossier this script:
      1. Relocates it into /SubmissionsArchive/<application>/ with a File Staging move
         (PUT /items). Server-side: no bytes cross the network. Asynchronous, so the
         move job is polled to completion.
      2. Calls Import Submission on the matching submission__v record.
      3. Polls the import job, then retrieves the import results.
      4. Appends a row to a results CSV - file name, both staging paths, job ids,
         status, binder id/version and any validation messages.

    The archive -> submission mapping comes from export_results.csv, which the export
    wrote next to the dossiers. It is read directly off File Staging; you do not need a
    local copy, and nothing has to be typed in by hand.

    Re-runnable: dossiers already recorded as SUCCESS are skipped.

.PARAMETER ConfigFile
    All settings live in config.ini beside this script. Command line overrides it.

.NOTES
    Windows PowerShell 5.1 compatible (also runs on PowerShell 7).
    Endpoints, all relative to https://<VaultDNS>/api/<ApiVersion>:
      POST /auth
      GET  /services/file_staging/items/{item}?recursive=true      list the export
      GET  /services/file_staging/items/content/{item}             read export_results.csv
      POST /services/file_staging/items                            create target folder
      PUT  /services/file_staging/items/{item}                     move  (async, job id)
      POST /vobjects/submission__v/{id}/actions/import             import (async, job id)
      GET  /services/jobs/{job_id}                                 poll either job
      GET  /vobjects/submission__v/{id}/actions/import/{job_id}/results
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # ======================================================================================
    #  All configuration lives in ONE file: config.ini, next to this script.
    #  Precedence:  command line  >  config.ini  >  the defaults here
    # ======================================================================================

    [string]     $ConfigFile       = '',

    # ---- Required ----
    [string]     $VaultDNS         = '',

    # Staging folder holding the export, e.g. '/u5678/Submissions Archive Export/727301'
    [string]     $SourceStagingPath = '',

    # Local folder for the results CSV and log. Nothing else is written locally.
    [string]     $OutputRoot       = '',

    # ---- Vault ----
    [ValidatePattern('^v\d+\.\d+$')]
    [string]     $ApiVersion       = 'v26.2',

    # The ONLY place a session id is configured. Blank = log in and manage it for me.
    [string]     $SessionId        = '',

    # Import target root. Archives can only be imported from here.
    [string]     $StagingRoot      = '/SubmissionsArchive',

    # ---- Run mode ----
    [switch]     $GenerateManifest,
    [string]     $Manifest,

    # Staging path of export_results.csv. Blank = look for it under SourceStagingPath.
    [string]     $ExportResultsCsv,
    [string]     $IdColumn,
    [string]     $PathColumn,
    [switch]     $NameIsSubmissionId,

    # Return each dossier to its original export path after a successful import.
    # There is no copy operation in the File Staging API, so a move is otherwise one-way.
    [switch]     $MoveBack,

    [pscredential] $Credential,

    # ---- Advanced ----
    [string]     $LookupField      = 'name__v',
    [string]     $DefaultDossierFormatId,
    [string[]]   $Include          = @('*.zip', '*.tar.gz', '*.tgz'),
    [int]        $JobTimeoutMinutes = 120,
    [int]        $JobPollSeconds   = 20,
    [int]        $MaxRetries       = 4
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --------------------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------------------

function Get-Field {
    # Strict-mode-safe property read: missing property or empty value yields $Default.
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

function ConvertTo-StagingUrlPath {
    <#
      Escapes a staging path for use in a URL segment while keeping the separators.
      Export folders are literally named "Submissions Archive Export" - the spaces must
      be encoded or every request 404s.
    #>
    param([Parameter(Mandatory)][string]$Path)
    $clean = $Path.Replace('\', '/').Trim('/')
    return (($clean -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}

function Join-StagingPath {
    param([Parameter(Mandatory)][string]$Parent, [Parameter(Mandatory)][string]$Child)
    return ('/' + $Parent.Replace('\', '/').Trim('/') + '/' + $Child.Replace('\', '/').Trim('/'))
}

# --------------------------------------------------------------------------------------
# Configuration: one file, one load
# --------------------------------------------------------------------------------------

$IntKeys    = @('JobTimeoutMinutes', 'JobPollSeconds', 'MaxRetries')
$SwitchKeys = @('GenerateManifest', 'NameIsSubmissionId', 'MoveBack')
$ListKeys   = @('Include')

function Import-ConfigFile {
    param([Parameter(Mandatory)][string]$Path)
    $cfg = [ordered]@{}
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';') -or $t.StartsWith('[')) { continue }
        $eq = $t.IndexOf('=')
        if ($eq -lt 1) { continue }
        $k = $t.Substring(0, $eq).Trim()
        $v = $t.Substring($eq + 1).Trim().Trim('"', "'")
        $cfg[$k] = [Environment]::ExpandEnvironmentVariables($v)
    }
    return $cfg
}

$ConfigExplicit = $PSBoundParameters.ContainsKey('ConfigFile')
if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
    $ConfigFile = Join-Path $here 'config.ini'
}

$ConfigMode = ''
if (Test-Path -LiteralPath $ConfigFile) {
    $cfg = Import-ConfigFile -Path $ConfigFile
    foreach ($key in $cfg.Keys) {
        $value = $cfg[$key]
        if ($key -eq 'MODE') { $ConfigMode = $value.ToUpperInvariant(); continue }
        if ($PSBoundParameters.ContainsKey($key)) { continue }
        if (-not (Get-Variable -Name $key -Scope Script -ErrorAction SilentlyContinue)) {
            Write-Warning "config.ini: ignoring unknown setting '$key'"
            continue
        }
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        if     ($IntKeys    -contains $key) { Set-Variable -Name $key -Value ([int]$value) }
        elseif ($SwitchKeys -contains $key) { Set-Variable -Name $key -Value ([bool]($value -match '^(1|true|yes|on)$')) }
        elseif ($ListKeys   -contains $key) { Set-Variable -Name $key -Value ([string[]]($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) }
        else                                { Set-Variable -Name $key -Value $value }
    }
    switch ($ConfigMode) {
        'MANIFEST' { if (-not $PSBoundParameters.ContainsKey('GenerateManifest')) { $GenerateManifest = $true } }
        'DRYRUN'   { if (-not $PSBoundParameters.ContainsKey('WhatIf'))           { $WhatIfPreference = $true } }
        'IMPORT'   { }
        ''         { }
        default    { throw "config.ini: MODE must be MANIFEST, DRYRUN or IMPORT (got '$ConfigMode')." }
    }
}
elseif ($ConfigExplicit) { throw "Config file not found: $ConfigFile" }
else { Write-Warning "No config.ini found at $ConfigFile - relying on command-line arguments." }

foreach ($name in @('VaultDNS', 'SourceStagingPath', 'OutputRoot')) {
    if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $name -ValueOnly))) {
        throw "$name is not set. Add it to $ConfigFile, or pass -$name on the command line."
    }
}
$VaultDNS          = $VaultDNS -replace '^https?://', '' -replace '/+$', ''
$SourceStagingPath = '/' + $SourceStagingPath.Replace('\', '/').Trim('/')
$StagingRoot       = '/' + $StagingRoot.Replace('\', '/').Trim('/')

$OutputRoot = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $OutputRoot)).TrimEnd('\')
if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null }

$stamp         = Get-Date -Format 'yyyyMMdd-HHmmss'
$ResultsCsv    = Join-Path $OutputRoot 'import-results.csv'
$ManifestOut   = Join-Path $OutputRoot 'manifest.csv'
$TranscriptLog = Join-Path $OutputRoot "import-$stamp.log"

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line }
    }
    Add-Content -LiteralPath $TranscriptLog -Value $line -Encoding UTF8
}

# --------------------------------------------------------------------------------------
# Session id
#
# $script:SessionId is the single source of truth for the Vault session:
#   seeded here from the SessionId config value, written only by Connect-Vault,
#   read only by Invoke-VaultApi when it builds the Authorization header.
# No function takes a session id as an argument, which is what makes mid-run re-auth
# safe - the header is rebuilt from this variable on every attempt.
# --------------------------------------------------------------------------------------

$script:BaseUrl   = "https://$VaultDNS/api/$ApiVersion"
$script:SessionId = $SessionId
$script:Cred      = $Credential

function Connect-Vault {
    if (-not $script:Cred) { $script:Cred = Get-Credential -Message "Vault credentials for $VaultDNS" }
    $body = @{ username = $script:Cred.UserName; password = $script:Cred.GetNetworkCredential().Password }
    $r = Invoke-RestMethod -Method Post -Uri "$script:BaseUrl/auth" -Body $body `
            -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' }
    if ($r.responseStatus -ne 'SUCCESS') { throw "Authentication failed: $($r | ConvertTo-Json -Depth 5 -Compress)" }
    $script:SessionId = $r.sessionId
    Write-Log "Authenticated to $VaultDNS (vaultId $($r.vaultId), userId $($r.userId))" 'OK'
}

# --------------------------------------------------------------------------------------
# Core request helper
# --------------------------------------------------------------------------------------

function Invoke-VaultApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body,
        [string]$ContentType,
        [hashtable]$ExtraHeaders = @{},
        [int]$TimeoutSec = 600,
        [switch]$Raw                      # return the response body as text, not parsed JSON
    )

    $uri = if ($Path -match '^https?://') { $Path } else { "$script:BaseUrl$Path" }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $headers = @{ Authorization = $script:SessionId; Accept = if ($Raw) { '*/*' } else { 'application/json' } }
        foreach ($k in $ExtraHeaders.Keys) { $headers[$k] = $ExtraHeaders[$k] }

        try {
            $req = @{ Method = $Method; Uri = $uri; Headers = $headers; TimeoutSec = $TimeoutSec; UseBasicParsing = $true }
            if ($null -ne $Body) { $req['Body'] = $Body }
            if ($ContentType)    { $req['ContentType'] = $ContentType }

            $resp = Invoke-WebRequest @req

            $remaining = $resp.Headers['X-VaultAPI-BurstLimitRemaining']
            if ($remaining -and [int]$remaining -lt 200) {
                Write-Log "Burst limit low ($remaining remaining) - pausing 30s" 'WARN'
                Start-Sleep -Seconds 30
            }

            if ($Raw) { return $resp.Content }

            $json = $null
            if ($resp.Content) { try { $json = $resp.Content | ConvertFrom-Json } catch { } }
            if ($null -eq $json) { return [pscustomobject]@{ responseStatus = 'SUCCESS'; raw = $resp.Content } }

            if ((Get-Field $json 'responseStatus') -eq 'FAILURE') {
                $errs  = @(Get-Field $json 'errors' @())
                $types = @($errs | ForEach-Object { Get-Field $_ 'type' })
                if ($types -contains 'INVALID_SESSION_ID') {
                    Write-Log 'Session expired - re-authenticating' 'WARN'
                    Connect-Vault
                    continue
                }
                $msg = ($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; '
                throw "Vault API FAILURE on $Method $Path -- $msg"
            }
            return $json
        }
        catch [System.Net.WebException] {
            $status = $null
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 429) {
                Write-Log "HTTP 429 rate limited - waiting 60s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            $transient = (-not $status) -or ($status -ge 500)
            if (-not $transient -or $attempt -eq $MaxRetries) {
                $detail = ''
                try { $detail = (New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch { }
                throw "$Method $Path failed (HTTP $status): $($_.Exception.Message) $detail"
            }
            $wait = [math]::Pow(2, $attempt) * 5
            Write-Log "Transient error on $Method $Path (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
            Start-Sleep -Seconds $wait
        }
    }
    throw "$Method $Path failed after $MaxRetries attempts"
}

function Wait-VaultJob {
    param([Parameter(Mandatory)]$JobId, [string]$What = 'job')
    $running  = @('SCHEDULED','QUEUING','QUEUED','RUNNING','IN_PROGRESS')
    $deadline = (Get-Date).AddMinutes($JobTimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        $r = Invoke-VaultApi -Method GET -Path "/services/jobs/$JobId"
        $status = "$(Get-Field (Get-Field $r 'data' $null) 'status' '')".ToUpperInvariant()
        if ($status -and ($running -notcontains $status)) { return $status }
        Start-Sleep -Seconds $JobPollSeconds
    }
    return "TIMEOUT_AFTER_${JobTimeoutMinutes}_MIN"
}

# --------------------------------------------------------------------------------------
# File Staging
# --------------------------------------------------------------------------------------

function Get-StagingItem {
    <# Recursive listing of a staging folder. Follows pagination. #>
    param([Parameter(Mandatory)][string]$Path)

    $items = New-Object System.Collections.ArrayList
    $next  = "/services/file_staging/items/$(ConvertTo-StagingUrlPath $Path)?recursive=true&limit=500"

    while ($next) {
        $r = Invoke-VaultApi -Method GET -Path $next
        foreach ($d in @(Get-Field $r 'data' @())) { [void]$items.Add($d) }
        $next = Get-Field (Get-Field $r 'responseDetails' $null) 'next_page' ''
    }
    return $items
}

function Get-StagingFileText {
    param([Parameter(Mandatory)][string]$Path)
    return Invoke-VaultApi -Method GET -Path "/services/file_staging/items/content/$(ConvertTo-StagingUrlPath $Path)" -Raw
}

function New-StagingFolder {
    param([Parameter(Mandatory)][string]$Path)
    try {
        Invoke-VaultApi -Method POST -Path '/services/file_staging/items' `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{ kind = 'folder'; path = $Path; overwrite = 'false' } | Out-Null
        Write-Log "Staging folder ready: $Path"
    }
    catch {
        if ("$_" -match 'exist') { Write-Log "Staging folder already present: $Path" } else { throw }
    }
}

function Move-StagingItem {
    <#
      Server-side relocation. No bytes cross the network. Asynchronous: Vault returns a
      job id which is polled here. There is no copy operation in the File Staging API,
      so this is one-way unless -MoveBack is set.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,      # current full staging path
        [Parameter(Mandatory)][string]$NewParent  # destination folder
    )
    $r = Invoke-VaultApi -Method PUT -Path "/services/file_staging/items/$(ConvertTo-StagingUrlPath $Path)" `
            -ContentType 'application/x-www-form-urlencoded' -Body @{ parent = $NewParent }

    $jobId = Get-Field (Get-Field $r 'data' $null) 'job_id' (Get-Field $r 'job_id' '')
    if ($jobId) {
        $status = Wait-VaultJob -JobId $jobId -What 'move'
        if ($status -ne 'SUCCESS') { throw "Move of $Path to $NewParent ended $status (job $jobId)" }
    }
    $leaf = ($Path.Replace('\', '/').TrimEnd('/') -split '/')[-1]
    return (Join-StagingPath $NewParent $leaf)
}

# --------------------------------------------------------------------------------------
# Mapping: export_results.csv, read straight off staging
# --------------------------------------------------------------------------------------

function ConvertFrom-ExportResults {
    param([Parameter(Mandatory)][string]$Csv)

    $rows = @($Csv | ConvertFrom-Csv)
    if ($rows.Count -eq 0) { throw 'export_results.csv parsed to zero rows' }

    $headers = @($rows[0].PSObject.Properties.Name)
    $sample  = @($rows | Select-Object -First 50)

    $idCol = $IdColumn
    if (-not $idCol) { $idCol = @($headers | Where-Object { $_ -match '^(id|submission_?id|submission__v)$' }) | Select-Object -First 1 }
    if (-not $idCol) {
        $idCol = @($headers | Where-Object {
            $c = $_
            @($sample | ForEach-Object { "$(Get-Field $_ $c)" } | Where-Object { $_ -match '^00S[A-Za-z0-9]{8,}$' }).Count -gt 0
        }) | Select-Object -First 1
    }
    if (-not $idCol) { throw "No submission id column found. Columns: $($headers -join ', '). Set IdColumn in config.ini." }

    $pathCol = $PathColumn
    if (-not $pathCol) { $pathCol = @($headers | Where-Object { $_ -match 'path|folder' }) | Select-Object -First 1 }
    if (-not $pathCol) {
        $pathCol = @($headers | Where-Object {
            $c = $_
            @($sample | ForEach-Object { "$(Get-Field $_ $c)" } | Where-Object { $_ -match '[\\/]' }).Count -gt 0
        }) | Select-Object -First 1
    }
    if (-not $pathCol) { throw "No submission folder path column found. Columns: $($headers -join ', '). Set PathColumn in config.ini." }

    Write-Log "export_results.csv: id column '$idCol', path column '$pathCol'"

    $map = @{}
    foreach ($r in $rows) {
        $id  = "$(Get-Field $r $idCol)"
        $rel = "$(Get-Field $r $pathCol)".Replace('\', '/').Trim('/')
        if (-not $id -or -not $rel) { continue }

        $parts = @($rel -split '/' | Where-Object { $_ })
        if ($parts.Count -eq 0) { continue }
        $sub = $parts[-1]
        $app = if ($parts.Count -ge 2) { $parts[-2] } else { '' }

        $entry = [pscustomobject]@{
            ApplicationFolder    = $app
            SubmissionId         = $id
            SubmissionKey        = $sub
            ActualSubmissionDate = ''
            DossierFormatId      = ''
        }
        foreach ($k in @("$app-$sub.zip", "$sub.zip", "$id.zip", "$app-$sub", $sub)) {
            if ($k -and -not $map.ContainsKey($k)) { $map[$k] = $entry }
        }
    }
    if ($map.Count -eq 0) { throw 'No usable rows parsed from export_results.csv' }
    return $map
}

# --------------------------------------------------------------------------------------
# Discover the export on staging
# --------------------------------------------------------------------------------------

if (-not $script:SessionId) { Connect-Vault }

Write-Log "Listing export folder on File Staging: $SourceStagingPath"
$staged = Get-StagingItem -Path $SourceStagingPath

$dossiers = @($staged | Where-Object {
    $kind = "$(Get-Field $_ 'kind' 'file')"
    $name = "$(Get-Field $_ 'name' '')"
    ($kind -ne 'folder') -and (($Include | Where-Object { $name -like $_ } | Select-Object -First 1) -ne $null)
})

if ($dossiers.Count -eq 0) {
    throw "No dossiers matching $($Include -join ', ') found under $SourceStagingPath. Listed $($staged.Count) item(s) - check the path, and note that only .zip/.tar.gz can be imported from the staging root."
}
Write-Log "Found $($dossiers.Count) dossier(s) under $SourceStagingPath"

# export_results.csv, in place
$map = @{}
$exportCsvPath = $ExportResultsCsv
if (-not $exportCsvPath) {
    $hit = @($staged | Where-Object { "$(Get-Field $_ 'name' '')" -ieq 'export_results.csv' }) | Select-Object -First 1
    if ($hit) { $exportCsvPath = "$(Get-Field $hit 'path' '')" }
}
if ($exportCsvPath) {
    Write-Log "Reading mapping from staging: $exportCsvPath"
    $map = ConvertFrom-ExportResults -Csv (Get-StagingFileText -Path $exportCsvPath)
    Write-Log "Mapping loaded for $($map.Count) key(s)" 'OK'
} else {
    Write-Log "No export_results.csv found under $SourceStagingPath - falling back to file names and VQL." 'WARN'
}

# A hand-edited manifest overrides the export csv.
if ($Manifest) {
    if (-not (Test-Path -LiteralPath $Manifest)) { throw "Manifest not found: $Manifest" }
    $n = 0
    foreach ($row in (Import-Csv -LiteralPath $Manifest)) {
        $fn = Get-Field $row 'FileName'
        if ($fn) { $map[$fn] = $row; $n++ }
    }
    Write-Log "Loaded manifest with $n row(s): $Manifest"
}

# --------------------------------------------------------------------------------------
# MODE = MANIFEST: write the mapping sheet and stop
# --------------------------------------------------------------------------------------

if ($GenerateManifest) {
    $resolved = 0
    $dossiers | ForEach-Object {
        $name = "$(Get-Field $_ 'name' '')"
        $base = ($name -replace '\.tar\.gz$|\.tgz$|\.zip$', '')
        $hit  = if ($map.ContainsKey($name)) { $map[$name] } elseif ($map.ContainsKey($base)) { $map[$base] } else { $null }
        $subId = if ($hit) { Get-Field $hit 'SubmissionId' } elseif ($NameIsSubmissionId) { $base } else { '' }
        if ($subId) { $resolved++ }
        [pscustomobject]@{
            FileName             = $name
            StagingPath          = "$(Get-Field $_ 'path' '')"
            SizeMB               = [math]::Round(([double]"$(Get-Field $_ 'size' 0)") / 1MB, 2)
            ApplicationFolder    = if ($hit) { Get-Field $hit 'ApplicationFolder' } else { '' }
            SubmissionId         = $subId
            SubmissionKey        = if ($hit) { Get-Field $hit 'SubmissionKey' } else { $base }
            ActualSubmissionDate = ''
            DossierFormatId      = ''
        }
    } | Export-Csv -LiteralPath $ManifestOut -NoTypeInformation -Encoding UTF8

    Write-Log "Wrote manifest for $($dossiers.Count) dossier(s), $resolved with SubmissionId filled in: $ManifestOut" 'OK'
    return
}

# --------------------------------------------------------------------------------------
# Submission lookup / import
# --------------------------------------------------------------------------------------

function Resolve-SubmissionId {
    param([Parameter(Mandatory)][string]$Key)
    $escaped = $Key.Replace("'", "\'")
    $r = Invoke-VaultApi -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
            -Body @{ q = "SELECT id, name__v FROM submission__v WHERE $LookupField = '$escaped'" }
    $rows = @(Get-Field $r 'data' @())
    if ($rows.Count -eq 0) { throw "No submission__v record where $LookupField = '$Key'" }
    if ($rows.Count -gt 1) { throw "$($rows.Count) submission__v records match $LookupField = '$Key' - set SubmissionId in the manifest" }
    return $rows[0].id
}

function Start-SubmissionImport {
    param(
        [Parameter(Mandatory)][string]$SubmissionId,
        [Parameter(Mandatory)][string]$StagingPath,
        [string]$DossierFormatId,
        [string]$ActualSubmissionDate
    )
    $body = @{ file = $StagingPath }
    if ($DossierFormatId)      { $body['dossier_format_record_id'] = $DossierFormatId }
    if ($ActualSubmissionDate) { $body['actual_submission_date']   = $ActualSubmissionDate }

    $r = Invoke-VaultApi -Method POST -Path "/vobjects/submission__v/$SubmissionId/actions/import" `
            -ContentType 'application/x-www-form-urlencoded' -Body $body

    $warnings = ''
    $w = Get-Field $r 'warnings' $null
    if ($w) {
        $warnings = (@($w) | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join ' | '
        Write-Log "Import warnings for $SubmissionId -- $warnings" 'WARN'
    }
    return [pscustomobject]@{ JobId = (Get-Field $r 'job_id' ''); Warnings = $warnings }
}

function Get-ImportResult {
    param([Parameter(Mandatory)][string]$SubmissionId, [Parameter(Mandatory)]$JobId)
    try {
        # Vault 26R3 stops returning the data array here; importMessages remains.
        $r = Invoke-VaultApi -Method GET -Path "/vobjects/submission__v/$SubmissionId/actions/import/$JobId/results"
        $binderId = ''; $version = ''
        $d = Get-Field $r 'data' $null
        if ($d) {
            $first    = @($d)[0]
            $binderId = Get-Field $first 'id' ''
            $version  = "$(Get-Field $first 'major_version_number__v' '?').$(Get-Field $first 'minor_version_number__v' '?')"
        }
        $messages = ''
        $im = Get-Field $r 'importMessages' $null
        if ($im) { $messages = (@($im) | ForEach-Object { "$_" }) -join ' | ' }
        return [pscustomobject]@{ BinderId = $binderId; BinderVersion = $version; Messages = $messages }
    }
    catch {
        return [pscustomobject]@{ BinderId = ''; BinderVersion = ''; Messages = "results unavailable: $_" }
    }
}

# --------------------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------------------

$done = @{}
if (Test-Path -LiteralPath $ResultsCsv) {
    foreach ($row in (Import-Csv -LiteralPath $ResultsCsv)) {
        if ((Get-Field $row 'Status') -eq 'SUCCESS') { $done[(Get-Field $row 'FileName')] = $true }
    }
    if ($done.Count) { Write-Log "$($done.Count) dossier(s) already SUCCESS in $ResultsCsv - skipping them" }
}

$results   = New-Object System.Collections.ArrayList
$createdIn = @{}
$i = 0

foreach ($d in $dossiers) {
    $i++
    $name       = "$(Get-Field $d 'name' '')"
    $sourcePath = "$(Get-Field $d 'path' '')"
    $base       = ($name -replace '\.tar\.gz$|\.tgz$|\.zip$', '')
    $prefix     = "[$i/$($dossiers.Count)] $name"

    if ($done.ContainsKey($name)) { Write-Log "$prefix - skipped (already SUCCESS)"; continue }

    $hit = if ($map.ContainsKey($name)) { $map[$name] } elseif ($map.ContainsKey($base)) { $map[$base] } else { $null }

    $appFolder = Get-Field $hit 'ApplicationFolder' ''
    $subKey    = Get-Field $hit 'SubmissionKey'     $base
    $subId     = Get-Field $hit 'SubmissionId'      $(if ($NameIsSubmissionId) { $base } else { '' })
    $dossier   = Get-Field $hit 'DossierFormatId'   $DefaultDossierFormatId
    $subDate   = Get-Field $hit 'ActualSubmissionDate' ''

    $record = [ordered]@{
        FileName          = $name
        SourceStagingPath = $sourcePath
        SizeMB            = [math]::Round(([double]"$(Get-Field $d 'size' 0)") / 1MB, 2)
        ApplicationFolder = $appFolder
        ImportStagingPath = ''
        SubmissionKey     = $subKey
        SubmissionId      = $subId
        MoveJobDone       = ''
        JobId             = ''
        Status            = ''
        BinderId          = ''
        BinderVersion     = ''
        Warnings          = ''
        Messages          = ''
        StartedUtc        = (Get-Date).ToUniversalTime().ToString('s')
        FinishedUtc       = ''
    }

    try {
        if (-not $appFolder) {
            throw "No ApplicationFolder for $name - it was not in export_results.csv. Add a manifest row, or set ExportResultsCsv."
        }

        $targetFolder = "$StagingRoot/$appFolder"
        $targetPath   = "$targetFolder/$name"
        $record.ImportStagingPath = $targetPath

        if (-not $subId) {
            # Read-only VQL, so it runs under -WhatIf too: a bad key surfaces before any move.
            Write-Log "$prefix - resolving submission by $LookupField = '$subKey'"
            $subId = Resolve-SubmissionId -Key $subKey
            $record.SubmissionId = $subId
        }

        if ($PSCmdlet.ShouldProcess("$sourcePath -> $targetPath, submission $subId", 'Move on staging and import')) {
            if (-not $createdIn.ContainsKey($targetFolder)) {
                New-StagingFolder -Path $targetFolder
                $createdIn[$targetFolder] = $true
            }

            Write-Log "$prefix - moving on staging to $targetFolder (server-side, no transfer)"
            $moved = Move-StagingItem -Path $sourcePath -NewParent $targetFolder
            $record.MoveJobDone = 'yes'
            $record.ImportStagingPath = $moved

            $job = Start-SubmissionImport -SubmissionId $subId -StagingPath $moved `
                        -DossierFormatId $dossier -ActualSubmissionDate $subDate
            $record.JobId    = $job.JobId
            $record.Warnings = $job.Warnings
            Write-Log "$prefix - import job $($job.JobId) started; polling"

            $status = Wait-VaultJob -JobId $job.JobId -What 'import'
            $record.Status = $status

            $res = Get-ImportResult -SubmissionId $subId -JobId $job.JobId
            $record.BinderId      = $res.BinderId
            $record.BinderVersion = $res.BinderVersion
            $record.Messages      = $res.Messages

            if ($status -eq 'SUCCESS') { Write-Log "$prefix - SUCCESS (binder $($res.BinderId) v$($res.BinderVersion))" 'OK' }
            else                       { Write-Log "$prefix - job ended $status. $($res.Messages)" 'ERROR' }

            if ($MoveBack) {
                $originalParent = ($sourcePath.Replace('\', '/').TrimEnd('/') -split '/')
                $originalParent = ($originalParent[0..($originalParent.Count - 2)]) -join '/'
                Write-Log "$prefix - returning dossier to $originalParent"
                Move-StagingItem -Path $moved -NewParent $originalParent | Out-Null
                $record.MoveJobDone = 'yes (returned)'
            }
        }
        else {
            $record.Status = 'WHATIF'
            Write-Log "$prefix - WhatIf: would move to $targetPath and import into submission $subId"
        }
    }
    catch {
        $record.Status   = 'ERROR'
        $record.Messages = "$_"
        Write-Log "$prefix - ERROR: $_" 'ERROR'
    }

    $record.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
    [void]$results.Add([pscustomobject]$record)
    $results | Export-Csv -LiteralPath $ResultsCsv -NoTypeInformation -Encoding UTF8
}

# --------------------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------------------

$ok   = @($results | Where-Object Status -eq 'SUCCESS').Count
$bad  = @($results | Where-Object { $_.Status -notin @('SUCCESS','WHATIF') }).Count
$what = @($results | Where-Object Status -eq 'WHATIF').Count

Write-Log '----------------------------------------------------------------'
Write-Log "Processed $($results.Count) dossier(s): $ok succeeded, $bad failed, $what dry-run" $(if ($bad) { 'WARN' } else { 'OK' })
Write-Log "Results CSV : $ResultsCsv"
Write-Log "Log         : $TranscriptLog"
if (-not $MoveBack -and $ok -gt 0) {
    Write-Log "Note: imported dossiers now live under $StagingRoot, not $SourceStagingPath. The File Staging API has no copy operation, so the move is one-way unless MoveBack is set." 'WARN'
}

if ($bad -gt 0) { exit 1 }
