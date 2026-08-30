<#
.SUPERSEDED
    Kept for reference, no longer shipped by refresh.bat.

    MODE = EXPORT here writes to the SOURCE vault's File Staging, which is the approach
    the migration moved away from - Transfer-VaultDocuments.ps1 downloads straight from
    the document instead and never touches source staging. MODE = REPORT still gives a
    size projection for an id list, and MODE = UPDATE still does bulk field edits, but
    neither is part of the current path.

.SYNOPSIS
    Runs a Library bulk action against Vault documents from a VQL query, instead of
    clicking through Refine Selection -> Choose Action -> Edit Details in the UI.

.DESCRIPTION
    A saved Library view (e.g. "Insert Product for Document Extraction") is not
    reachable over the API - saved views, their filters and the grid's Export to
    Text/Excel are UI-only. What IS reachable is the query behind it. This script:

      1. Rebuilds the view's filters as VQL and runs it, paging through every match.
      2. Writes what it found to documents.csv - the API-side equivalent of the
         grid's Export to Excel, and the thing to eyeball before changing anything.
      3. Then, depending on MODE, either stops, bulk-updates field values on those
         documents, or exports them to File Staging.

    Bulk update goes through Update Multiple Documents, which caps at 1,000
    documents per call - the same 1,000 the UI offers as "First 1000 Documents".
    A view matching 5,200 documents is therefore six batches, not one.

    Re-runnable: documents already recorded as SUCCESS are skipped.

.PARAMETER ConfigFile
    All settings live in documents.ini beside this script. Command line overrides it.

.PARAMETER SamplePercent
    Process a random percentage (1-100) of the documents found instead of all of
    them. 0 = no sampling. Rounded up, so a small percentage still picks at least
    one. A fresh sample is drawn every run.

.NOTES
    Windows PowerShell 5.1 compatible (also runs on PowerShell 7).
    Endpoints, all relative to https://<VaultDNS>/api/<ApiVersion>:
      POST /auth                                          log in
      POST /query                                         the view's filters, as VQL
      GET  /metadata/objects/documents/properties         document fields (editable:true)
      GET  /metadata/objects/documents/types              document types
      PUT  /objects/documents/batch                       bulk field update (max 1000)
      POST /objects/documents/batch/actions/fileextract   export to File Staging
      GET  /services/jobs/{job_id}                        poll the export job
      GET  /objects/documents/batch/actions/fileextract/{job_id}/results
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # ======================================================================================
    #  All configuration lives in ONE file: documents.ini, next to this script.
    #  Precedence:  command line  >  documents.ini  >  the defaults here
    # ======================================================================================

    [string]     $ConfigFile       = '',

    # ---- Required ----
    [string]     $VaultDNS         = '',

    # Local folder for the CSV reports and log. Nothing else is written locally.
    [string]     $OutputRoot       = '',

    # ---- Vault ----
    [ValidatePattern('^v\d+\.\d+$')]
    [string]     $ApiVersion       = 'v26.2',

    # The ONLY place a session id is configured. Blank = log in and manage it for me.
    [string]     $SessionId        = '',

    [pscredential] $Credential,

    # Withhold every write, whatever MODE says. Same as -WhatIf, but settable in the
    # ini so it survives a double-click. Works for EXPORT as well as UPDATE.
    [switch]     $DryRun,

    # ---- Which documents ----
    #
    # A local .txt of document ids, one per line. When set, nothing is queried: this
    # IS the document list. Blank lines, #-comments and an "id" header are ignored,
    # duplicates are dropped. Highest precedence of the three.
    #
    # Defaults to sourcedocids.txt, picked up automatically when that file sits beside
    # the script - so an older documents.ini with no IdFile line still uses it. If the
    # file is absent the run falls through to the filters below instead of failing.
    # Naming a file explicitly is different: then a missing file IS an error.
    [string]     $IdFile           = 'sourcedocids.txt',

    # Otherwise: hand the whole query over in Vql, or leave that blank and let the
    # filter settings below build it. Vql wins over the filters.
    [string]     $Vql              = '',

    # Fields to pull back. id is always included whether it is listed or not.
    [string[]]   $SelectFields     = @('id', 'name__v', 'type__v', 'size__v', 'major_version_number__v', 'minor_version_number__v'),

    # Product filter. A product record id (00P...) is exact and always safe. A plain
    # name is matched against ProductNameField instead, which requires that field to
    # exist on documents in this vault.
    [string]     $Product          = '',
    [string]     $ProductField     = 'product__v',

    # Document types to KEEP. This is the allowlist, and it is the safer of the two:
    # a type added to the vault later is excluded by default rather than swept in.
    # Becomes  type__v CONTAINS ('A', 'B', ...)  which is VQL's OR-of-values.
    # Document queries match on LABELS by default, so use what the UI shows.
    [string[]]   $IncludeTypes     = @(),

    # Document types to leave out - the UI's "Document Types not in (...)" filter.
    # VQL has no NOT IN: this becomes a chain of type__v != '...' AND ...
    # Ignored when IncludeTypes is set.
    [string[]]   $ExcludeTypes     = @(),

    # Anything else, appended to the WHERE clause verbatim. Your escaping, your risk.
    [string]     $Where            = '',

    # Cap on how many documents to act on at all. 0 = no cap. Use it to prove the
    # plumbing on ten documents before turning it loose on five thousand.
    [int]        $MaxDocuments     = 0,

    [ValidateRange(0, 100)]
    [int]        $SamplePercent    = 0,

    # ---- What to do with them ----
    #
    # Field values to write, as name=value pairs separated by | (a pipe, because
    # documents.ini treats " ;" as the start of a comment).
    #    SetFields = product__v=00P1110|country__v=00C0001
    # A value of null clears the field. Only the latest version of each document is
    # updated; past versions need Update Document Version, which this does not do.
    [string]     $SetFields        = '',

    # Repeating (multi-value) fields are refused by default - see Test-UpdateField.
    # Set this only once you have confirmed what Vault does with a repeating field in
    # THIS vault, on documents you can afford to be wrong about.
    [switch]     $AllowRepeatingFields,

    # Export options, used in EXPORT mode. text=true is the one to use if what you
    # want out is document text rather than the source files.
    [bool]       $ExportSource     = $true,
    [bool]       $ExportRenditions = $false,
    [bool]       $ExportAllVersions = $false,
    [bool]       $ExportText       = $false,

    # ---- Existing output reports ----
    # What to do when this run's CSV reports are already sitting in OutputRoot from
    # an earlier run.
    #   Prompt  = ask (default). Non-interactive hosts fall back to Resume.
    #   Resume  = keep them: skip what already succeeded, carry the old rows forward.
    #   Restart = rotate them aside to <name>-<when they were written>.csv, start clean.
    [ValidateSet('Prompt', 'Resume', 'Restart')]
    [string]     $ExistingResults  = 'Prompt',

    # ---- Advanced ----
    # Vault's own ceiling is 1,000 per call and the API rejects more. Lower it if you
    # want smaller, more frequent checkpoints in the results CSV.
    [ValidateRange(1, 1000)]
    [int]        $BatchSize        = 1000,

    [ValidateRange(1, 1000)]
    [int]        $PageSize         = 1000,

    [int]        $JobTimeoutMinutes = 120,
    [int]        $JobPollSeconds   = 20,
    [int]        $MaxRetries       = 4
)

