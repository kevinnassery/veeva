<#
.SYNOPSIS
    Bulk-imports downloaded submission archives into Veeva Vault RIM Submissions Archive.

.DESCRIPTION
    For each archive in -SourceRoot this script:
      1. Uploads it to the Vault File Staging server under /SubmissionsArchive/<application>/
         (resumable upload session, 50 MB parts -- handles multi-GB submissions).
      2. Calls Import Submission on the matching submission__v record.
      3. Polls the resulting job to completion.
      4. Retrieves the import results (binder id/version + validation messages).
      5. Appends one row per archive to a results CSV -- file name included, so nothing
         has to be copy/pasted by hand.

    SAFETY: the script NEVER writes to, moves, renames or deletes anything under -SourceRoot.
    Source files are opened read-only. All output goes to -OutputRoot, which is refused if it
    resolves inside -SourceRoot or inside any path listed in -ProtectedPath.

    Re-runnable: archives already recorded as SUCCESS in the results CSV are skipped, so an
    interrupted run can simply be started again.

.PARAMETER VaultDNS
    Vault host name, e.g. mycompany-rim.veevavault.com

.PARAMETER SourceRoot
    Folder holding the downloaded archives. Expected layout (one folder per application):
        <SourceRoot>\<ApplicationFolder>\<submission>.zip
    A flat folder of archives also works if you supply -Manifest with ApplicationFolder filled in.

.PARAMETER OutputRoot
    Where the results CSV, manifest and transcript are written. Created if missing.

.PARAMETER Manifest
    CSV mapping archives to submission records. Columns:
        FileName,ApplicationFolder,SubmissionId,SubmissionKey,ActualSubmissionDate,DossierFormatId
    SubmissionId wins if present; otherwise SubmissionKey is resolved by VQL against -LookupField.
    Run with -GenerateManifest first to produce this file pre-filled with the file names.

.PARAMETER GenerateManifest
    Scan -SourceRoot, write a manifest CSV skeleton to -OutputRoot and exit. No Vault calls,
    no uploads. Fill in SubmissionId (or SubmissionKey) and re-run without this switch.

