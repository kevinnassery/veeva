<#
.SYNOPSIS
    Imports submission dossiers that are already on Veeva Vault File Staging into
    RIM Submissions Archive. Nothing is moved, downloaded or uploaded.

.DESCRIPTION
    The dossiers are staged under the Submissions Archive root, e.g.
        /SubmissionsArchive/{JobID}/{application}/{submission}
    or  /SubmissionsArchive/{application}/{submission}
    and Import Submission reads them straight from there.

    For each dossier this script:
      1. Calls Import Submission on the matching submission__v record, pointing at
         the dossier's existing staging path.
      2. Polls the import job, then retrieves the import results.
      3. Appends a row to a results CSV - file name, staging path, job id, status,
         binder id/version and any validation messages.

    The archive -> submission mapping comes from export_results.csv, which Bulk
    Submission Export wrote next to the dossiers. It is read directly off File
    Staging; no local copy is needed and nothing has to be typed in by hand.

    Re-runnable: dossiers already recorded as SUCCESS are skipped.

.PARAMETER ConfigFile
    All settings live in config.ini beside this script. Command line overrides it.

.NOTES
    Windows PowerShell 5.1 compatible (also runs on PowerShell 7).
    Endpoints, all relative to https://<VaultDNS>/api/<ApiVersion>:
      POST /auth
      GET  /services/file_staging/items/{item}?recursive=true      list the dossiers
      GET  /services/file_staging/items/content/{item}             read export_results.csv
      POST /vobjects/submission__v/{id}/actions/import             import (async, job id)
      GET  /services/jobs/{job_id}                                 poll the import job
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

    # File Staging folder holding the dossiers, under the Submissions Archive root.
    #   e.g. '/SubmissionsArchive/e157135'  or  '/SubmissionsArchive'
    [string]     $SourceStagingPath = '',

    # Local folder for the results CSV and log. Nothing else is written locally.
    [string]     $OutputRoot       = '',

    # ---- Vault ----
    [ValidatePattern('^v\d+\.\d+$')]
    [string]     $ApiVersion       = 'v26.2',

    # The ONLY place a session id is configured. Blank = log in and manage it for me.
    [string]     $SessionId        = '',

    # ---- Run mode ----
    [switch]     $GenerateManifest,
    [string]     $Manifest,

    # Staging path of export_results.csv. Blank = look for it under SourceStagingPath.
    [string]     $ExportResultsCsv,
    [string]     $IdColumn,
    [string]     $PathColumn,
    [switch]     $NameIsSubmissionId,

    [pscredential] $Credential,

    # ---- Advanced ----
    # How a submission folder name (e.g. 0000) and its application (e.g. e157135)
    # map onto Vault fields, used to resolve the submission__v record when there is
    # no manifest and no export_results.csv. Confirm these match your vault.
    [string]     $LookupField       = 'name__v',        # submission__v field the folder name is found in
    [ValidateSet('prefix','exact')]
    [string]     $SubmissionMatch   = 'prefix',          # folder name is a prefix of name__v ("0000 - ...")
    [string]     $ApplicationObject   = 'application__v', # object queried to turn e157135 into an id
    [string]     $ApplicationKeyField = 'name__v',       # application__v field holding e157135
    [string]     $ApplicationRefField = 'application__v', # submission__v field storing the application id

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
    # Escape each path segment for a URL while keeping the separators. Staging folders
    # can contain spaces (e.g. "Submissions Archive Export"), which otherwise 404.
    param([Parameter(Mandatory)][string]$Path)
    $clean = $Path.Replace('\', '/').Trim('/')
    return (($clean -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}

# --------------------------------------------------------------------------------------
# Configuration: one file, one load
# --------------------------------------------------------------------------------------

$IntKeys    = @('JobTimeoutMinutes', 'JobPollSeconds', 'MaxRetries')
$SwitchKeys = @('GenerateManifest', 'NameIsSubmissionId')
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
        $v = $t.Substring($eq + 1).Trim()
        # Strip an inline comment - whitespace followed by # or ; - unless the value is
        # quoted. Without this, "field = name__v  # note" would keep the note as the value.
        if ($v -notmatch '^["'']') { $v = ($v -split '\s+[#;]', 2)[0].TrimEnd() }
        $v = $v.Trim('"', "'")
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
        [switch]$Raw
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
    param([Parameter(Mandatory)]$JobId)
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
# File Staging - read only
# --------------------------------------------------------------------------------------

function Get-StagingItem {
    param([Parameter(Mandatory)][string]$Path, [switch]$Recursive)
    $items = New-Object System.Collections.ArrayList
    $rec   = if ($Recursive) { 'true' } else { 'false' }
    $next  = "/services/file_staging/items/$(ConvertTo-StagingUrlPath $Path)?recursive=$rec&limit=500"
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
# Discover the dossiers on staging
# --------------------------------------------------------------------------------------

if (-not $script:SessionId) { Connect-Vault }

# The application is the folder SourceStagingPath points at, e.g. e157135 in
# /SubmissionsArchive/e157135. Its direct children are the submissions.
$ApplicationKey = @($SourceStagingPath -split '/' | Where-Object { $_ })[-1]

Write-Log "Listing submissions on File Staging: $SourceStagingPath (application '$ApplicationKey')"
$staged = Get-StagingItem -Path $SourceStagingPath      # direct children only

# A dossier is either a submission folder (uncompressed eCTD) or a .zip/.tar.gz,
# sitting directly under SourceStagingPath. Skip Vault's own VFMTemp scratch folder.
$dossiers = @($staged | Where-Object {
    $kind = "$(Get-Field $_ 'kind' 'file')"
    $name = "$(Get-Field $_ 'name' '')"
    if ($name -ieq 'VFMTemp' -or $name.StartsWith('.')) { return $false }
    if ($kind -eq 'folder') { return $true }
    return (($Include | Where-Object { $name -like $_ } | Select-Object -First 1) -ne $null)
})

if ($dossiers.Count -eq 0) {
    throw "No submission folders or archives found directly under $SourceStagingPath (listed $($staged.Count) item(s)). Point SourceStagingPath at the application folder whose children are the submissions."
}
Write-Log "Found $($dossiers.Count) submission(s) under $SourceStagingPath"

# export_results.csv, if the export left one anywhere under the path. Optional:
# with the /SubmissionsArchive/<app>/<submission> layout there usually isn't one,
# and submissions resolve by folder name + application via VQL instead.
$map = @{}
$exportCsvPath = $ExportResultsCsv
if (-not $exportCsvPath) {
    # Only look among direct children - never recurse into the eCTD trees to find it.
    $hit = @($staged | Where-Object { "$(Get-Field $_ 'name' '')" -ieq 'export_results.csv' }) | Select-Object -First 1
    if ($hit) { $exportCsvPath = "$(Get-Field $hit 'path' '')" }
}
if ($exportCsvPath) {
    Write-Log "Reading mapping from staging: $exportCsvPath"
    $map = ConvertFrom-ExportResults -Csv (Get-StagingFileText -Path $exportCsvPath)
    Write-Log "Mapping loaded for $($map.Count) key(s)" 'OK'
} else {
    Write-Log "No export_results.csv - resolving each submission by folder name + application via VQL." 'INFO'
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
        # Folders keep their name; archives lose the extension.
        $base = if ("$(Get-Field $_ 'kind' 'file')" -eq 'folder') { $name } else { $name -replace '\.tar\.gz$|\.tgz$|\.zip$', '' }
        $hit  = if ($map.ContainsKey($name)) { $map[$name] } elseif ($map.ContainsKey($base)) { $map[$base] } else { $null }
        $subId = if ($hit) { Get-Field $hit 'SubmissionId' } elseif ($NameIsSubmissionId) { $base } else { '' }
        if ($subId) { $resolved++ }
        # Only the columns import actually reads. FileName is the join key back to the
        # live staging listing; the rest are what you fill in. The dossier's real staging
        # path comes from that live listing at import time, so it is not carried here.
        [pscustomobject]@{
            FileName             = $name
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

function Get-ApplicationId {
    # Turn the application folder name (e157135) into its record id, once per run.
    # Cached so we query the application object a single time, not per submission.
    # A direct-equality filter on the id later avoids VQL relationship traversal,
    # which is what the "Unknown relationship [application__v]" error was about.
    param([string]$Key)
    if ($script:AppIdResolved) { return $script:AppId }
    $script:AppIdResolved = $true
    $script:AppId = ''
    if (-not $Key) { return '' }

    $k = $Key.Replace("'", "\'")
    $r = Invoke-VaultApi -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
            -Body @{ q = "SELECT id FROM $ApplicationObject WHERE $ApplicationKeyField = '$k'" }
    $rows = @(Get-Field $r 'data' @())
    if ($rows.Count -eq 0) { throw "No $ApplicationObject where $ApplicationKeyField = '$Key' - check ApplicationObject / ApplicationKeyField in config.ini" }
    if ($rows.Count -gt 1) { throw "$($rows.Count) $ApplicationObject records match $ApplicationKeyField = '$Key'" }
    $script:AppId = $rows[0].id
    Write-Log "Application '$Key' resolved to $ApplicationObject $($script:AppId)"
    return $script:AppId
}

function Resolve-SubmissionId {
    # Resolve a submission__v record from its folder name (the submission number)
    # scoped to its application id, via VQL. This is what makes the tool manifest-
    # and export_results.csv-free: the staging folder structure supplies both keys.
    #
    # The submission NAME is "0000 - Submission Meeting Minutes", i.e. the folder name
    # is a PREFIX of name__v, not the whole value - so SubmissionMatch defaults to
    # 'prefix' (LIKE '0000%'). Set it to 'exact' if LookupField holds just the number.
    param(
        [Parameter(Mandatory)][string]$Key,   # submission folder name, e.g. 0000
        [string]$ApplicationId                 # application record id (from Get-ApplicationId)
    )
    $sub = $Key.Replace("'", "\'")
    if ($SubmissionMatch -eq 'exact') {
        $clause = "$LookupField = '$sub'"
    } else {
        # Zero-padded 4-digit numbers are prefix-unique (0000 never prefixes 0001),
        # so '0000%' safely picks "0000 - ...". % and _ can't appear in a folder name.
        $clause = "$LookupField LIKE '$sub%'"
    }
    $where = $clause
    if ($ApplicationId) {
        # Direct equality on the reference field's stored id - no relationship traversal.
        $where += " AND $ApplicationRefField = '$ApplicationId'"
    }
    $r = Invoke-VaultApi -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
            -Body @{ q = "SELECT id, name__v FROM submission__v WHERE $where" }
    $rows = @(Get-Field $r 'data' @())
    if ($rows.Count -eq 0) { throw "No submission__v where $where" }
    if ($rows.Count -gt 1) {
        $names = (@($rows | ForEach-Object { Get-Field $_ 'name__v' }) -join '; ')
        throw "$($rows.Count) submission__v records match $where ($names) - narrow LookupField or set SubmissionId in a manifest"
    }
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

$results = New-Object System.Collections.ArrayList
$script:AppIdResolved = $false   # Get-ApplicationId caches into $script:AppId after first call
$i = 0

foreach ($d in $dossiers) {
    $i++
    $name        = "$(Get-Field $d 'name' '')"
    $stagingPath = "$(Get-Field $d 'path' '')"
    $base        = if ("$(Get-Field $d 'kind' 'file')" -eq 'folder') { $name } else { $name -replace '\.tar\.gz$|\.tgz$|\.zip$', '' }
    $prefix      = "[$i/$($dossiers.Count)] $name"

    if ($done.ContainsKey($name)) { Write-Log "$prefix - skipped (already SUCCESS)"; continue }

    $hit = if ($map.ContainsKey($name)) { $map[$name] } elseif ($map.ContainsKey($base)) { $map[$base] } else { $null }

    $subKey  = Get-Field $hit 'SubmissionKey'        $base
    $subId   = Get-Field $hit 'SubmissionId'         $(if ($NameIsSubmissionId) { $base } else { '' })
    $dossier = Get-Field $hit 'DossierFormatId'      $DefaultDossierFormatId
    $subDate = Get-Field $hit 'ActualSubmissionDate' ''

    $record = [ordered]@{
        FileName      = $name
        StagingPath   = $stagingPath
        SizeMB        = [math]::Round(([double]"$(Get-Field $d 'size' 0)") / 1MB, 2)
        SubmissionKey = $subKey
        SubmissionId  = $subId
        JobId         = ''
        Status        = ''
        BinderId      = ''
        BinderVersion = ''
        Warnings      = ''
        Messages      = ''
        StartedUtc    = (Get-Date).ToUniversalTime().ToString('s')
        FinishedUtc   = ''
    }

    try {
        if (-not $subId) {
            # Read-only VQL, so it runs under -WhatIf too: a bad key surfaces before importing.
            Write-Log "$prefix - resolving submission '$subKey' in application '$ApplicationKey'"
            $appId = Get-ApplicationId -Key $ApplicationKey   # cached after the first call
            $subId = Resolve-SubmissionId -Key $subKey -ApplicationId $appId
            $record.SubmissionId = $subId
        }

        if ($PSCmdlet.ShouldProcess("submission $subId from $stagingPath", 'Import')) {
            $job = Start-SubmissionImport -SubmissionId $subId -StagingPath $stagingPath `
                        -DossierFormatId $dossier -ActualSubmissionDate $subDate
            $record.JobId    = $job.JobId
            $record.Warnings = $job.Warnings
            Write-Log "$prefix - import job $($job.JobId) started; polling"

            $status = Wait-VaultJob -JobId $job.JobId
            $record.Status = $status

            $res = Get-ImportResult -SubmissionId $subId -JobId $job.JobId
            $record.BinderId      = $res.BinderId
            $record.BinderVersion = $res.BinderVersion
            $record.Messages      = $res.Messages

            if ($status -eq 'SUCCESS') { Write-Log "$prefix - SUCCESS (binder $($res.BinderId) v$($res.BinderVersion))" 'OK' }
            else                       { Write-Log "$prefix - job ended $status. $($res.Messages)" 'ERROR' }
        }
        else {
            $record.Status = 'WHATIF'
            Write-Log "$prefix - WhatIf: would import $stagingPath into submission $subId"
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

if ($bad -gt 0) { exit 1 }