$ScriptVersion = '2026.08.30-12'

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

function ConvertTo-VqlLiteral {
    # Escape a value for a single-quoted VQL string literal.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return $Value.Replace('\', '\\').Replace("'", "\'")
}

function ConvertTo-CsvValue {
    # RFC 4180 field: quote when the value holds a comma, quote, CR or LF.
    param([AllowNull()]$Value)
    $s = "$Value"
    if ($s -match '[",\r\n]') { return '"' + $s.Replace('"', '""') + '"' }
    return $s
}

# --------------------------------------------------------------------------------------
# Configuration: one file, one load
# --------------------------------------------------------------------------------------

$IntKeys    = @('MaxDocuments', 'SamplePercent', 'BatchSize', 'PageSize',
                'JobTimeoutMinutes', 'JobPollSeconds', 'MaxRetries')
$BoolKeys   = @('ExportSource', 'ExportRenditions', 'ExportAllVersions', 'ExportText')
$SwitchKeys = @('AllowRepeatingFields', 'DryRun')
$ListKeys   = @('SelectFields', 'IncludeTypes', 'ExcludeTypes')

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
    $ConfigFile = Join-Path $here 'documents.ini'
}

$ConfigMode = ''
if (Test-Path -LiteralPath $ConfigFile) {
    $cfg = Import-ConfigFile -Path $ConfigFile
    foreach ($key in $cfg.Keys) {
        $value = $cfg[$key]
        if ($key -eq 'MODE') { $ConfigMode = $value.ToUpperInvariant(); continue }
        if ($PSBoundParameters.ContainsKey($key)) { continue }
        if (-not (Get-Variable -Name $key -Scope Script -ErrorAction SilentlyContinue)) {
            Write-Warning "documents.ini: ignoring unknown setting '$key'"
            continue
        }
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        if     ($IntKeys    -contains $key) { Set-Variable -Name $key -Value ([int]$value) -WhatIf:$false }
        elseif ($BoolKeys   -contains $key) { Set-Variable -Name $key -Value ([bool]($value -match '^(1|true|yes|on)$')) -WhatIf:$false }
        elseif ($SwitchKeys -contains $key) { Set-Variable -Name $key -Value ([bool]($value -match '^(1|true|yes|on)$')) -WhatIf:$false }
        elseif ($ListKeys -contains $key) { Set-Variable -Name $key -Value ([string[]]($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) -WhatIf:$false }
        else                              { Set-Variable -Name $key -Value $value -WhatIf:$false }
    }
}
elseif ($ConfigExplicit) { throw "Config file not found: $ConfigFile" }
else { Write-Warning "No documents.ini found at $ConfigFile - relying on command-line arguments." }

# refresh.bat deliberately never overwrites documents.ini, which means an ini written
# against an older version silently lacks any setting added since. Say so rather than
# letting a missing key look like a setting that did not work.
if ($cfg) {
    $known = @($MyInvocation.MyCommand.Parameters.Keys)
    $newer = @($known | Where-Object {
        $_ -notin @('ConfigFile','Credential','Verbose','Debug','ErrorAction','WarningAction',
                    'InformationAction','ErrorVariable','WarningVariable','InformationVariable',
                    'OutVariable','OutBuffer','PipelineVariable','WhatIf','Confirm','ProgressAction') -and
        -not $cfg.Contains($_)
    })
    if ($newer.Count) {
        $shown = @($newer | Sort-Object)
        $tail  = ''
        if ($shown.Count -gt 10) { $tail = " (+$($shown.Count - 10) more)"; $shown = @($shown | Select-Object -First 10) }
        Write-Warning "documents.ini does not mention $($newer.Count) setting(s), all running on defaults:"
        Write-Warning "  $($shown -join ', ')$tail"
        Write-Warning '  If you expected one of those to apply, add the line - refresh.bat never'
        Write-Warning '  overwrites documents.ini, so an older ini lacks anything added since.'
    }
}

# Resolve IdFile against the script's own folder as well as the working directory - a
# .bat double-clicked from Explorer does not necessarily run with its folder as the CWD.
$IdFileExplicit = $PSBoundParameters.ContainsKey('IdFile')
if ($cfg -and $cfg.Contains('IdFile') -and -not [string]::IsNullOrWhiteSpace($cfg['IdFile'])) { $IdFileExplicit = $true }

if ($IdFile) {
    # Say WHERE it looked. "Not found" on its own sends you hunting; the two absolute
    # paths tell you immediately whether the file is missing or merely somewhere else.
    $looked = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $IdFile)) {
        [void]$looked.Add([IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $IdFile)))
        $here2 = $PSScriptRoot
        if (-not $here2) { $here2 = (Get-Location).ProviderPath }
        $beside = Join-Path $here2 $IdFile
        if (Test-Path -LiteralPath $beside) { $IdFile = $beside }
        elseif ($beside -ne $looked[0]) { [void]$looked.Add($beside) }
    }
    if (-not (Test-Path -LiteralPath $IdFile)) {
        $where = ($looked | ForEach-Object { "    $_" }) -join "`n"
        if ($IdFileExplicit) {
            throw "IdFile not found. Looked in:`n$where"
        }
        Write-Warning "No $IdFile found. Looked in:"
        foreach ($l in $looked) { Write-Warning "    $l" }
        Write-Warning 'Falling back to the filter settings. Put the file at one of those paths to work from a list instead.'
        $IdFile = ''
    }
}

if (-not $ConfigMode) { $ConfigMode = 'REPORT' }
$Updates_Pending = -not [string]::IsNullOrWhiteSpace($SetFields)
switch ($ConfigMode) {
    'REPORT' { }   # query only: documents.csv plus the field/type reference CSVs
    'DRYRUN' { }
    'UPDATE' { }
    'EXPORT' { }
    default  { throw "documents.ini: MODE must be REPORT, DRYRUN, UPDATE or EXPORT (got '$ConfigMode')." }
}