.EXAMPLE
    # Step 1 - build the mapping sheet (file names filled in for you)
    .\Import-VaultSubmissions.ps1 -VaultDNS mycompany-rim.veevavault.com `
        -SourceRoot D:\SubmissionDownloads -OutputRoot D:\ImportRun -GenerateManifest

.EXAMPLE
    # Step 2 - dry run: validates mapping + staging paths, uploads and imports nothing
    .\Import-VaultSubmissions.ps1 -VaultDNS mycompany-rim.veevavault.com `
        -SourceRoot D:\SubmissionDownloads -OutputRoot D:\ImportRun `
        -Manifest D:\ImportRun\manifest.csv -WhatIf

.EXAMPLE
    # Step 3 - the real run
    .\Import-VaultSubmissions.ps1 -VaultDNS mycompany-rim.veevavault.com `
        -SourceRoot D:\SubmissionDownloads -OutputRoot D:\ImportRun `
        -Manifest D:\ImportRun\manifest.csv

.NOTES
    Windows PowerShell 5.1 compatible (also runs on PowerShell 7).

    API version is a single variable: -ApiVersion (default v26.2), or API_VERSION in
    Run-Import.bat. Every URL below is built from it.

    Endpoints (documented for v26.1 and v26.2 alike):
      POST /api/{v}/auth
      POST /api/{v}/services/file_staging/items                     (create folder)
      POST /api/{v}/services/file_staging/upload                    (create resumable session)
      PUT  /api/{v}/services/file_staging/upload/{session_id}       (upload part)
      POST /api/{v}/services/file_staging/upload/{session_id}       (commit)
      POST /api/{v}/vobjects/submission__v/{id}/actions/import
      GET  /api/{v}/services/jobs/{job_id}
      GET  /api/{v}/vobjects/submission__v/{id}/actions/import/{job_id}/results
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # ======================================================================================
    #  All configuration lives in ONE file: config.ini, next to this script.
    #  Edit that. Do not edit the defaults below - they exist only as fallbacks.
    #
    #  Precedence:  command line  >  config.ini  >  the defaults here
    # ======================================================================================

    # Path to the single config file. Blank means config.ini beside this script.
    [string]     $ConfigFile       = '',

    # Vault host name. No https://, no trailing slash.
    #   e.g. 'mycompany-rim.veevavault.com'
    [string]     $VaultDNS         = '',

    # Vault API version. Every request is built as https://<VaultDNS>/api/<ApiVersion>/...
    # so this one value moves the whole script between releases. Must look like v26.2.
    [ValidatePattern('^v\d+\.\d+$')]
    [string]     $ApiVersion       = 'v26.2',

    # Vault API session id.
    #
    #   *** This is the ONLY place a session id is configured. ***
    #
    # Leave it blank for normal use: the script authenticates and manages the session
    # itself, including re-authenticating if it expires mid-run. Set it only when you
    # already hold a session from somewhere else and want to reuse it.
    # See the "Session id" block below for how it flows through the script.
    [string]     $SessionId        = '',

    # Folder holding the bulk download. This script only ever reads from it.
    #   e.g. 'D:\SubmissionDownloads'
    [string]     $SourceRoot       = '',

    # Where the manifest, results CSV and log are written. Must not be inside SourceRoot.
    #   e.g. 'D:\ImportRun'
    [string]     $OutputRoot       = '',

    # Staging root for Submissions Archive imports. Change only if your Vault differs.
    [string]     $StagingRoot      = '/SubmissionsArchive',

    # ======================================================================================
    #  RUN MODE - how this particular run should behave.
    # ======================================================================================

    # Scan SourceRoot, write a manifest skeleton to OutputRoot, and exit. No Vault calls.
    [switch]     $GenerateManifest,

    # Mapping sheet produced by -GenerateManifest and then filled in by hand.
    [string]     $Manifest,

    # Vault's own export summary (export_results.csv, found in the
    # <App>-<Sub>-export-summary.zip that Bulk Submission Export produces). When supplied,
    # the mapping of archive -> submission record is derived from it and no hand-built
    # manifest is needed. Column names are detected, since Veeva does not publish a schema.
    [string]     $ExportResultsCsv,
    [string]     $IdColumn,
    [string]     $PathColumn,

    # Use when each downloaded file is named for the submission record id itself
    # (e.g. 00S000000000001.zip, as produced by a /vobjects/.../attachments/file loop).
    [switch]     $NameIsSubmissionId,

    # Supply credentials non-interactively instead of being prompted.
    [pscredential] $Credential,

    # ======================================================================================
    #  ADVANCED - sensible defaults; change only if you have a reason.
    # ======================================================================================

    # VQL field used to resolve SubmissionKey -> submission__v id when SubmissionId is blank.
    [string]     $LookupField      = 'name__v',

    # Applied when the manifest row leaves DossierFormatId blank.
    [string]     $DefaultDossierFormatId,

    [string[]]   $Include          = @('*.zip', '*.tar.gz', '*.tgz'),

    # Folders the script must never write into. Add anything you want fenced off.
    [string[]]   $ProtectedPath    = @("$env:USERPROFILE\Documents\wave1"),

    [int]        $PartSizeMB       = 50,     # Vault max part size is 50 MB; max 2000 parts.
    [int]        $JobTimeoutMinutes = 120,
    [int]        $JobPollSeconds   = 20,
    [int]        $MaxRetries       = 4
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # large -Body PUTs are ~10x faster without it
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --------------------------------------------------------------------------------------
# Configuration: one file, one load, applied here
#
# config.ini is the single place settings live. Run-Import.bat reads the same file, so
# there is never a second copy to keep in sync. Anything passed explicitly on the command
# line wins over the file -- that is what $PSBoundParameters checks below.
# --------------------------------------------------------------------------------------

$IntKeys    = @('PartSizeMB', 'JobTimeoutMinutes', 'JobPollSeconds', 'MaxRetries')
$SwitchKeys = @('GenerateManifest', 'NameIsSubmissionId')
$ListKeys   = @('Include', 'ProtectedPath')

function Import-ConfigFile {
    <#
      Minimal KEY = VALUE parser. Blank lines and #/; comments ignored, surrounding
      quotes stripped, lists split on commas. Returns an ordered hashtable.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $cfg = [ordered]@{}
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';') -or $t.StartsWith('[')) { continue }
        $eq = $t.IndexOf('=')
        if ($eq -lt 1) { continue }
        $k = $t.Substring(0, $eq).Trim()
        $v = $t.Substring($eq + 1).Trim().Trim('"', "'")
        # Expand %USERPROFILE% and friends so paths can be written the .bat way.
        $cfg[$k] = [Environment]::ExpandEnvironmentVariables($v)
    }
    return $cfg
}

$ConfigExplicit = $PSBoundParameters.ContainsKey('ConfigFile')
if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    # $PSScriptRoot is empty when dot-sourced or pasted into a console.
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
    $ConfigFile = Join-Path $here 'config.ini'
}

$ConfigMode = ''
if (Test-Path -LiteralPath $ConfigFile) {
    $cfg = Import-ConfigFile -Path $ConfigFile

    foreach ($key in $cfg.Keys) {
        $value = $cfg[$key]

        # MODE is for humans and for Run-Import.bat; translate it into switches here.
        if ($key -eq 'MODE') { $ConfigMode = $value.ToUpperInvariant(); continue }

        # An explicit command-line argument always wins over the file.
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
elseif ($ConfigExplicit) {
    throw "Config file not found: $ConfigFile"
}
else {
    Write-Warning "No config.ini found at $ConfigFile - relying on command-line arguments."
}

# --------------------------------------------------------------------------------------
# Required settings
#
# No safe default exists for these, so they must come from config.ini or the command line.
# Checked here rather than with [Parameter(Mandatory)], which would prompt on every run
# even when config.ini already has the answer.
# --------------------------------------------------------------------------------------

foreach ($name in @('VaultDNS', 'SourceRoot', 'OutputRoot')) {
    if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $name -ValueOnly))) {
        throw "$name is not set. Add it to $ConfigFile, or pass -$name on the command line."
    }
}
$VaultDNS = $VaultDNS -replace '^https?://', '' -replace '/+$', ''

# --------------------------------------------------------------------------------------
# Paths and guard rails
# --------------------------------------------------------------------------------------

function Resolve-FullPath([string]$Path) {
    return [IO.Path]::GetFullPath(
        [IO.Path]::Combine((Get-Location).ProviderPath, $Path)
    ).TrimEnd('\')
}

function Test-IsUnder([string]$Child, [string]$Parent) {
    $c = (Resolve-FullPath $Child).ToLowerInvariant()
    $p = (Resolve-FullPath $Parent).ToLowerInvariant()
    return ($c -eq $p) -or $c.StartsWith($p + '\')
}

$SourceRoot = Resolve-FullPath $SourceRoot
$OutputRoot = Resolve-FullPath $OutputRoot

if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "SourceRoot does not exist: $SourceRoot"
}
if (Test-IsUnder $OutputRoot $SourceRoot) {
    throw "OutputRoot ($OutputRoot) is inside SourceRoot. The download folder is read-only for this script -- pick an OutputRoot somewhere else."
}
foreach ($p in $ProtectedPath) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    if (Test-Path -LiteralPath $p) {
        if (Test-IsUnder $OutputRoot $p) { throw "OutputRoot ($OutputRoot) is inside protected path $p. Refusing to write there." }
    }
}
if (-not (Test-Path -LiteralPath $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}

$stamp        = Get-Date -Format 'yyyyMMdd-HHmmss'
$ResultsCsv   = Join-Path $OutputRoot 'import-results.csv'
$ManifestOut  = Join-Path $OutputRoot 'manifest.csv'
$TranscriptLog = Join-Path $OutputRoot "import-$stamp.log"

function Get-Field {
    # Strict-mode-safe property read: missing property or empty value yields $Default.
    # Used for optional manifest columns and optional JSON response fields.
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

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
# Discover archives (read-only enumeration of SourceRoot)
# --------------------------------------------------------------------------------------

function Get-SourceArchive {
    # Post-filter rather than -Include: -Include silently matches nothing in several
    # LiteralPath/Recurse combinations, which looks like "no files found".
    Get-ChildItem -LiteralPath $SourceRoot -Recurse -File |
        Where-Object {
            $name = $_.Name
            ($Include | Where-Object { $name -like $_ } | Select-Object -First 1) -ne $null
        } |
        Sort-Object FullName |
        ForEach-Object {
            # ApplicationFolder = first folder under SourceRoot, else '' for a flat layout
            $rel = $_.FullName.Substring($SourceRoot.Length).TrimStart('\')
            $parts = $rel -split '\\'
            $app = if ($parts.Count -gt 1) { $parts[0] } else { '' }
            [pscustomobject]@{
                FileName            = $_.Name
                FullPath            = $_.FullName
                SizeBytes           = $_.Length
                SizeMB              = [math]::Round($_.Length / 1MB, 2)
                RelativePath        = $rel
                ApplicationFolder   = $app
                BaseName            = ($_.Name -replace '\.tar\.gz$|\.tgz$|\.zip$', '')
            }
        }
}

# --------------------------------------------------------------------------------------
# Vault's own export summary as the source of truth
#
# Bulk Submission Export writes export_results.csv / manifest.csv into a
# <App>-<Sub>-export-summary.zip alongside each <App>-<Sub>.zip dossier. export_results.csv
# lists every exported submission with the relative path to its submission folder plus
# Submission record field values -- which is exactly the archive -> record mapping we need.
#
# Veeva does not publish the column schema, so columns are detected by name and then by
# value shape, and can be forced with -IdColumn / -PathColumn.
# --------------------------------------------------------------------------------------

function Import-ExportResults {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "ExportResultsCsv not found: $Path" }
    $rows = @(Import-Csv -LiteralPath $Path)
    if ($rows.Count -eq 0) { throw "ExportResultsCsv is empty: $Path" }

    $headers = @($rows[0].PSObject.Properties.Name)
    $sample  = @($rows | Select-Object -First 50)

    # --- id column ---
    $idCol = $IdColumn
    if (-not $idCol) {
        $idCol = @($headers | Where-Object { $_ -match '^(id|submission_?id|submission__v)$' }) | Select-Object -First 1
    }
    if (-not $idCol) {
        # Vault object record ids for submission__v look like 00S............
        $idCol = @($headers | Where-Object {
            $c = $_
            @($sample | ForEach-Object { "$(Get-Field $_ $c)" } | Where-Object { $_ -match '^00S[A-Za-z0-9]{8,}$' }).Count -gt 0
        }) | Select-Object -First 1
    }
    if (-not $idCol) {
        throw "Could not find a submission id column in $Path. Columns present: $($headers -join ', '). Re-run with -IdColumn <name>."
    }

    # --- path column ---
    $pathCol = $PathColumn
    if (-not $pathCol) {
        $pathCol = @($headers | Where-Object { $_ -match 'path|folder' }) | Select-Object -First 1
    }
    if (-not $pathCol) {
        $pathCol = @($headers | Where-Object {
            $c = $_
            @($sample | ForEach-Object { "$(Get-Field $_ $c)" } | Where-Object { $_ -match '[\\/]' }).Count -gt 0
        }) | Select-Object -First 1
    }
    if (-not $pathCol) {
        throw "Could not find a submission folder path column in $Path. Columns present: $($headers -join ', '). Re-run with -PathColumn <name>."
    }

    Write-Log "export_results.csv: using '$idCol' as the submission id and '$pathCol' as the submission folder path"

    $out = @{}
    foreach ($r in $rows) {
        $id  = "$(Get-Field $r $idCol)"
        $rel = "$(Get-Field $r $pathCol)".Replace('\', '/').Trim('/')
        if (-not $id -or -not $rel) { continue }

        $parts = @($rel -split '/' | Where-Object { $_ })
        if ($parts.Count -eq 0) { continue }
        $sub = $parts[-1]
        $app = if ($parts.Count -ge 2) { $parts[-2] } else { '' }

        $entry = [pscustomobject]@{
            FileName             = "$app-$sub.zip"
            ApplicationFolder    = $app
            SubmissionId         = $id
            SubmissionKey        = $sub
            ActualSubmissionDate = ''
            DossierFormatId      = ''
        }

        # Primary key: the dossier name Vault emits, "<App>-<Sub>.zip".
        $out[$entry.FileName] = $entry
        # Secondary keys for downloads that were renamed on the way out.
        foreach ($alt in @("$sub.zip", "$id.zip")) {
            if (-not $out.ContainsKey($alt)) { $out[$alt] = $entry }
        }
    }

    if ($out.Count -eq 0) { throw "No usable rows parsed from $Path" }
    Write-Log "Mapped $($rows.Count) exported submission(s) from $Path" 'OK'
    return $out
}

# --------------------------------------------------------------------------------------
# -GenerateManifest: write the mapping sheet and stop. No network, no uploads.
# --------------------------------------------------------------------------------------

if ($GenerateManifest) {
    $archives = @(Get-SourceArchive)
    if ($archives.Count -eq 0) { throw "No archives matching $($Include -join ', ') found under $SourceRoot" }

    $fromExport = @{}
    if ($ExportResultsCsv) { $fromExport = Import-ExportResults -Path $ExportResultsCsv }

    $resolved = 0
    $archives | ForEach-Object {
        $a = $_
        $hit = $null
        if ($fromExport.ContainsKey($a.FileName))      { $hit = $fromExport[$a.FileName] }
        elseif ($fromExport.ContainsKey("$($a.BaseName).zip")) { $hit = $fromExport["$($a.BaseName).zip"] }

        $subId = ''
        if ($hit)                    { $subId = $hit.SubmissionId; $resolved++ }
        elseif ($NameIsSubmissionId) { $subId = $a.BaseName;       $resolved++ }

        [pscustomobject]@{
            FileName             = $a.FileName
            RelativePath         = $a.RelativePath
            SizeMB               = $a.SizeMB
            ApplicationFolder    = if ($hit -and $hit.ApplicationFolder) { $hit.ApplicationFolder } else { $a.ApplicationFolder }
            SubmissionId         = $subId
            SubmissionKey        = if ($hit) { $hit.SubmissionKey } else { $a.BaseName }
            ActualSubmissionDate = ''
            DossierFormatId      = ''
        }
    } | Export-Csv -LiteralPath $ManifestOut -NoTypeInformation -Encoding UTF8

    Write-Log "Wrote manifest for $($archives.Count) archive(s), $resolved with SubmissionId already filled in: $ManifestOut" 'OK'
    if ($resolved -lt $archives.Count) {
        Write-Log "Fill in SubmissionId for the remaining $($archives.Count - $resolved) row(s), or leave SubmissionKey for VQL lookup on $LookupField." 'INFO'
    }
    return
}

# --------------------------------------------------------------------------------------
# Session id
#
# $script:SessionId is the single source of truth for the Vault session. It is:
#   seeded  here, once, from the -SessionId CONFIG value (blank means "log in for me")
#   written only by Connect-Vault, on first login and on re-auth after expiry
#   read    only by Invoke-VaultApi, which stamps it into the Authorization header
#
# Nothing else in the script touches it, and no function takes a session id as an
# argument. That is what makes the mid-run re-auth safe: the header is rebuilt from
# this variable on every attempt, so a refreshed session is picked up immediately by
# whatever call was in flight.
#
# Vault expects the raw session id in Authorization -- no "Bearer " prefix.
# --------------------------------------------------------------------------------------

$script:BaseUrl   = "https://$VaultDNS/api/$ApiVersion"
$script:SessionId = $SessionId
$script:Cred      = $Credential

function Connect-Vault {
    if (-not $script:Cred) {
        $script:Cred = Get-Credential -Message "Vault credentials for $VaultDNS"
    }
    $body = @{
        username = $script:Cred.UserName
        password = $script:Cred.GetNetworkCredential().Password
    }
    $r = Invoke-RestMethod -Method Post -Uri "$script:BaseUrl/auth" -Body $body `
            -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' }
    if ($r.responseStatus -ne 'SUCCESS') {
        throw "Authentication failed: $($r | ConvertTo-Json -Depth 5 -Compress)"
    }
    $script:SessionId = $r.sessionId
    Write-Log "Authenticated to $VaultDNS (vaultId $($r.vaultId), userId $($r.userId))" 'OK'
}