# MODE names the action; DRYRUN names an intent but not an action, so infer which one
# was meant. SetFields set means an update rehearsal, otherwise an export rehearsal.
# Getting this wrong used to make MODE = DRYRUN demand SetFields even when the run was
# only ever going to be an export.
$Action = $ConfigMode
if ($ConfigMode -eq 'DRYRUN') {
    $Action = if ($Updates_Pending) { 'UPDATE' } else { 'EXPORT' }
}
if (($DryRun -or $ConfigMode -eq 'DRYRUN') -and -not $PSBoundParameters.ContainsKey('WhatIf')) {
    $WhatIfPreference = $true
}

foreach ($name in @('VaultDNS', 'OutputRoot')) {
    if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $name -ValueOnly))) {
        throw "$name is not set. Add it to $ConfigFile, or pass -$name on the command line."
    }
}
$VaultDNS = $VaultDNS -replace '^https?://', '' -replace '/+$', ''

$OutputRoot = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $OutputRoot))
# Trim the trailing separator, except on a drive root - "C:\" trimmed to "C:" means
# "the current directory on C:", which is not what anyone typing C:\ meant.
if ($OutputRoot.Length -gt 3) { $OutputRoot = $OutputRoot.TrimEnd('\') }
if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force -WhatIf:$false | Out-Null }

$stamp         = Get-Date -Format 'yyyyMMdd-HHmmss'
$DocumentsCsv  = Join-Path $OutputRoot 'documents.csv'
$ResultsCsv    = Join-Path $OutputRoot 'document-results.csv'
$FieldsCsv     = Join-Path $OutputRoot 'document-fields.csv'
$TypesCsv      = Join-Path $OutputRoot 'document-types.csv'
$TranscriptLog = Join-Path $OutputRoot "documents-$stamp.log"

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line }
    }
    Add-Content -LiteralPath $TranscriptLog -Value $line -Encoding UTF8 -WhatIf:$false
}

# --------------------------------------------------------------------------------------
# Field updates: parse SetFields once, up front
#
# Done before authenticating so a typo in documents.ini is reported immediately rather
# than after a five-thousand-row query.
# --------------------------------------------------------------------------------------

$Updates = [ordered]@{}
if ($SetFields) {
    foreach ($pair in ($SetFields -split '\|')) {
        $p = $pair.Trim()
        if (-not $p) { continue }
        $eq = $p.IndexOf('=')
        if ($eq -lt 1) { throw "SetFields: '$p' is not a name=value pair. Separate pairs with | (a pipe)." }
        $n = $p.Substring(0, $eq).Trim()
        $v = $p.Substring($eq + 1).Trim()
        if ($n -ieq 'id') { throw "SetFields: id is the key, it cannot be updated." }
        $Updates[$n] = $v
    }
}
if ($Action -eq 'UPDATE' -and $Updates.Count -eq 0) {
    throw "MODE is $ConfigMode but SetFields is empty - there is nothing to write. Set it in $ConfigFile."
}

# --------------------------------------------------------------------------------------
# Existing output reports
#
# The CSV reports this run writes may already be in OutputRoot from an earlier run.
# Continuing is usually right: it skips what already succeeded and keeps the old rows.
# But if the last run was a different view or a different field, those rows are not
# this run's, and you want a clean sheet.
#
# Restarting ROTATES, it never deletes: the old report is renamed to carry the time it
# was written, so the record survives and the new run starts empty.
# --------------------------------------------------------------------------------------

function Get-ReportSummary {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $rows = @(Import-Csv -LiteralPath $Path)
        if ($rows.Count -eq 0) { return 'empty' }
        $ok  = @($rows | Where-Object { (Get-Field $_ 'Status') -eq 'SUCCESS' }).Count
        $when = (Get-Item -LiteralPath $Path).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        return "$($rows.Count) row(s), $ok SUCCESS, last written $when"
    }
    catch { return 'unreadable' }
}

function Move-ExistingReport {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $when = (Get-Item -LiteralPath $Path).LastWriteTime.ToString('yyyyMMdd-HHmmss')
    $moved = [IO.Path]::Combine([IO.Path]::GetDirectoryName($Path),
             ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($Path), $when, [IO.Path]::GetExtension($Path)))
    Move-Item -LiteralPath $Path -Destination $moved -Force -WhatIf:$false
    Write-Log "Rotated $([IO.Path]::GetFileName($Path)) -> $([IO.Path]::GetFileName($moved))"
}