# --------------------------------------------------------------------------------------
# Core request helper: retries, session refresh, burst-limit backoff
# --------------------------------------------------------------------------------------

function Invoke-VaultApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,             # relative to /api/{version}
        $Body,
        [string]$ContentType,
        [hashtable]$ExtraHeaders = @{},
        [int]$TimeoutSec = 900,
        [switch]$NoRetryOn4xx
    )

    $uri = if ($Path -match '^https?://') { $Path } else { "$script:BaseUrl$Path" }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $headers = @{ Authorization = $script:SessionId; Accept = 'application/json' }
        foreach ($k in $ExtraHeaders.Keys) { $headers[$k] = $ExtraHeaders[$k] }

        try {
            # NB: not $args -- that is an automatic variable and clobbering it breaks splatting.
            $req = @{
                Method          = $Method
                Uri             = $uri
                Headers         = $headers
                TimeoutSec      = $TimeoutSec
                UseBasicParsing = $true
            }
            if ($null -ne $Body)  { $req['Body'] = $Body }
            if ($ContentType)     { $req['ContentType'] = $ContentType }

            $resp = Invoke-WebRequest @req

            # Burst limit is a rolling 5-minute window; back off before Vault throttles us.
            $remaining = $resp.Headers['X-VaultAPI-BurstLimitRemaining']
            if ($remaining -and [int]$remaining -lt 200) {
                Write-Log "Burst limit low ($remaining remaining) - pausing 30s" 'WARN'
                Start-Sleep -Seconds 30
            }

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
            $transient = (-not $status) -or ($status -ge 500) -or ($status -eq 429)

            if ($status -eq 429) {
                Write-Log "HTTP 429 rate limited - waiting 60s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            if (-not $transient -or $NoRetryOn4xx -or $attempt -eq $MaxRetries) {
                $detail = ''
                try {
                    $sr = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                    $detail = $sr.ReadToEnd()
                } catch { }
                throw "$Method $Path failed (HTTP $status): $($_.Exception.Message) $detail"
            }
            $wait = [math]::Pow(2, $attempt) * 5
            Write-Log "Transient error on $Method $Path (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
            Start-Sleep -Seconds $wait
        }
    }
    throw "$Method $Path failed after $MaxRetries attempts"
}