$existing = @($DocumentsCsv, $ResultsCsv | Where-Object { Test-Path -LiteralPath $_ })
if ($existing.Count) {
    $choice = $ExistingResults
    if ($choice -eq 'Prompt') {
        Write-Host ''
        Write-Host 'Reports from an earlier run are already in this folder:' -ForegroundColor Yellow
        foreach ($f in $existing) { Write-Host ('  {0,-22} {1}' -f [IO.Path]::GetFileName($f), (Get-ReportSummary -Path $f)) }
        Write-Host ''
        if ($Host.UI.RawUI -and -not [Console]::IsInputRedirected) {
            $answer = Read-Host 'Resume (keep them, skip what already succeeded) or Restart (rotate aside, start fresh)? [R]esume/[S]tart fresh'
            $choice = if ($answer -match '^[Ss]') { 'Restart' } else { 'Resume' }
        }
        else {
            Write-Host 'Non-interactive host - resuming.' -ForegroundColor Yellow
            $choice = 'Resume'
        }
    }
    if ($choice -eq 'Restart') { foreach ($f in $existing) { Move-ExistingReport -Path $f } }
    else { Write-Log 'Resuming: rows already SUCCESS will be skipped and carried forward.' }
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

$script:BaseUrl     = "https://$VaultDNS/api/$ApiVersion"
$script:SessionId   = $SessionId
$script:Cred        = $Credential
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

function Connect-Vault {
    if (-not $script:Cred) { $script:Cred = Get-Credential -Message "Vault credentials for $VaultDNS" }
    $body = @{ username = $script:Cred.UserName; password = $script:Cred.GetNetworkCredential().Password }
    $r = Invoke-RestMethod -Method Post -Uri "$script:BaseUrl/auth" -Body $body `
            -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' }
    if ((Get-Field $r 'responseStatus') -ne 'SUCCESS') { throw "Authentication failed: $($r | ConvertTo-Json -Depth 5 -Compress)" }
    $sid = "$(Get-Field $r 'sessionId' '')"
    if (-not $sid) { throw "Authentication returned no sessionId. Vault said: $($r | ConvertTo-Json -Depth 5 -Compress)" }
    $script:SessionId = $sid
    Write-Log "Authenticated to $VaultDNS (vaultId $(Get-Field $r 'vaultId' '?'), userId $(Get-Field $r 'userId' '?'))" 'OK'
    # Refresh the cache so the NEXT run does not prompt either, and so a mid-run
    # re-auth leaves a working session behind rather than a stale one.
    if ($script:SessionFile) {
        try { Set-Content -LiteralPath $script:SessionFile -Value $r.sessionId -Encoding ASCII -NoNewline -WhatIf:$false } catch { }
    }
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

    # Three shapes of Path arrive here and they are not interchangeable:
    #   https://...        a full URL (File Staging pagination hands these back)
    #   /api/v26.2/query   host-relative and ALREADY carrying the api prefix - this is
    #                      what VQL next_page returns, and prefixing BaseUrl onto it
    #                      would produce .../api/v26.2/api/v26.2/query
    #   /query             our own calls, relative to BaseUrl
    $uri =
        if     ($Path -match '^https?://') { $Path }
        elseif ($Path -match '^/api/')     { "https://$VaultDNS$Path" }
        else                               { "$script:BaseUrl$Path" }

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
        catch {
            # Windows PowerShell 5.1 throws WebException here; PowerShell 7 throws
            # HttpResponseException for an HTTP status and HttpRequestException for a
            # transport failure. Matching on the type NAME covers all three without
            # needing System.Net.Http to be loadable on 5.1. Anything else - a real bug
            # in this script - is rethrown immediately rather than retried four times.
            $ex   = $_.Exception
            $name = $ex.GetType().Name
            if ($name -notin @('WebException', 'HttpResponseException', 'HttpRequestException')) { throw }

            $status = $null
            try { if ($ex.Response) { $status = [int]$ex.Response.StatusCode } } catch { }

            if ($status -eq 429) {
                Write-Log "HTTP 429 rate limited - waiting 60s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            $transient = (-not $status) -or ($status -ge 500)
            if (-not $transient -or $attempt -eq $MaxRetries) {
                # 5.1 leaves the body on the response stream; 7 has already read it into
                # ErrorDetails. Try both, take whichever produced something.
                $detail = ''
                try { $detail = "$(Get-Field $_ 'ErrorDetails' $null | Select-Object -ExpandProperty Message -ErrorAction SilentlyContinue)" } catch { }
                if (-not $detail) {
                    try { $detail = (New-Object IO.StreamReader($ex.Response.GetResponseStream())).ReadToEnd() } catch { }
                }
                throw "$Method $Path failed (HTTP $status): $($ex.Message) $detail"
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
# The query behind the view
# --------------------------------------------------------------------------------------

function New-DocumentVql {
    # Rebuild a Library view's filters as VQL. Three things about document VQL that
    # trip up a direct translation from the UI:
    #   - There is no NOT IN, and NOT is only legal inside a FIND clause. "Document
    #     Types not in (a, b, c)" has to become type__v != 'a' AND type__v != 'b' ...
    #   - IN is not a value list either; it only works as an inner-join subquery.
    #   - Document queries match on field LABELS by default, which is why the excluded
    #     types are spelled the way the UI spells them.
    $fields = @('id') + @($SelectFields | Where-Object { $_ -and $_ -ne 'id' })
    $fields = @($fields | Select-Object -Unique)

    $clauses = New-Object System.Collections.ArrayList
    if ($Product) {
        [void]$clauses.Add("$ProductField = '$(ConvertTo-VqlLiteral $Product)'")
    }
    if ($IncludeTypes.Count) {
        # CONTAINS is VQL's OR-of-values. Not IN - that is inner-join subqueries only.
        $list = ($IncludeTypes | Where-Object { $_ } | ForEach-Object { "'$(ConvertTo-VqlLiteral $_)'" }) -join ', '
        [void]$clauses.Add("type__v CONTAINS ($list)")
        if ($ExcludeTypes.Count) { Write-Log 'IncludeTypes is set, so ExcludeTypes is ignored.' 'WARN' }
    }
    else {
        foreach ($t in $ExcludeTypes) {
            if (-not $t) { continue }
            [void]$clauses.Add("type__v != '$(ConvertTo-VqlLiteral $t)'")
        }
    }
    if ($Where) { [void]$clauses.Add("($Where)") }

    $q = "SELECT $($fields -join ', ') FROM documents"
    if ($clauses.Count) { $q += " WHERE $($clauses -join ' AND ')" }
    return $q
}

function Import-IdFile {
    # One id per line. Tolerant on purpose - this file usually arrives pasted out of
    # Excel or the Library grid, so it may carry a header, quotes, a BOM, CRLFs, a
    # trailing comma, or blank lines.
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "IdFile not found: $Path" }

    $ids     = New-Object System.Collections.ArrayList
    $seen    = @{}
    $skipped = New-Object System.Collections.ArrayList
    $dupes   = 0
    $lineNo  = 0

    foreach ($raw in (Get-Content -LiteralPath $Path)) {
        $lineNo++
        $t = "$raw".Trim().Trim([char]0xFEFF).Trim('"', "'").TrimEnd(',').Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        if ($lineNo -eq 1 -and $t -match '^(id|document.?id)$') { continue }   # header
        if ($t -notmatch '^\d+$') { [void]$skipped.Add("line ${lineNo}: '$t'"); continue }
        if ($seen.ContainsKey($t)) { $dupes++; continue }
        $seen[$t] = $true
        [void]$ids.Add($t)
    }

    if ($skipped.Count) {
        Write-Log "$($skipped.Count) line(s) in $Path are not document ids and were skipped" 'WARN'
        foreach ($sk in ($skipped | Select-Object -First 5)) { Write-Log "  $sk" 'WARN' }
        if ($skipped.Count -gt 5) { Write-Log "  ... and $($skipped.Count - 5) more" 'WARN' }
    }
    if ($dupes) { Write-Log "$dupes duplicate id(s) dropped" }
    if ($ids.Count -eq 0) { throw "No document ids found in $Path" }

    Write-Log "$($ids.Count) document id(s) read from $Path" 'OK'
    return @($ids | ForEach-Object { [pscustomobject]@{ id = $_ } })
}

function Invoke-VaultQuery {
    # Page with next_page rather than PAGEOFFSET: Vault warns on manual pagination and
    # errors outright past 10,000 records, and next_page carries a query token that is
    # cheaper on their side.
    param([Parameter(Mandatory)][string]$Query)
    $rows  = New-Object System.Collections.ArrayList
    $total = $null
    $next  = ''
    $page  = 0

    while ($true) {
        $r =
            if ($next) { Invoke-VaultApi -Method GET -Path $next }
            else {
                Invoke-VaultApi -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
                    -Body @{ q = $Query; pagesize = $PageSize }
            }
        foreach ($d in @(Get-Field $r 'data' @())) { [void]$rows.Add($d) }

        $details = Get-Field $r 'responseDetails' $null
        if ($null -eq $total) { $total = Get-Field $details 'total' $rows.Count }
        $page++
        Write-Log "Query page $page - $($rows.Count) of $total document(s) retrieved"

        if ($MaxDocuments -gt 0 -and $rows.Count -ge $MaxDocuments) { break }
        $next = "$(Get-Field $details 'next_page' '')"
        if (-not $next) { break }
    }

    if ($MaxDocuments -gt 0 -and $rows.Count -gt $MaxDocuments) {
        $rows = New-Object System.Collections.ArrayList (, @($rows | Select-Object -First $MaxDocuments))
    }
    return [pscustomobject]@{ Rows = $rows; Total = $total }
}

function Format-Bytes {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}

function Write-SizeReport {
    param([Parameter(Mandatory)][array]$Sizes, [int]$Expected, [string]$Label, [int]$ThisRun)
    if ($Sizes.Count -eq 0) {
        Write-Log 'No size__v values came back - cannot project the export size.' 'WARN'
        return
    }
    $total = ($Sizes | Measure-Object -Sum).Sum
    $max   = ($Sizes | Measure-Object -Maximum).Maximum
    $avg   = $total / $Sizes.Count

    Write-Log '----------------------------------------------------------------'
    Write-Log "SIZE   projection for $Label"
    Write-Log ("       documents  {0:N0}" -f $Sizes.Count)
    Write-Log ("       TOTAL      {0}" -f (Format-Bytes $total))
    Write-Log ("       average    {0}" -f (Format-Bytes $avg))
    Write-Log ("       largest    {0}" -f (Format-Bytes $max))
    if ($Expected -gt 0 -and $Sizes.Count -lt $Expected) {
        Write-Log ("       {0:N0} document(s) had no size and are NOT counted - the real total is higher" -f ($Expected - $Sizes.Count)) 'WARN'
    }
    if ($ThisRun -gt 0 -and $ThisRun -lt $Sizes.Count) {
        $share = $total * $ThisRun / $Sizes.Count
        Write-Log ("       this run covers only {0:N0} of them, roughly {1}" -f $ThisRun, (Format-Bytes $share)) 'WARN'
    }
    Write-Log '----------------------------------------------------------------'
}

function Measure-QuerySize {
    # Project the WHOLE extract, not just the slice this run would touch. MaxDocuments
    # caps the action, never the projection - a 10-document cap sizing 10 documents is
    # not a projection, it is a sample presented as a total.
    #
    # Pages a minimal id + size__v query so the cost is a couple of fields per row
    # rather than the full SelectFields.
    param([Parameter(Mandatory)][string]$Query, [int]$ThisRun)

    Write-Log 'Sizing the full matched set (this ignores MaxDocuments)'
    $sizes = New-Object System.Collections.ArrayList
    $rows  = 0
    $next  = ''
    while ($true) {
        try {
            $r =
                if ($next) { Invoke-VaultApi -Method GET -Path $next }
                else {
                    Invoke-VaultApi -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
                        -Body @{ q = $Query; pagesize = $PageSize }
                }
        }
        catch {
            Write-Log "Could not size the full set: $_" 'WARN'
            return
        }
        foreach ($row in @(Get-Field $r 'data' @())) {
            $rows++
            $v = "$(Get-Field $row 'size__v' '')"
            if ($v -ne '') { [void]$sizes.Add([double]$v) }
        }
        $next = "$(Get-Field (Get-Field $r 'responseDetails' $null) 'next_page' '')"
        if (-not $next) { break }
    }
    Write-SizeReport -Sizes @($sizes) -Expected $rows -Label 'the FULL matched set' -ThisRun $ThisRun
}

function Measure-DocumentSize {
    # How much data an export would actually move. Worth knowing before asking Vault to
    # stage several thousand files: it decides whether this is a coffee break or an
    # overnight run, and whether File Staging has room.
    #
    # size__v is on the document, so when the run came from a query the value is already
    # in hand. An IdFile run has nothing but ids, so the sizes are fetched in chunks -
    # CONTAINS is VQL's OR-of-values. If the vault will not filter id that way, this
    # gives up and says so rather than firing one request per document.
    param([Parameter(Mandatory)][array]$Docs, [string]$Label = 'the documents in this run', [int]$ThisRun = 0)

    $known = @($Docs | Where-Object { "$(Get-Field $_ 'size__v' '')" -ne '' })
    $sizes = New-Object System.Collections.ArrayList
    foreach ($d in $known) { [void]$sizes.Add([double](Get-Field $d 'size__v' 0)) }

    $unknown = @($Docs | Where-Object { "$(Get-Field $_ 'size__v' '')" -eq '' } |
                 ForEach-Object { "$(Get-Field $_ 'id' '')" } | Where-Object { $_ })

    if ($unknown.Count) {
        Write-Log "Fetching sizes for $($unknown.Count) document(s)"
        $chunk = 200
        for ($i = 0; $i -lt $unknown.Count; $i += $chunk) {
            $ids  = @($unknown[$i..([math]::Min($i + $chunk, $unknown.Count) - 1)])
            $list = ($ids | ForEach-Object { "'$_'" }) -join ', '
            try {
                $r = Invoke-VaultApi -Method POST -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
                        -Body @{ q = "SELECT id, size__v FROM documents WHERE id CONTAINS ($list)"; pagesize = $chunk }
                foreach ($row in @(Get-Field $r 'data' @())) {
                    $v = "$(Get-Field $row 'size__v' '')"
                    if ($v -ne '') { [void]$sizes.Add([double]$v) }
                }
            }
            catch {
                Write-Log "Could not size documents by id: $_" 'WARN'
                Write-Log 'Skipping the size estimate - the export itself is unaffected.' 'WARN'
                return
            }
        }
    }

    Write-SizeReport -Sizes @($sizes) -Expected $Docs.Count -Label $Label -ThisRun $ThisRun
}

function Export-DocumentReference {
    # REPORT mode also dumps the two metadata endpoints, because the single most common
    # cause of a failed bulk update is writing a field that is not editable, or spelling
    # a document type the way the UI shows it when the vault wants the field name.
    Write-Log 'Retrieving document fields and types for reference'
    try {
        $props = Invoke-VaultApi -Method GET -Path '/metadata/objects/documents/properties'
        @(Get-Field $props 'properties' @()) |
            Select-Object @{n='Name';e={Get-Field $_ 'name'}},
                          @{n='Label';e={Get-Field $_ 'label'}},
                          @{n='Type';e={Get-Field $_ 'type'}},
                          @{n='Editable';e={Get-Field $_ 'editable' $false}},
                          @{n='Required';e={Get-Field $_ 'required' $false}},
                          @{n='Repeating';e={Get-Field $_ 'repeating' $false}} |
            Export-Csv -LiteralPath $FieldsCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
        Write-Log "Document fields  : $FieldsCsv"
    }
    catch { Write-Log "Could not retrieve document fields: $_" 'WARN' }

    try {
        $types = Invoke-VaultApi -Method GET -Path '/metadata/objects/documents/types'
        # value is a metadata URL; its last segment is the type NAME, which is what
        # TONAME(type__v) wants when a label is ambiguous or localised.
        @(Get-Field $types 'types' @()) |
            Select-Object @{n='Label';e={Get-Field $_ 'label'}},
                          @{n='Name';e={ ("$(Get-Field $_ 'value' '')" -split '/')[-1] }},
                          @{n='Value';e={Get-Field $_ 'value'}} |
            Export-Csv -LiteralPath $TypesCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
        Write-Log "Document types   : $TypesCsv"
    }
    catch { Write-Log "Could not retrieve document types: $_" 'WARN' }
}

# --------------------------------------------------------------------------------------
# Preflight for UPDATE
#
# Checked against the vault's own field metadata before the first batch, because all
# three of these failures are silent or expensive after the fact:
#
#   unknown field   - Vault reports a per-row error 1,000 rows at a time
#   not editable    - same, and it is the single most common cause of a failed run
#   repeating field - the dangerous one. A repeating (multi-value) field holds a SET.
#                     Writing one value to it does not necessarily append; it can
#                     replace everything already there. On thousands of documents that
#                     is unrecoverable without a restore, so it is refused by default.
# --------------------------------------------------------------------------------------

function Test-UpdateField {
    $props = $null
    try { $props = Invoke-VaultApi -Method GET -Path '/metadata/objects/documents/properties' }
    catch {
        Write-Log "Could not read document field metadata to pre-check SetFields: $_" 'WARN'
        Write-Log 'Continuing unchecked - a bad field name will surface as per-row errors.' 'WARN'
        return
    }

    $byName = @{}
    foreach ($f in @(Get-Field $props 'properties' @())) {
        $n = "$(Get-Field $f 'name' '')"
        if ($n) { $byName[$n] = $f }
    }

    $missing   = New-Object System.Collections.ArrayList
    $readonly  = New-Object System.Collections.ArrayList
    $repeating = New-Object System.Collections.ArrayList

    foreach ($n in $Updates.Keys) {
        if (-not $byName.ContainsKey($n)) { [void]$missing.Add($n); continue }
        $f = $byName[$n]
        if (-not [bool](Get-Field $f 'editable' $false)) { [void]$readonly.Add($n) }
        if ([bool](Get-Field $f 'repeating' $false))     { [void]$repeating.Add($n) }
        Write-Log ("SetFields: {0} type={1} editable={2} repeating={3}" -f `
            $n, "$(Get-Field $f 'type' '')", [bool](Get-Field $f 'editable' $false), [bool](Get-Field $f 'repeating' $false))
    }

    if ($missing.Count)  { throw "SetFields names field(s) this vault does not have: $($missing -join ', '). Check document-fields.csv." }
    if ($readonly.Count) { throw "SetFields names field(s) that are not editable: $($readonly -join ', '). Check document-fields.csv." }

    if ($repeating.Count) {
        Write-Log '----------------------------------------------------------------' 'WARN'
        Write-Log "REPEATING FIELD: $($repeating -join ', ')" 'WARN'
        Write-Log 'A repeating field holds a set of values. Writing a single value to it may' 'WARN'
        Write-Log 'REPLACE every value already on the document rather than adding to it, and' 'WARN'
        Write-Log "this run would do that to $($pending.Count) document(s)." 'WARN'
        Write-Log '' 'WARN'
        Write-Log 'Before overriding: pick ONE document, note its current values, update just' 'WARN'
        Write-Log 'that one with -MaxDocuments 1, and look at what Vault actually did. If it' 'WARN'
        Write-Log 'replaced rather than appended, the full value set has to go in SetFields.' 'WARN'
        Write-Log '----------------------------------------------------------------' 'WARN'
        if (-not $AllowRepeatingFields) {
            throw "Refusing to write repeating field(s): $($repeating -join ', '). Confirm the behaviour on one document, then re-run with -AllowRepeatingFields (or AllowRepeatingFields = true in the ini)."
        }
        Write-Log 'AllowRepeatingFields is set - proceeding.' 'WARN'
    }
}

# --------------------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------------------

function Update-DocumentBatch {
    # Update Multiple Documents. The CSV goes up as UTF-8 bytes because Vault requires
    # UTF-8 and a PowerShell string body is not guaranteed to be encoded that way.
    param([Parameter(Mandatory)][string[]]$Ids)

    $cols  = @('id') + @($Updates.Keys)
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add(($cols -join ','))
    foreach ($id in $Ids) {
        $vals = @(ConvertTo-CsvValue $id) + @($Updates.Keys | ForEach-Object { ConvertTo-CsvValue $Updates[$_] })
        [void]$lines.Add(($vals -join ','))
    }
    $csv = ($lines -join "`r`n")

    $resp = Invoke-VaultApi -Method PUT -Path '/objects/documents/batch' `
                -ContentType 'text/csv' -Body ([Text.Encoding]::UTF8.GetBytes($csv))

    # Per-row outcomes, keyed by id. Vault returns them in request order, but keying by
    # the id it echoes back is safer than trusting position.
    $byId = @{}
    foreach ($row in @(Get-Field $resp 'data' @())) {
        $rid = "$(Get-Field $row 'id' '')"
        $st  = "$(Get-Field $row 'responseStatus' '')"
        $msg = ''
        if ($st -ne 'SUCCESS') {
            $errs = @(Get-Field $row 'errors' @())
            $msg  = ($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; '
            if (-not $msg) { $msg = ($row | ConvertTo-Json -Depth 5 -Compress) }
        }
        if ($rid) { $byId[$rid] = [pscustomobject]@{ Status = $st; Message = $msg } }
    }
    return $byId
}

function Export-DocumentBatch {
    # Export Documents: asynchronous, so this posts the batch, polls the job, and reads
    # the results manifest. The files land on File Staging; the manifest gives the path
    # of each one so a later step can download them.
    param([Parameter(Mandatory)][string[]]$Ids)

    # Built by hand rather than with ConvertTo-Json: on Windows PowerShell 5.1 a
    # single-element array serialises as a bare object, and Vault wants an array.
    $payload = '[' + (($Ids | ForEach-Object { '{"id":"' + $_ + '"}' }) -join ',') + ']'
    $qs = 'source={0}&renditions={1}&allversions={2}&text={3}' -f `
            $ExportSource.ToString().ToLowerInvariant(), $ExportRenditions.ToString().ToLowerInvariant(),
            $ExportAllVersions.ToString().ToLowerInvariant(), $ExportText.ToString().ToLowerInvariant()

    $resp  = Invoke-VaultApi -Method POST -Path "/objects/documents/batch/actions/fileextract?$qs" `
                 -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($payload))
    $jobId = "$(Get-Field $resp 'job_id' '')"
    if (-not $jobId) { throw "Export did not return a job id: $($resp | ConvertTo-Json -Depth 5 -Compress)" }
    Write-Log "Export job $jobId started for $($Ids.Count) document(s); polling"

    $status = Wait-VaultJob -JobId $jobId
    Write-Log "Export job $jobId ended $status" $(if ($status -eq 'SUCCESS') { 'OK' } else { 'ERROR' })

    $byId = @{}
    try {
        $res = Invoke-VaultApi -Method GET -Path "/objects/documents/batch/actions/fileextract/$jobId/results"
        foreach ($row in @(Get-Field $res 'data' @())) {
            $rid = "$(Get-Field $row 'id' '')"
            if (-not $rid) { continue }
            # One row per exported FILE, not per document - a document comes back more
            # than once with allversions or renditions on. Keep every path rather than
            # letting the last row silently win.
            $file = "$(Get-Field $row 'file' '')"
            $ver  = "$(Get-Field $row 'major_version_number__v' '')" + '_' + "$(Get-Field $row 'minor_version_number__v' '')"
            if ($ver -ne '_') { $file = "v$ver $file" }
            if ($byId.ContainsKey($rid)) {
                $byId[$rid].Message = ($byId[$rid].Message + ' | ' + $file).Trim(' ', '|')
                if ("$(Get-Field $row 'responseStatus' '')" -ne 'SUCCESS') { $byId[$rid].Status = "$(Get-Field $row 'responseStatus' $status)" }
            }
            else {
                $byId[$rid] = [pscustomobject]@{
                    Status  = "$(Get-Field $row 'responseStatus' $status)"
                    Message = $file
                    JobId   = $jobId
                }
            }
        }
    }
    catch {
        Write-Log "Could not read export results for job ${jobId}: $_" 'WARN'
    }
    return [pscustomobject]@{ JobId = $jobId; JobStatus = $status; ById = $byId }
}

# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------

if (-not $script:SessionId) { Connect-Vault }
elseif ($script:SessionFile) { Write-Log 'Using the cached session from session.txt' }
else { Write-Log 'Using the session id from configuration' }

Write-Log "Invoke-VaultDocumentAction.ps1 $ScriptVersion"
Write-Log "MODE $ConfigMode"

$allDocs = @()   # the whole set, kept for sizing - MaxDocuments must not shrink a projection

if ($IdFile) {
    Write-Log "Document list: $IdFile (no query)"
    # Say out loud which filters are being ignored. Leaving them populated in the ini is
    # harmless but reads as though they still apply, which is worse than a warning.
    $ignored = New-Object System.Collections.ArrayList
    if ($Product)             { [void]$ignored.Add('Product') }
    if ($IncludeTypes.Count)  { [void]$ignored.Add('IncludeTypes') }
    if ($ExcludeTypes.Count)  { [void]$ignored.Add('ExcludeTypes') }
    if ($Where)               { [void]$ignored.Add('Where') }
    if ($Vql)                 { [void]$ignored.Add('Vql') }
    if ($ignored.Count) {
        Write-Log "IdFile is set, so these are IGNORED: $($ignored -join ', ')" 'WARN'
        Write-Log 'Nothing is filtered - every id in the file is acted on.' 'WARN'
    }
    $allDocs = @(Import-IdFile -Path $IdFile)
    $docs    = $allDocs
    if ($MaxDocuments -gt 0 -and $docs.Count -gt $MaxDocuments) {
        Write-Log "MaxDocuments $MaxDocuments - this run touches the first $MaxDocuments of $($allDocs.Count)" 'WARN'
        $docs = @($docs | Select-Object -First $MaxDocuments)
    }
    $TotalDiscovered = $docs.Count
}
else {
    $Query = if ($Vql) { $Vql } else { New-DocumentVql }
    Write-Log "VQL: $Query"

    if ($Action -eq 'REPORT') { Export-DocumentReference }

    $found = Invoke-VaultQuery -Query $Query
    $docs  = @($found.Rows)
    $TotalDiscovered = $docs.Count
    Write-Log "$TotalDiscovered document(s) matched (vault reports $($found.Total) total)" 'OK'
    if ($MaxDocuments -gt 0 -and $found.Total -gt $MaxDocuments) {
        Write-Log "MaxDocuments $MaxDocuments - this run covers only the first $TotalDiscovered of $($found.Total)" 'WARN'
    }
    if ($TotalDiscovered -eq 0) {
        Write-Log 'Nothing matched the query - check the filters.' 'WARN'
        exit 0
    }
}

$docs | Export-Csv -LiteralPath $DocumentsCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
Write-Log "Documents CSV    : $DocumentsCsv"

if ($SamplePercent -gt 0 -and $SamplePercent -lt 100) {
    $take = [math]::Ceiling($TotalDiscovered * $SamplePercent / 100.0)
    $docs = @($docs | Get-Random -Count $take)
    Write-Log "SAMPLE $SamplePercent% - $($docs.Count) of $TotalDiscovered document(s) selected at random" 'WARN'
}

if ($Action -eq 'REPORT' -or $WhatIfPreference) {
    if ($IdFile) {
        # Size every id in the file, not just the slice MaxDocuments allows through.
        Measure-DocumentSize -Docs $allDocs -Label 'the FULL id list' -ThisRun $docs.Count
    }
    elseif ($Vql) {
        Write-Log 'Vql is set, so the size projection covers only what this run fetched.' 'WARN'
        Measure-DocumentSize -Docs $docs -Label 'the documents this run fetched'
    }
    else {
        # Re-run the filters as a minimal id + size__v query, paged all the way, so the
        # projection is the real total rather than the first MaxDocuments of it.
        $sizeFields   = $SelectFields
        $SelectFields = @('id', 'size__v')
        $sizeQuery    = New-DocumentVql
        $SelectFields = $sizeFields
        Measure-QuerySize -Query $sizeQuery -ThisRun $docs.Count
    }
}

if ($Action -eq 'REPORT') {
    Write-Log '----------------------------------------------------------------'
    Write-Log "REPORT only - nothing was changed. Review $DocumentsCsv, then set MODE = EXPORT." 'OK'
    Write-Log "Log              : $TranscriptLog"
    exit 0
}

# Rows an earlier run recorded, so a re-run skips what already landed and keeps its record.
$done  = @{}
$prior = [ordered]@{}
if (Test-Path -LiteralPath $ResultsCsv) {
    foreach ($row in (Import-Csv -LiteralPath $ResultsCsv)) {
        $rid = "$(Get-Field $row 'Id' '')"
        if (-not $rid) { continue }
        $prior[$rid] = $row
        if ((Get-Field $row 'Status') -eq 'SUCCESS') { $done[$rid] = $true }
    }
    if ($done.Count) { Write-Log "$($done.Count) document(s) already SUCCESS in $ResultsCsv - skipping them" }
}

$results = New-Object System.Collections.ArrayList

function Save-Results {
    # Rewrite the results CSV after every batch, so an interrupted run still leaves a
    # usable file. Rows an earlier run recorded for documents this run did not touch are
    # carried through instead of being dropped - otherwise a sampled run (or any re-run,
    # which skips the ones already SUCCESS) would truncate the file to just what it
    # processed, losing the record of everything already done.
    $current = @{}
    foreach ($r in $results) { $current["$($r.Id)"] = $r }

    $out     = New-Object System.Collections.ArrayList
    $written = @{}
    foreach ($k in $prior.Keys) {
        $key = "$k"
        if ($current.ContainsKey($key)) { [void]$out.Add($current[$key]) } else { [void]$out.Add($prior[$key]) }
        $written[$key] = $true
    }
    foreach ($r in $results) {
        if (-not $written.ContainsKey("$($r.Id)")) { [void]$out.Add($r) }
    }
    $out | Export-Csv -LiteralPath $ResultsCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
}

$pending = @($docs | Where-Object { -not $done.ContainsKey("$(Get-Field $_ 'id' '')") })
Write-Log "$($pending.Count) document(s) to process in batches of $BatchSize"

if ($Action -eq 'UPDATE' -and $pending.Count -gt 0) { Test-UpdateField }

$applied = if ($Action -eq 'UPDATE') { ($Updates.Keys | ForEach-Object { "$_=$($Updates[$_])" }) -join '; ' } else { '' }
$batchNo = 0
$total   = [math]::Ceiling($pending.Count / [double]$BatchSize)

for ($offset = 0; $offset -lt $pending.Count; $offset += $BatchSize) {
    $batchNo++
    $batch  = @($pending[$offset..([math]::Min($offset + $BatchSize, $pending.Count) - 1)])
    $ids    = @($batch | ForEach-Object { "$(Get-Field $_ 'id' '')" } | Where-Object { $_ })
    $prefix = "[batch $batchNo/$total] $($ids.Count) document(s)"
    $startedUtc = (Get-Date).ToUniversalTime().ToString('s')

    $outcome = @{}
    $jobId   = ''
    $failure = ''

    try {
        if ($PSCmdlet.ShouldProcess("$($ids.Count) document(s)", $Action)) {
            if ($Action -eq 'UPDATE') {
                Write-Log "$prefix - updating $applied"
                $outcome = Update-DocumentBatch -Ids $ids
            }
            else {
                Write-Log "$prefix - exporting to File Staging"
                $exp     = Export-DocumentBatch -Ids $ids
                $jobId   = $exp.JobId
                $outcome = $exp.ById
                if ($exp.JobStatus -ne 'SUCCESS') { $failure = "export job ended $($exp.JobStatus)" }
            }
        }
        else {
            Write-Log "$prefix - WhatIf: would $Action $($ids -join ', ')"
        }
    }
    catch {
        $failure = "$_"
        Write-Log "$prefix - ERROR: $_" 'ERROR'
    }

    foreach ($d in $batch) {
        $id = "$(Get-Field $d 'id' '')"
        $status  = 'WHATIF'
        $message = ''
        if ($failure) { $status = 'ERROR'; $message = $failure }
        elseif ($outcome.ContainsKey($id)) { $status = $outcome[$id].Status; $message = $outcome[$id].Message }
        elseif ($outcome.Count -gt 0) { $status = 'ERROR'; $message = 'no result returned for this document' }

        [void]$results.Add([pscustomobject][ordered]@{
            Id          = $id
            Name        = "$(Get-Field $d 'name__v' '')"
            Type        = "$(Get-Field $d 'type__v' '')"
            Action      = $Action
            Applied     = $applied
            JobId       = $jobId
            Status      = $status
            Message     = $message
            StartedUtc  = $startedUtc
            FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
        })
    }

    Save-Results
    $ok = @($results | Where-Object { $_.Status -eq 'SUCCESS' }).Count
    Write-Log "$prefix - done ($ok SUCCESS so far)" $(if ($failure) { 'WARN' } else { 'OK' })
}

# --------------------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------------------

$ok   = @($results | Where-Object { $_.Status -eq 'SUCCESS' }).Count
$bad  = @($results | Where-Object { $_.Status -notin @('SUCCESS','WHATIF') }).Count
$what = @($results | Where-Object { $_.Status -eq 'WHATIF' }).Count

Write-Log '----------------------------------------------------------------'
Write-Log "Processed $($results.Count) document(s): $ok succeeded, $bad failed, $what dry-run" $(if ($bad) { 'WARN' } else { 'OK' })
if ($SamplePercent -gt 0 -and $SamplePercent -lt 100) {
    Write-Log "SAMPLE $SamplePercent% - this covered $($docs.Count) of $TotalDiscovered document(s), NOT the whole view" 'WARN'
}
Write-Log "Documents CSV    : $DocumentsCsv"
Write-Log "Results CSV      : $ResultsCsv"
Write-Log "Log              : $TranscriptLog"

if ($bad -gt 0) { exit 1 }