# --------------------------------------------------------------------------------------
# File Staging
# --------------------------------------------------------------------------------------

function New-StagingFolder {
    param([Parameter(Mandatory)][string]$Path)   # e.g. /SubmissionsArchive/nda123456
    try {
        Invoke-VaultApi -Method POST -Path '/services/file_staging/items' `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{ kind = 'folder'; path = $Path; overwrite = 'false' } | Out-Null
        Write-Log "Staging folder ready: $Path"
    }
    catch {
        # Already-exists is the normal case on re-runs; anything else is real.
        if ("$_" -match 'exist') { Write-Log "Staging folder already present: $Path" }
        else { throw }
    }
}

function Send-StagingFile {
    <#
      Uploads via a resumable session for every file, regardless of size:
      one code path, binary-safe on PowerShell 5.1 (no multipart assembly), restartable,
      and the only supported route above 50 MB.
      Returns the staging path of the committed file.
    #>
    param(
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$StagingPath   # full destination path incl. file name
    )

    $fi        = Get-Item -LiteralPath $LocalPath
    $partSize  = $PartSizeMB * 1MB
    $totalSize = $fi.Length
    $partCount = [math]::Max(1, [math]::Ceiling($totalSize / $partSize))

    if ($partCount -gt 2000) {
        throw "$($fi.Name) needs $partCount parts; Vault allows 2000. Raise -PartSizeMB (max 50) or split the archive."
    }

    $session = Invoke-VaultApi -Method POST -Path '/services/file_staging/upload' `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ path = $StagingPath; size = $totalSize; overwrite = 'true' }

    $sdata = Get-Field $session 'data' $null
    $sid   = Get-Field $sdata 'upload_session_id' (Get-Field $sdata 'id' '')
    if (-not $sid) { throw "No upload session id returned for $($fi.Name)" }

    Write-Log ("Uploading {0} ({1:N1} MB, {2} part(s), session {3})" -f $fi.Name, ($totalSize / 1MB), $partCount, $sid)

    $md5 = [Security.Cryptography.MD5]::Create()
    # FileShare::Read -- the source download is never locked for writing by this script.
    $fs  = New-Object IO.FileStream($fi.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $buffer = New-Object byte[] $partSize
        for ($part = 1; $part -le $partCount; $part++) {
            $read = $fs.Read($buffer, 0, $partSize)
            if ($read -le 0) { break }

            # Array.Copy, not $buffer[0..$n] -- the range operator on a 50 MB buffer is
            # pathologically slow and allocates an object[] of 50 million elements.
            $chunk = $buffer
            if ($read -ne $partSize) {
                $chunk = New-Object byte[] $read
                [Array]::Copy($buffer, 0, $chunk, 0, $read)
            }
            $hash = [Convert]::ToBase64String($md5.ComputeHash($chunk))

            Invoke-VaultApi -Method PUT -Path "/services/file_staging/upload/$sid" `
                -ContentType 'application/octet-stream' -Body $chunk `
                -ExtraHeaders @{ 'X-VaultAPI-FilePartNumber' = "$part"; 'Content-MD5' = $hash } | Out-Null

            Write-Log ("  part {0}/{1} ({2:N1} MB) ok" -f $part, $partCount, ($read / 1MB))
        }
    }
    finally {
        $fs.Close(); $fs.Dispose(); $md5.Dispose()
    }

    Invoke-VaultApi -Method POST -Path "/services/file_staging/upload/$sid" | Out-Null
    Write-Log "Committed to staging: $StagingPath" 'OK'
    return $StagingPath
}

# --------------------------------------------------------------------------------------
# Submission lookup, import, job polling
# --------------------------------------------------------------------------------------

function Resolve-SubmissionId {
    param([Parameter(Mandatory)][string]$Key)
    $escaped = $Key.Replace("'", "\'")
    $q = "SELECT id, name__v FROM submission__v WHERE $LookupField = '$escaped'"
    $r = Invoke-VaultApi -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' -Body @{ q = $q }
    $rows = @($r.data)
    if ($rows.Count -eq 0) { throw "No submission__v record where $LookupField = '$Key'" }
    if ($rows.Count -gt 1) { throw "$($rows.Count) submission__v records match $LookupField = '$Key' -- set SubmissionId explicitly in the manifest" }
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

function Wait-VaultJob {
    param([Parameter(Mandatory)]$JobId)

    $running  = @('SCHEDULED','QUEUING','QUEUED','RUNNING','IN_PROGRESS')
    $deadline = (Get-Date).AddMinutes($JobTimeoutMinutes)

    while ((Get-Date) -lt $deadline) {
        $r = Invoke-VaultApi -Method GET -Path "/services/jobs/$JobId"
        $status = "$(Get-Field (Get-Field $r 'data' $null) 'status' '')".ToUpperInvariant()
        if ($status -and ($running -notcontains $status)) {
            return $status
        }
        Start-Sleep -Seconds $JobPollSeconds
    }
    return "TIMEOUT_AFTER_${JobTimeoutMinutes}_MIN"
}

function Get-ImportResult {
    param([Parameter(Mandatory)][string]$SubmissionId, [Parameter(Mandatory)]$JobId)
    try {
        $r = Invoke-VaultApi -Method GET -Path "/vobjects/submission__v/$SubmissionId/actions/import/$JobId/results"

        # Note: Vault 26R3 (Dec 2026) stops returning the `data` array here; the endpoint
        # keeps working and importMessages remains. Hence the tolerant reads below.
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
# Build the work list
# --------------------------------------------------------------------------------------

$archives = @(Get-SourceArchive)
if ($archives.Count -eq 0) { throw "No archives matching $($Include -join ', ') found under $SourceRoot" }
Write-Log "Found $($archives.Count) archive(s) under $SourceRoot (read-only)"

$map = @{}
if ($ExportResultsCsv) {
    # Highest-fidelity source: Vault generated it during the export.
    $map = Import-ExportResults -Path $ExportResultsCsv
}
if ($Manifest) {
    if (-not (Test-Path -LiteralPath $Manifest)) { throw "Manifest not found: $Manifest" }
    $n = 0
    foreach ($row in (Import-Csv -LiteralPath $Manifest)) {
        $fn = Get-Field $row 'FileName'
        if ($fn) { $map[$fn] = $row; $n++ }   # a hand-edited manifest overrides the export csv
    }
    Write-Log "Loaded manifest with $n row(s): $Manifest"
}
if (-not $ExportResultsCsv -and -not $Manifest -and -not $NameIsSubmissionId) {
    Write-Log "No -ExportResultsCsv, -Manifest or -NameIsSubmissionId: application folder comes from the directory layout and the submission is resolved by VQL on $LookupField = <file base name>." 'WARN'
}

# Skip anything already imported successfully in a previous run.
$done = @{}
if (Test-Path -LiteralPath $ResultsCsv) {
    foreach ($row in (Import-Csv -LiteralPath $ResultsCsv)) {
        if ($row.Status -eq 'SUCCESS') { $done[$row.FileName] = $true }
    }
    if ($done.Count) { Write-Log "$($done.Count) archive(s) already SUCCESS in $ResultsCsv - they will be skipped" }
}

if (-not $script:SessionId) { Connect-Vault }

# --------------------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------------------

$results   = New-Object System.Collections.ArrayList
$createdIn = @{}
$i = 0

foreach ($a in $archives) {
    $i++
    $prefix = "[$i/$($archives.Count)] $($a.FileName)"

    if ($done.ContainsKey($a.FileName)) { Write-Log "$prefix - skipped (already SUCCESS)"; continue }

    $row = $null
    if ($map.ContainsKey($a.FileName))                    { $row = $map[$a.FileName] }
    elseif ($map.ContainsKey("$($a.BaseName).zip"))       { $row = $map["$($a.BaseName).zip"] }

    $appFolder = Get-Field $row 'ApplicationFolder'    $a.ApplicationFolder
    $subKey    = Get-Field $row 'SubmissionKey'        $a.BaseName
    $subId     = Get-Field $row 'SubmissionId'         $(if ($NameIsSubmissionId) { $a.BaseName } else { '' })
    $dossier   = Get-Field $row 'DossierFormatId'      $DefaultDossierFormatId
    $subDate   = Get-Field $row 'ActualSubmissionDate' ''

    $record = [ordered]@{
        FileName          = $a.FileName
        SourcePath        = $a.FullPath
        SizeMB            = $a.SizeMB
        ApplicationFolder = $appFolder
        StagingPath       = ''
        SubmissionKey     = $subKey
        SubmissionId      = $subId
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
            throw "No ApplicationFolder for $($a.FileName) -- set it in the manifest or put the archive in a per-application subfolder."
        }

        $stagingFolder = "$StagingRoot/$appFolder"
        $stagingPath   = "$stagingFolder/$($a.FileName)"
        $record.StagingPath = $stagingPath

        if (-not $subId) {
            # Read-only VQL, so it runs under -WhatIf too -- that is what makes the dry run
            # worth doing: a bad SubmissionKey surfaces before anything is uploaded.
            Write-Log "$prefix - resolving submission by $LookupField = '$subKey'"
            $subId = Resolve-SubmissionId -Key $subKey
            $record.SubmissionId = $subId
        }

        if ($PSCmdlet.ShouldProcess("$stagingPath -> submission $subId", 'Upload and import')) {
            if (-not $createdIn.ContainsKey($stagingFolder)) {
                New-StagingFolder -Path $stagingFolder
                $createdIn[$stagingFolder] = $true
            }

            Send-StagingFile -LocalPath $a.FullPath -StagingPath $stagingPath | Out-Null

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
            Write-Log "$prefix - WhatIf: would upload to $stagingPath and import into submission $subId"
        }
    }
    catch {
        $record.Status   = 'ERROR'
        $record.Messages = "$_"
        Write-Log "$prefix - ERROR: $_" 'ERROR'
    }

    $record.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
    [void]$results.Add([pscustomobject]$record)

    # Flush after every archive so an interrupted run still leaves a usable CSV.
    $results | Export-Csv -LiteralPath $ResultsCsv -NoTypeInformation -Encoding UTF8
}

# --------------------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------------------

$ok    = @($results | Where-Object Status -eq 'SUCCESS').Count
$bad   = @($results | Where-Object { $_.Status -notin @('SUCCESS','WHATIF') }).Count
$what  = @($results | Where-Object Status -eq 'WHATIF').Count

Write-Log '----------------------------------------------------------------'
Write-Log "Processed $($results.Count) archive(s): $ok succeeded, $bad failed, $what dry-run" $(if ($bad) { 'WARN' } else { 'OK' })
Write-Log "Results CSV : $ResultsCsv"
Write-Log "Log         : $TranscriptLog"
Write-Log "Source files untouched in: $SourceRoot"

if ($bad -gt 0) { exit 1 }
