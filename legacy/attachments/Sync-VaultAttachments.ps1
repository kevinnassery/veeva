<#
.SYNOPSIS
    Reconcile document attachments between two Vaults: find what the target is missing
    and deliver only that.

.DESCRIPTION
    Given a map of source document id to target document id, for each pair:

      1. List the attachments on the SOURCE document.
      2. List the attachments on the TARGET document.
      3. Work out which source attachments are missing on the target.
      4. Download each missing one, upload it to the target's File Staging, and attach
         it to the target document.

    Comparing before copying is what makes this safe to run repeatedly. A document whose
    attachments are already present costs two listing calls and nothing else, and a run
    interrupted anywhere can simply be run again.

    Attachments are matched by filename, which is also how Vault itself decides: posting
    an attachment whose name already exists creates a new VERSION of it rather than a
    second attachment. Matching on anything looser would silently produce version churn.
    The listing also carries an MD5, so a name that matches with a different checksum is
    reported as DIFFERS and left alone unless you ask for it.

    Three modes:
      REPORT - diff only. Downloads nothing, uploads nothing, changes nothing.
      SYNC   - diff, then download and attach everything missing.
    Both modes are idempotent: the diff is recomputed live from both vaults on every
    run, so nothing is delivered twice and an interrupted run is simply run again.

.NOTES
    Windows PowerShell 5.1 compatible.
    SOURCE:
      GET  /objects/documents/{id}/attachments                   what exists
      GET  /objects/documents/{id}/attachments/{aid}/file         the bytes
    TARGET:
      GET  /objects/documents/{id}/attachments                   what is already there
      POST /objects/documents/{id}/attachments                   upload and attach, 2GB
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string] $ConfigFile = '',

    # One login is used for BOTH vaults unless SeparateCredentials is set - the same
    # account exists on each side, so prompting twice for the same thing is just a way
    # to get one of them wrong.
    [pscredential] $Credential,
    [switch] $SeparateCredentials,

    # ---- Source ----
    [string] $SourceVaultDNS  = '',
    [string] $SourceSessionId = '',
    [pscredential] $SourceCredential,

    # ---- Target ----
    # The vault DNS, not the sandbox's display name. It is the host in the browser's
    # address bar when you are logged into that vault, e.g. sb-something.veevavault.com
    [string] $TargetVaultDNS  = '',
    [string] $TargetSessionId = '',
    [pscredential] $TargetCredential,


    [ValidatePattern('^v\d+\.\d+$')]
    [string] $ApiVersion = 'v26.2',

    # ---- What to do ----
    # REPORT = compare both sides and report the gap. Changes nothing, downloads
    #          nothing. Always start here.
    # SYNC   = deliver every missing attachment: download, stage, attach.
    # Accepted and ignored, so the validator's setting in the shared ini is quiet.
    [string] $ValidateMode = '',

    [ValidateSet('REPORT', 'SYNC')]
    [string] $Mode       = 'REPORT',

    # CSV mapping source document id to target document id, with a header row. Column
    # names are detected from the usual spellings; set them explicitly if yours differ.
    [string] $IdMap            = 'attachments-map.csv',
    [string] $MapSourceColumn  = '',
    [string] $MapTargetColumn  = '',

    # An attachment whose name matches on both sides but whose MD5 differs is reported
    # as DIFFERS and left alone. Set this to send it anyway, which Vault records as a
    # new VERSION of the existing attachment rather than a second attachment.
    [switch] $ReplaceDiffering,


    # Stop once TestCount attachments have actually been reconciled, however many
    # documents that took. MaxDocuments is the wrong tool for a first look here: most
    # documents carry no attachments at all, so a cap of five documents can easily
    # reconcile nothing and tell you nothing.
    #
    # Reconciled means ATTACHED in SYNC - staged AND attached, confirmed end to end.
    # In REPORT it means five missing attachments found, since that is what SYNC would
    # have delivered.
    [switch] $Test,
    [ValidateRange(1, 10000)]
    [int]    $TestCount        = 5,

    # ---- What to move ----
    [string] $IdFile     = '',
    [string] $OutputRoot = '',

    # Where the in-flight file lands. Defaults to a work folder under OutputRoot.
    [string] $WorkDir    = '',

    [int]    $MaxDocuments = 0,

    # How many documents to move at once. 1 keeps the original single-threaded path.
    # Above 1, this process becomes a supervisor: it shards the outstanding ids, runs
    # that many copies of itself, and merges their results at the end.
    #
    # Per-document time is dominated by round trips, not bytes, so this scales close to
    # linearly until Vault's burst limit starts throttling. 4 is a safe starting point.
    [ValidateRange(1, 16)]
    [int]    $Workers = 1,

    # Set by the supervisor on the workers it launches. A PSCredential exported with
    # Export-CliXml, which on Windows is DPAPI-encrypted for the current user only - so
    # a worker can authenticate, and re-authenticate when its session expires, without a
    # password ever appearing on a command line or in the environment.
    [string] $CredentialFile = '',

    # ---- Disk safety ----
    # Refuse to start a download unless this much free space would remain afterwards.
    # The run stops cleanly instead of filling the volume out from under everything.
    [int]    $ReserveMB  = 2048,

    # ---- Upload tuning ----
    # Vault requires parts of at least 5MB (except the last) and at most 52MB.
    [ValidateRange(5, 52)]
    [int]    $PartSizeMB = 25,

    [ValidateSet('Prompt', 'Resume', 'Restart')]
    [string] $ExistingResults = 'Prompt',

    [int]    $MaxRetries = 4
)

$ScriptVersion = '2026.08.29-25'

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --------------------------------------------------------------------------------------
# Run lock
#
# refresh.bat replaces the scripts in this folder. Doing that mid-run is not harmless:
# the supervisor launches each worker from the script file on disk, so a refresh part way
# through a parallel run would have new workers running different code from the process
# that started them.
#
# The lock is written next to the script, which is the folder refresh.bat manages, and
# removed on exit. A kill -9 leaves it behind; refresh.bat says which pid it belonged to
# so a stale one can be told apart from a live run.
# --------------------------------------------------------------------------------------

$lockHere = $PSScriptRoot
if (-not $lockHere) { $lockHere = (Get-Location).ProviderPath }
$script:LockFile = Join-Path $lockHere ('.run-' + [IO.Path]::GetFileNameWithoutExtension($PSCommandPath) + '.lock')
try {
    Set-Content -LiteralPath $script:LockFile -Encoding ASCII -WhatIf:$false -Value @(
        "pid=$PID",
        "script=$([IO.Path]::GetFileName($PSCommandPath))",
        "started=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    )
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action {
        try { Remove-Item -LiteralPath $script:LockFile -Force -ErrorAction SilentlyContinue } catch { }
    }
}
catch { Write-Warning "Could not write the run lock: $_" }

function Get-Field {
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

function Format-Bytes {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}

function ConvertTo-StagingUrlPath {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)
    $clean = $Path.Replace('\', '/').Trim('/')
    if (-not $clean) { return '' }
    return (($clean -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}

# --------------------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------------------

$IntKeys    = @('MaxDocuments', 'ReserveMB', 'PartSizeMB', 'MaxRetries', 'Workers', 'TestCount')
$SwitchKeys = @('SeparateCredentials', 'ReplaceDiffering', 'Test')

if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
    $here = $PSScriptRoot
    if (-not $here) { $here = (Get-Location).ProviderPath }
    $ConfigFile = Join-Path $here 'attachments.ini'
}
$cfg = $null
if (Test-Path -LiteralPath $ConfigFile) {
    $cfg = [ordered]@{}
    foreach ($line in (Get-Content -LiteralPath $ConfigFile)) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';') -or $t.StartsWith('[')) { continue }
        $eq = $t.IndexOf('='); if ($eq -lt 1) { continue }
        $k = $t.Substring(0, $eq).Trim(); $v = $t.Substring($eq + 1).Trim()
        if ($v -notmatch '^["'']') { $v = ($v -split '\s+[#;]', 2)[0].TrimEnd() }
        $cfg[$k] = [Environment]::ExpandEnvironmentVariables($v.Trim('"', "'"))
    }
    foreach ($key in $cfg.Keys) {
        $value = $cfg[$key]
        if ($PSBoundParameters.ContainsKey($key)) { continue }
        if (-not (Get-Variable -Name $key -Scope Script -ErrorAction SilentlyContinue)) {
            Write-Warning "attachments.ini: ignoring unknown setting '$key'"
            continue
        }
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        if     ($IntKeys    -contains $key) { Set-Variable -Name $key -Value ([int]$value) -WhatIf:$false }
        elseif ($SwitchKeys -contains $key) { Set-Variable -Name $key -Value ([bool]($value -match '^(1|true|yes|on)$')) -WhatIf:$false }
        else                         { Set-Variable -Name $key -Value $value -WhatIf:$false }
    }
}
else { Write-Warning "No attachments.ini found at $ConfigFile - relying on command-line arguments." }


$needTarget = @('SourceVaultDNS', 'TargetVaultDNS', 'OutputRoot')
foreach ($n in $needTarget) {
    if ([string]::IsNullOrWhiteSpace((Get-Variable -Name $n -ValueOnly))) {
        throw "$n is not set. Add it to $ConfigFile, or pass -$n on the command line."
    }
}
$SourceVaultDNS = $SourceVaultDNS -replace '^https?://', '' -replace '/+$', ''
$TargetVaultDNS = $TargetVaultDNS -replace '^https?://', '' -replace '/+$', ''
if ($SourceVaultDNS -eq $TargetVaultDNS) {
    Write-Warning 'Source and target are the same vault. That is legal but rarely intended.'
}

$OutputRoot = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $OutputRoot))
if ($OutputRoot.Length -gt 3) { $OutputRoot = $OutputRoot.TrimEnd('\') }
if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force -WhatIf:$false | Out-Null }

if ([string]::IsNullOrWhiteSpace($WorkDir)) { $WorkDir = Join-Path $OutputRoot 'attachment-work' }
if (-not (Test-Path -LiteralPath $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force -WhatIf:$false | Out-Null }

$stamp         = Get-Date -Format 'yyyyMMdd-HHmmss'
$ResultsCsv    = Join-Path $OutputRoot 'attachment-results.csv'
$TranscriptLog = Join-Path $OutputRoot "attachments-$stamp.log"

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
# Two sessions, kept apart on purpose
#
# Source and target are different vaults with different credentials. Every request names
# which side it is for, so a target token can never be sent to the source vault.
# --------------------------------------------------------------------------------------

$script:Session = @{ Source = $SourceSessionId; Target = $TargetSessionId }
if ($CredentialFile) {
    if (-not (Test-Path -LiteralPath $CredentialFile)) { throw "CredentialFile not found: $CredentialFile" }
    $imported = Import-Clixml -LiteralPath $CredentialFile
    if (-not $SourceCredential) { $SourceCredential = $imported }
    if (-not $TargetCredential) { $TargetCredential = $imported }
}

$script:Cred    = @{ Source = $SourceCredential; Target = $TargetCredential }
if (-not $SeparateCredentials) {
    if (-not $script:Cred['Source']) { $script:Cred['Source'] = $Credential }
    if (-not $script:Cred['Target']) { $script:Cred['Target'] = $Credential }
}
$script:Dns     = @{ Source = $SourceVaultDNS;  Target = $TargetVaultDNS }

function Connect-Vault {
    param([Parameter(Mandatory)][ValidateSet('Source','Target')][string]$Side)
    $dns = $script:Dns[$Side]
    if (-not $script:Cred[$Side]) {
        $msg = if ($SeparateCredentials) { "$Side vault credentials for $dns" }
               else { "Vault credentials (used for BOTH vaults) - prompted for $dns" }
        $c = Get-Credential -Message $msg
        $script:Cred[$Side] = $c
        # Same account on both sides, so answer the other prompt now too.
        if (-not $SeparateCredentials) {
            foreach ($other in @('Source', 'Target')) { if (-not $script:Cred[$other]) { $script:Cred[$other] = $c } }
        }
    }
    $c = $script:Cred[$Side]
    $r = Invoke-RestMethod -Method Post -Uri "https://$dns/api/$ApiVersion/auth" `
            -Body @{ username = $c.UserName; password = $c.GetNetworkCredential().Password } `
            -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' }
    if ((Get-Field $r 'responseStatus') -ne 'SUCCESS') { throw "$Side authentication failed: $($r | ConvertTo-Json -Depth 5 -Compress)" }

    # Read every field defensively. StrictMode turns a missing property into a
    # terminating error, so reaching straight for $r.vaultId let a LOG LINE kill the run
    # after the login had already succeeded - and crashing there hid the response that
    # would have explained it.
    $sid = "$(Get-Field $r 'sessionId' '')"
    if (-not $sid) {
        throw "$Side authentication returned no sessionId. Vault said: $($r | ConvertTo-Json -Depth 5 -Compress)"
    }
    $script:Session[$Side] = $sid
    $vid = "$(Get-Field $r 'vaultId' '?')"
    $uid = "$(Get-Field $r 'userId'  '?')"
    Write-Log "$Side vault $dns - authenticated (vaultId $vid, userId $uid)" 'OK'
}

function Invoke-VaultApi {
    param(
        [Parameter(Mandatory)][ValidateSet('Source','Target')][string]$Side,
        [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body,
        [string]$ContentType,
        [hashtable]$ExtraHeaders = @{},
        [int]$TimeoutSec = 900
    )
    $dns = $script:Dns[$Side]
    $uri = if ($Path -match '^https?://') { $Path } elseif ($Path -match '^/api/') { "https://$dns$Path" } else { "https://$dns/api/$ApiVersion$Path" }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $headers = @{ Authorization = $script:Session[$Side]; Accept = 'application/json' }
        foreach ($k in $ExtraHeaders.Keys) { $headers[$k] = $ExtraHeaders[$k] }
        try {
            $req = @{ Method = $Method; Uri = $uri; Headers = $headers; TimeoutSec = $TimeoutSec; UseBasicParsing = $true }
            if ($null -ne $Body) { $req['Body'] = $Body }
            if ($ContentType)    { $req['ContentType'] = $ContentType }
            $resp = Invoke-WebRequest @req

            $remaining = $resp.Headers['X-VaultAPI-BurstLimitRemaining']
            if ($remaining -and [int]$remaining -lt 200) {
                Write-Log "$Side burst limit low ($remaining) - pausing 30s" 'WARN'
                Start-Sleep -Seconds 30
            }
            $json = $null
            if ($resp.Content) { try { $json = $resp.Content | ConvertFrom-Json } catch { } }
            if ($null -eq $json) { return [pscustomobject]@{ responseStatus = 'SUCCESS'; raw = $resp.Content } }
            if ((Get-Field $json 'responseStatus') -eq 'FAILURE') {
                $errs  = @(Get-Field $json 'errors' @())
                if (@($errs | ForEach-Object { Get-Field $_ 'type' }) -contains 'INVALID_SESSION_ID') {
                    Write-Log "$Side session expired - re-authenticating" 'WARN'
                    Connect-Vault -Side $Side
                    continue
                }
                throw "$Side API FAILURE on $Method $Path -- " + (($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; ')
            }
            return $json
        }
        catch {
            $ex = $_.Exception
            if ($ex.GetType().Name -notin @('WebException','HttpResponseException','HttpRequestException')) { throw }
            $status = $null
            try { if ($ex.Response) { $status = [int]$ex.Response.StatusCode } } catch { }
            if ($status -eq 429) {
                Write-Log "$Side HTTP 429 - waiting 60s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = [math]::Pow(2, $attempt) * 5
                Write-Log "$Side transient error on $Method $Path (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            $detail = ''
            try { $detail = "$($_.ErrorDetails.Message)" } catch { }
            throw "$Side $Method $Path failed (HTTP $status): $($ex.Message) $detail"
        }
    }
    throw "$Side $Method $Path failed after $MaxRetries attempts"
}

# --------------------------------------------------------------------------------------
# Download: streamed to disk
#
# Invoke-WebRequest -OutFile buffers the whole response on Windows PowerShell 5.1, which
# a 2GB document would not survive. HttpWebRequest with a stream copy keeps memory flat
# no matter how large the file is.
# --------------------------------------------------------------------------------------

function Save-DocumentFile {
    param([Parameter(Mandatory)][string]$DocId, [Parameter(Mandatory)][string]$Destination)

    $uri = "https://$($script:Dns['Source'])/api/$ApiVersion/objects/documents/$DocId/file"
    $req = [Net.HttpWebRequest]::Create($uri)
    $req.Method  = 'GET'
    $req.Timeout = 900000
    $req.ReadWriteTimeout = 900000
    $req.Headers.Add('Authorization', $script:Session['Source'])

    $resp = $req.GetResponse()
    try {
        # Vault names the file in Content-Disposition. Fall back to the id if it is absent.
        $name = ''
        $cd = $resp.Headers['Content-Disposition']
        if ($cd -and $cd -match 'filename\*?=(?:UTF-8'''')?"?([^";]+)"?') {
            $name = [Uri]::UnescapeDataString($Matches[1]).Trim('"')
        }
        if (-not $name) { $name = "document-$DocId" }
        foreach ($bad in [IO.Path]::GetInvalidFileNameChars()) { $name = $name.Replace($bad, '_') }

        $path = Join-Path $Destination $name
        $in   = $resp.GetResponseStream()
        $out  = [IO.File]::Create($path)
        try {
            $buf = New-Object byte[] 1048576
            while (($read = $in.Read($buf, 0, $buf.Length)) -gt 0) { $out.Write($buf, 0, $read) }
        }
        finally { $out.Dispose(); $in.Dispose() }
        return [pscustomobject]@{ Path = $path; Name = $name; Size = (Get-Item -LiteralPath $path).Length }
    }
    finally { $resp.Dispose() }
}

# --------------------------------------------------------------------------------------
# Upload: always a resumable session
#
# One code path for every size. A single-part upload is legal because the 5MB minimum
# does not apply to the last part, and a single part is the last part. Parts are read
# from disk a chunk at a time, so a 2GB file never lands in memory.
# --------------------------------------------------------------------------------------




function Send-DocumentAttachment {
    # Upload straight onto the target document. No File Staging involved at all.
    #
    # POST /objects/documents/{id}/attachments takes the file as multipart/form-data, up
    # to 2GB, and attaches it in the same call. That replaces a five-step dance - open a
    # resumable session, create each folder level, upload parts, commit, then a separate
    # bulk attach - with one request, and leaves nothing behind on staging afterwards.
    #
    # Written over HttpWebRequest with buffering off so the body streams from disk: a
    # 2GB attachment must never be assembled in memory. PowerShell 5.1 has no -Form, so
    # the multipart envelope is built by hand.
    param(
        [Parameter(Mandatory)][string]$TargetDocId,
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$FileName
    )

    $fileLen = (Get-Item -LiteralPath $LocalPath).Length

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $boundary = '----VaultSync' + [guid]::NewGuid().ToString('N')
        $pre  = "--$boundary`r`n" +
                "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`"`r`n" +
                "Content-Type: application/octet-stream`r`n`r`n"
        $post = "`r`n--$boundary--`r`n"
        $preB  = [Text.Encoding]::UTF8.GetBytes($pre)
        $postB = [Text.Encoding]::UTF8.GetBytes($post)

        $uri = "https://$($script:Dns['Target'])/api/$ApiVersion/objects/documents/$TargetDocId/attachments"
        $req = [Net.HttpWebRequest]::Create($uri)
        $req.Method                   = 'POST'
        $req.ContentType              = "multipart/form-data; boundary=$boundary"
        $req.ContentLength            = $preB.Length + $fileLen + $postB.Length
        $req.AllowWriteStreamBuffering = $false
        $req.Timeout                  = 900000
        $req.ReadWriteTimeout         = 900000
        $req.Accept                   = 'application/json'
        $req.Headers.Add('Authorization', $script:Session['Target'])

        try {
            $rs = $req.GetRequestStream()
            try {
                $rs.Write($preB, 0, $preB.Length)
                $fs = [IO.File]::OpenRead($LocalPath)
                try {
                    $buf = New-Object byte[] 1048576
                    while (($read = $fs.Read($buf, 0, $buf.Length)) -gt 0) { $rs.Write($buf, 0, $read) }
                }
                finally { $fs.Dispose() }
                $rs.Write($postB, 0, $postB.Length)
            }
            finally { $rs.Dispose() }

            $resp = $req.GetResponse()
            try {
                $sr   = New-Object IO.StreamReader($resp.GetResponseStream())
                $body = $sr.ReadToEnd(); $sr.Dispose()
                $json = $null
                try { $json = $body | ConvertFrom-Json } catch { }
                if ($null -eq $json) { throw "attachment upload returned no JSON: $body" }
                if ((Get-Field $json 'responseStatus') -ne 'SUCCESS') {
                    $errs = @(Get-Field $json 'errors' @())
                    throw (($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; ')
                }
                $d = Get-Field $json 'data' $null
                return [pscustomobject]@{
                    AttachmentId = "$(Get-Field $d 'id' '')"
                    Version      = "$(Get-Field $d 'version__v' (Get-Field $d 'version' ''))"
                }
            }
            finally { $resp.Dispose() }
        }
        catch [Net.WebException] {
            $status = $null
            try { if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode } } catch { }
            $detail = ''
            try {
                $er = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $er.ReadToEnd(); $er.Dispose()
            } catch { }

            if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                Write-Log "Target HTTP 429 attaching $FileName - waiting 60s" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = [math]::Pow(2, $attempt) * 5
                Write-Log "Transient error attaching $FileName (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            throw "attach failed (HTTP $status): $($_.Exception.Message) $detail"
        }
    }
    throw "attach of $FileName failed after $MaxRetries attempts"
}


# --------------------------------------------------------------------------------------
# Disk
# --------------------------------------------------------------------------------------

function Read-WorkerLog {
    # Forward a worker's new WARN/ERROR lines into the parent log.
    #
    # Workers run hidden and write their own logs, so without this a worker failing
    # every document looks - from the parent - like progress that simply stopped. The
    # error text would be sitting in a file nobody is watching.
    #
    # Opened with FileShare.ReadWrite because the worker still has it open for writing.
    # The read offset is kept per worker so each line is forwarded once.
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][hashtable]$Offsets,
        [int]$MaxLines = 20
    )
    $log = @(Get-ChildItem -LiteralPath $Dir -Filter 'attachments-*.log' -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime | Select-Object -Last 1)
    if (-not $log.Count) { return }
    $path = $log[0].FullName

    try {
        $fs = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    }
    catch { return }
    try {
        $start = 0
        if ($Offsets.ContainsKey($Label)) { $start = [long]$Offsets[$Label] }
        if ($start -gt $fs.Length) { $start = 0 }   # rotated or truncated
        [void]$fs.Seek($start, [IO.SeekOrigin]::Begin)
        $sr   = New-Object IO.StreamReader($fs)
        $text = $sr.ReadToEnd()
        $Offsets[$Label] = $start + [Text.Encoding]::UTF8.GetByteCount($text)
        $sr.Dispose()
    }
    finally { $fs.Dispose() }

    $bad = @($text -split "`r?`n" | Where-Object { $_ -match '\[(WARN|ERROR)\]' })
    if (-not $bad.Count) { return }
    foreach ($line in ($bad | Select-Object -First $MaxLines)) {
        $level = if ($line -match '\[ERROR\]') { 'ERROR' } else { 'WARN' }
        Write-Log ("{0} | {1}" -f $Label, ($line -replace '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[(WARN|ERROR)\] ', '')) $level
    }
    if ($bad.Count -gt $MaxLines) {
        Write-Log ("{0} | ... {1} more line(s) this interval, full detail in {2}" -f $Label, ($bad.Count - $MaxLines), $path) 'WARN'
    }
}

function Get-DocumentAttachment {
    # Every attachment on the latest version of a document, from either vault. The
    # listing carries name, size and MD5, so the comparison and the size projection both
    # come free - no file has to be fetched to find out what is there.
    param(
        [Parameter(Mandatory)][ValidateSet('Source','Target')][string]$Side,
        [Parameter(Mandatory)][string]$DocId
    )
    $r = Invoke-VaultApi -Side $Side -Method GET -Path "/objects/documents/$DocId/attachments"
    $out = New-Object System.Collections.ArrayList
    foreach ($a in @(Get-Field $r 'data' @())) {
        $aid = "$(Get-Field $a 'id' '')"
        if (-not $aid) { continue }
        [void]$out.Add([pscustomobject]@{
            Id       = $aid
            Name     = "$(Get-Field $a 'filename__v' "attachment-$aid")"
            Size     = [long]"$(Get-Field $a 'size__v' 0)"
            Version  = "$(Get-Field $a 'version__v' '')"
            Format   = "$(Get-Field $a 'format__v' '')"
            Checksum = "$(Get-Field $a 'md5checksum__v' '')"
        })
    }
    return $out
}

function Test-TargetStaging {
    # What probe.bat was for, asked at the moment it matters instead of as a separate
    # errand: who this account is on the TARGET vault. Attachments go straight onto
    # documents now, so there is no staging path left to get wrong.
    $me = $null
    try { $me = Invoke-VaultApi -Side Target -Method GET -Path '/objects/users/me' } catch {
        Write-Log "Could not read the target user: $_" 'WARN'
        return
    }
    $u       = Get-Field (@(Get-Field $me 'users' @()) | Select-Object -First 1) 'user' $null
    $uid     = "$(Get-Field $u 'id' '')"
    $profile = "$(Get-Field $u 'security_profile__v' '')"
    $isAdmin = ($profile -match 'vault_owner|system_admin')
    Write-Log "Target user $(Get-Field $u 'user_name__v' '') id=$uid profile=$profile"

}

function Import-IdMap {
    # source document id -> target document id, from a CSV with a header row.
    #
    # Column names are guessed from the usual spellings rather than dictated, because
    # this file comes from whatever produced the load and its headers are not ours to
    # choose. An unguessable header is an error naming what was found, not a silent
    # mis-read of the first two columns.
    param([Parameter(Mandatory)][string]$Path, [string]$LegacyName = 'map.csv')

    # Relative names resolve against the WORKING directory - where the .bat was run
    # from - which is where the map is expected to be dropped. Falling back to the
    # script's own folder covers a double-click from elsewhere. Either way the absolute
    # path is logged, so there is never a question of which file was read.
    $resolved = $Path
    if (-not (Test-Path -LiteralPath $resolved)) {
        $resolved = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path))
    }

    # Fall back to the previous name rather than failing. These were renamed so each
    # input says which workflow it feeds; a machine mid-job still has the old file.
    if (-not (Test-Path -LiteralPath $resolved) -and $LegacyName) {
        foreach ($try in @(
            [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $LegacyName)),
            $(if ($PSScriptRoot) { Join-Path $PSScriptRoot $LegacyName } else { $null })
        )) {
            if ($try -and (Test-Path -LiteralPath $try)) {
                Write-Log "Using $LegacyName - rename it to $(Split-Path -Leaf $Path) when convenient" 'WARN'
                $resolved = $try
                break
            }
        }
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
        $mapHere = $PSScriptRoot
        if (-not $mapHere) { $mapHere = (Get-Location).ProviderPath }
        $beside = Join-Path $mapHere $Path
        if (Test-Path -LiteralPath $beside) { $resolved = $beside }
    }
    if (-not (Test-Path -LiteralPath $resolved)) {
        $tried = @(
            [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path))
        )
        if ($PSScriptRoot) { $tried += (Join-Path $PSScriptRoot $Path) }
        throw ("IdMap not found. Looked in:`n" + (($tried | ForEach-Object { "    $_" }) -join "`n"))
    }
    $Path = (Resolve-Path -LiteralPath $resolved).ProviderPath
    $script:IdMapPath = $Path

    # The file is named .txt, so the delimiter is not implied by the extension. Sniff
    # the header for whichever separator actually appears most - a tab-separated export
    # read as comma-separated yields one column and a confusing "could not work out
    # which columns" error rather than an obvious one.
    # Excel's "CSV UTF-8" writes a byte order mark, which Windows PowerShell 5.1 reads
    # as literal characters glued to the first column name - so a header of source_id
    # arrives as something no name match would ever find. Detect it and read as UTF-8.
    $bom = $false
    try {
        $head3 = New-Object byte[] 3
        $fsb = [IO.File]::OpenRead($Path)
        try { [void]$fsb.Read($head3, 0, 3) } finally { $fsb.Dispose() }
        if ($head3[0] -eq 0xEF -and $head3[1] -eq 0xBB -and $head3[2] -eq 0xBF) { $bom = $true }
    }
    catch { }

    $header = @(Get-Content -LiteralPath $Path -TotalCount 1)
    if (-not $header.Count) { throw "IdMap $Path is empty" }
    $header[0] = $header[0].TrimStart([char]0xFEFF).Replace([char]0xEF + [string][char]0xBB + [string][char]0xBF, '')
    $delims = @{ ',' = ([regex]::Matches($header[0], ',')).Count
                 "`t" = ([regex]::Matches($header[0], "`t")).Count
                 ';' = ([regex]::Matches($header[0], ';')).Count
                 '|' = ([regex]::Matches($header[0], '\|')).Count }
    $delim = ','
    $best  = 0
    foreach ($d in $delims.Keys) { if ($delims[$d] -gt $best) { $best = $delims[$d]; $delim = $d } }
    if ($best -eq 0) { throw "IdMap $Path has no delimiter in its header row: '$($header[0])'. It needs a header and at least two columns." }
    $shown = if ($delim -eq "`t") { 'tab' } else { $delim }

    # Import-Csv refuses a sheet with two columns of the same name - "The member
    # 'Created By' is already present" - and a real export very often has some. Only two
    # columns matter here, so a duplicate elsewhere should not stop the job: the header
    # is parsed, repeats are suffixed _2, _3, and the rows are converted against that.
    $all = if ($bom) { @(Get-Content -LiteralPath $Path -Encoding UTF8) }
           else      { @(Get-Content -LiteralPath $Path) }
    if ($all.Count -lt 2) { throw "IdMap $Path has a header but no rows" }

    $names    = New-Object System.Collections.ArrayList
    $usedName = @{}
    $renamed  = 0
    foreach ($raw in ($header[0] -split [regex]::Escape($delim))) {
        $n = $raw.Trim().Trim('"')
        if (-not $n) { $n = 'Column' }
        $base = $n
        $k = 2
        while ($usedName.ContainsKey($n.ToLowerInvariant())) { $n = "${base}_$k"; $k++; $renamed++ }
        $usedName[$n.ToLowerInvariant()] = $true
        [void]$names.Add($n)
    }
    if ($renamed) { Write-Log "$renamed duplicate column name(s) in the header were suffixed to keep them apart" }

    $rows = @($all | Select-Object -Skip 1 | ConvertFrom-Csv -Header $names -Delimiter $delim)
    if ($rows.Count -eq 0) { throw "IdMap $Path has a header but no rows" }
    $headers = @($rows[0].PSObject.Properties.Name)
    if ($headers.Count) { Write-Log "IdMap columns: $($headers -join ', ')" }

    # Match on what a header MEANS rather than on a list of exact spellings. Real
    # headers are written for people - "Source (old) Document ID" and "Destination
    # (new) Document ID" are perfectly clear and match no fixed name at all. A column
    # is a candidate if it mentions an id and a side.
    function Test-HeaderIs {
        param([string]$Header, [string[]]$Words)
        $n = ($Header -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
        if ($n -notmatch 'id$|id[^a-z]|^id') { return $false }
        foreach ($w in $Words) { if ($n -like "*$w*") { return $true } }
        return $false
    }

    $srcCol = $MapSourceColumn
    $tgtCol = $MapTargetColumn

    if (-not $srcCol) {
        $cand = @($headers | Where-Object { Test-HeaderIs -Header $_ -Words @('source','old','from','legacy') })
        if ($cand.Count -eq 1) { $srcCol = $cand[0] }
        elseif ($cand.Count -gt 1) { throw "More than one column could be the source id in $Path : $($cand -join ', '). Set MapSourceColumn." }
    }
    if (-not $tgtCol) {
        $cand = @($headers | Where-Object { Test-HeaderIs -Header $_ -Words @('destination','target','new','to') })
        if ($cand.Count -eq 1) { $tgtCol = $cand[0] }
        elseif ($cand.Count -gt 1) { throw "More than one column could be the target id in $Path : $($cand -join ', '). Set MapTargetColumn." }
    }
    if (-not $srcCol -or -not $tgtCol) {
        throw "Could not work out which columns hold the ids in $Path. Headers found: $($headers -join ', '). Set MapSourceColumn and MapTargetColumn."
    }

    $map = @{}
    $bad = 0
    $sci = 0
    $dupes = 0
    $conflict = New-Object System.Collections.ArrayList
    $badRows  = New-Object System.Collections.ArrayList
    $rowNo    = 1
    foreach ($row in $rows) {
        $rowNo++
        $a = "$(Get-Field $row $srcCol '')".Trim()
        $b = "$(Get-Field $row $tgtCol '')".Trim()
        if ($a -match '^\d+(\.\d+)?[eE][+-]?\d+$' -or $b -match '^\d+(\.\d+)?[eE][+-]?\d+$') {
            $sci++
            $bad++
            continue
        }
        if ($a -notmatch '^\d+$' -or $b -notmatch '^\d+$') {
            # A skipped row is a document that never gets reconciled, so say WHICH one.
            # A bare count leaves no way to find them in a 1000-row sheet.
            $bad++
            [void]$badRows.Add(("line {0}: source='{1}' target='{2}'" -f $rowNo, $a, $b))
            continue
        }
        if ($map.ContainsKey($a)) {
            # The sheet has a row per FILE, so one document appears on many rows.
            # Repeats are expected; a repeat pointing somewhere ELSE is not.
            if ($map[$a] -ne $b) { [void]$conflict.Add("$a -> $($map[$a]) and $b") } else { $dupes++ }
            continue
        }
        $map[$a] = $b
    }
    if ($conflict.Count) {
        $show = ($conflict | Select-Object -First 5) -join '; '
        throw "The map sends the same source document to two different targets: $show$(if ($conflict.Count -gt 5) { " (and $($conflict.Count - 5) more)" }). Fix the map - guessing which is right is not something this can do."
    }
    if ($sci) {
        # Refuse rather than carry on with the rows that survived. A mangled id is a
        # document that silently never gets reconciled, and the run would still report
        # success - the worst possible combination.
        throw @"
$sci row(s) in $Path hold ids in scientific notation, e.g. 5.5283E+04.

Excel does that to long numbers on export, and the original digits are gone - they
cannot be recovered from the file. Continuing would quietly skip those documents while
the run still reported success.

Re-export with both id columns formatted as Text before running again.
"@
    }
    if ($bad) {
        Write-Log "$bad row(s) in $Path had no usable id pair and were skipped - those documents are NOT reconciled" 'WARN'
        foreach ($br in ($badRows | Select-Object -First 10)) { Write-Log "  $br" 'WARN' }
        if ($badRows.Count -gt 10) { Write-Log "  ... and $($badRows.Count - 10) more" 'WARN' }

        # #N/A and friends are a failed lookup in the spreadsheet, not a bad id. Saying
        # so turns "10 rows skipped" into something actionable.
        $excelErr = @($badRows | Where-Object { $_ -match '#(N/A|REF!|VALUE!|NAME\?|DIV/0!|NUM!|NULL!)' })
        if ($excelErr.Count) {
            Write-Log "  $($excelErr.Count) of those hold an Excel error such as #N/A - the lookup in the sheet found no match," 'WARN'
            Write-Log '  so those documents have no target id. Either they were never migrated, or the formula missed them.' 'WARN'
        }
        $distinct = @($badRows | ForEach-Object { ($_ -split "source='")[1] -split "'" | Select-Object -First 1 } |
                      Where-Object { $_ } | Select-Object -Unique)
        if ($distinct.Count -and $distinct.Count -ne $badRows.Count) {
            Write-Log "  $($distinct.Count) distinct source document(s) affected: $($distinct -join ', ')" 'WARN'
        }
    }
    if ($map.Count -eq 0) { throw "No usable id pairs in $Path (columns '$srcCol' -> '$tgtCol')" }
    if ($dupes) { Write-Log "$dupes repeated row(s) for documents already mapped - expected when the sheet has a row per file" }
    Write-Log "$($map.Count) id pair(s) from $Path ($shown-separated, column '$srcCol' -> '$tgtCol')" 'OK'
    return $map
}


function Save-AttachmentFile {
    # Streamed to disk, for the same reason the document download is: a 2GB attachment
    # would not survive Invoke-WebRequest buffering the whole response on 5.1.
    param(
        [Parameter(Mandatory)][string]$DocId,
        [Parameter(Mandatory)][string]$AttachmentId,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string]$Destination
    )
    $uri = "https://$($script:Dns['Source'])/api/$ApiVersion/objects/documents/$DocId/attachments/$AttachmentId/file"
    $req = [Net.HttpWebRequest]::Create($uri)
    $req.Method = 'GET'
    $req.Timeout = 900000
    $req.ReadWriteTimeout = 900000
    $req.Headers.Add('Authorization', $script:Session['Source'])

    $name = $FileName
    foreach ($bad in [IO.Path]::GetInvalidFileNameChars()) { $name = $name.Replace($bad, '_') }
    if (-not $name) { $name = "attachment-$AttachmentId" }
    $path = Join-Path $Destination $name

    $resp = $req.GetResponse()
    try {
        $in  = $resp.GetResponseStream()
        $out = [IO.File]::Create($path)
        try {
            $buf = New-Object byte[] 1048576
            while (($read = $in.Read($buf, 0, $buf.Length)) -gt 0) { $out.Write($buf, 0, $read) }
        }
        finally { $out.Dispose(); $in.Dispose() }
    }
    finally { $resp.Dispose() }
    return [pscustomobject]@{ Path = $path; Name = $name; Size = (Get-Item -LiteralPath $path).Length }
}

function Get-FreeSpace {
    param([Parameter(Mandatory)][string]$Path)
    $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    try { return (New-Object IO.DriveInfo $root).AvailableFreeSpace }
    catch { return -1 }
}

# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------

Write-Log "Sync-VaultAttachments.ps1 $ScriptVersion"
Write-Log "Source: $SourceVaultDNS"
Write-Log "Target: $TargetVaultDNS"
Write-Log "Work  : $WorkDir"

# IdFile is optional and normally blank - map.csv defines the scope. Every path test
# below sits inside this guard: Test-Path THROWS on an empty string rather than
# returning false, so an unguarded check turns the normal case into a crash.
$haveIdFile = $false
if ([string]::IsNullOrWhiteSpace($IdFile)) {
    Write-Log 'No IdFile set - every document in the map is checked'
}
else {
    if (-not (Test-Path -LiteralPath $IdFile)) {
        $here2 = $PSScriptRoot
        if (-not $here2) { $here2 = (Get-Location).ProviderPath }
        $beside = Join-Path $here2 $IdFile
        if (Test-Path -LiteralPath $beside) { $IdFile = $beside }
    }
    $haveIdFile = Test-Path -LiteralPath $IdFile
    if (-not $haveIdFile) { Write-Log "No $IdFile found - every document in the map is checked" 'WARN' }
}

$ids  = New-Object System.Collections.ArrayList
$seen = @{}
$n = 0
foreach ($raw in $(if ($haveIdFile) { Get-Content -LiteralPath $IdFile } else { @() })) {
    $n++
    $t = "$raw".Trim().Trim([char]0xFEFF).Trim('"', "'").TrimEnd(',').Trim()
    if (-not $t -or $t.StartsWith('#')) { continue }
    if ($n -eq 1 -and $t -match '^(id|document.?id)$') { continue }
    if ($t -notmatch '^\d+$') { Write-Log "line ${n}: '$t' is not a document id - skipped" 'WARN'; continue }
    if ($seen.ContainsKey($t)) { continue }
    $seen[$t] = $true
    [void]$ids.Add($t)
}
if ($ids.Count -eq 0 -and $haveIdFile) { throw "No document ids found in $IdFile" }
if ($haveIdFile) { Write-Log "$($ids.Count) document id(s) from $IdFile" 'OK' }

# The map is what makes this possible at all: without a target id there is nothing to
# compare against and nowhere to deliver. It defines the set of work; IdFile, if there
# is one, only narrows it.
# Deliberately not called idMap: PowerShell variable names are case-insensitive, so
# that would BE the [string] $IdMap parameter - and a typed variable coerces on every
# assignment, so the hashtable was silently turned into the string
# "System.Collections.Hashtable" with no error raised at all.
$docMap = Import-IdMap -Path $IdMap
$resolvedIdMap = $script:IdMapPath

if (-not $haveIdFile) { $ids = @($docMap.Keys) }
$mapped   = @($ids | Where-Object { $docMap.ContainsKey($_) })
$unmapped = @($ids | Where-Object { -not $docMap.ContainsKey($_) })
if ($unmapped.Count) {
    Write-Log "$($unmapped.Count) id(s) in $IdFile have no target in the map and are skipped" 'WARN'
    foreach ($u in ($unmapped | Select-Object -First 5)) { Write-Log "  unmapped: $u" 'WARN' }
    if ($unmapped.Count -gt 5) { Write-Log "  ... and $($unmapped.Count - 5) more" 'WARN' }
}
$ids = $mapped
if ($ids.Count -eq 0) { throw "None of those ids appear in $IdMap - nothing to reconcile." }

# Prior results, so a re-run picks up where it stopped.
$done  = @{}
$prior = [ordered]@{}
if (Test-Path -LiteralPath $ResultsCsv) {
    $summary = "$(@(Import-Csv -LiteralPath $ResultsCsv).Count) row(s)"
    $choice  = $ExistingResults
    if ($choice -eq 'Prompt') {
        Write-Host ''
        Write-Host "transfer-results.csv already here: $summary" -ForegroundColor Yellow
        if ($Host.UI.RawUI -and -not [Console]::IsInputRedirected) {
            $a = Read-Host 'Resume (skip what already transferred) or Restart (rotate aside)? [R]esume/[S]tart fresh'
            $choice = if ($a -match '^[Ss]') { 'Restart' } else { 'Resume' }
        }
        else { $choice = 'Resume' }
    }
    if ($choice -eq 'Restart') {
        $when = (Get-Item -LiteralPath $ResultsCsv).LastWriteTime.ToString('yyyyMMdd-HHmmss')
        Move-Item -LiteralPath $ResultsCsv -Destination (Join-Path $OutputRoot "attachment-results-$when.csv") -Force -WhatIf:$false
        Write-Log 'Rotated the previous results aside.'
    }
    else {
        foreach ($row in (Import-Csv -LiteralPath $ResultsCsv)) {
            $rk = "$(Get-Field $row 'Key' '')"
            if (-not $rk) { continue }
            $prior[$rk] = $row
            # ATTACHED only - work THIS tool completed.
            #
            # PRESENT used to count too, which was wrong twice over. It is not something
            # we did, so calling it transferred was a lie; and an attachment later
            # deleted from the target would stay skipped for ever on the strength of one
            # old REPORT. The live state is recomputed from both vaults every run anyway
            # - by the time this check runs, both listings have already been fetched -
            # so skipping PRESENT saved nothing and could only go stale.
            #

            if ((Get-Field $row 'Status') -eq 'ATTACHED') { $done[$rk] = $true }
        }
        if ($done.Count) { Write-Log "$($done.Count) attachment(s) already delivered by an earlier run - not re-sent" }
    }
}

# Every document is still visited - its attachment list is what says whether there is
# anything left to do, and that is only knowable from the source vault. Attachments
# already moved are skipped individually, inside the loop.
$pending = @($ids)
if ($MaxDocuments -gt 0 -and $pending.Count -gt $MaxDocuments) {
    # Not "outstanding": every mapped document is visited every run. Whether anything is
    # left to do is decided per ATTACHMENT inside the loop, from the two vaults - the
    # document list never shrinks as work completes.
    Write-Log "MaxDocuments $MaxDocuments - this run examines the first $MaxDocuments of $($pending.Count) mapped document(s)" 'WARN'
    $pending = @($pending | Select-Object -First $MaxDocuments)
}
Write-Log "$($pending.Count) mapped document(s) to examine"

if (-not $script:Session['Source']) { Connect-Vault -Side Source } else { Write-Log 'Source: using the configured session id' }
if ($Test) {
    # Workers would each count their own five.
    if ($Workers -gt 1) { Write-Log 'TEST: running single-threaded so the count is the whole run' 'WARN'; $Workers = 1 }
    Write-Log "TEST: stopping after $TestCount attachment(s) are reconciled, however many documents that takes" 'WARN'
}

# REPORT still needs the target: the whole point is comparing against what is there.
if (-not $script:Session['Target']) { Connect-Vault -Side Target } else { Write-Log 'Target: using the configured session id' }

Test-TargetStaging

# --------------------------------------------------------------------------------------
# Parallel mode
#
# Above one worker this process stops moving documents itself and becomes a supervisor:
# it shards the outstanding ids, launches that many copies of THIS script - each in
# single-worker mode, i.e. the same code path proven in production - and merges their
# results at the end.
#
# Separate processes rather than runspaces on purpose. Each worker authenticates for
# itself, so it can re-authenticate when its session expires; a shared session handed
# out by the parent could not be refreshed from inside a worker. It also means the
# sequential path stays the single implementation, with nothing duplicated to drift.
# --------------------------------------------------------------------------------------

if ($Mode -eq 'SYNC' -and $Workers -gt 1 -and $pending.Count -gt 1) {

    if (-not $script:Cred['Source'] -or -not $script:Cred['Target']) {
        throw @'
Parallel mode needs a username and password, not a pasted session id: each worker
authenticates for itself so it can re-authenticate when its session expires.

Blank SourceSessionId and TargetSessionId in attachments.ini and run again.
'@
    }

    $workerCount = [math]::Min($Workers, $pending.Count)
    $parallelDir = Join-Path $OutputRoot 'attachment-workers'
    if (Test-Path -LiteralPath $parallelDir) { Remove-Item -LiteralPath $parallelDir -Recurse -Force -WhatIf:$false }
    New-Item -ItemType Directory -Path $parallelDir -Force -WhatIf:$false | Out-Null

    # DPAPI-encrypted for this user only. Deleted in the finally below, whatever happens.
    $credPath = Join-Path $parallelDir 'cred.xml'
    $script:Cred['Source'] | Export-Clixml -LiteralPath $credPath -WhatIf:$false

    try {
        # Round robin, so a run of large documents cannot all land on one worker.
        $shards = @{}
        for ($w = 1; $w -le $workerCount; $w++) { $shards[$w] = New-Object System.Collections.ArrayList }
        for ($n = 0; $n -lt $pending.Count; $n++) { [void]$shards[($n % $workerCount) + 1].Add($pending[$n]) }

        $logOffsets = @{}
        $procs = @()
        for ($w = 1; $w -le $workerCount; $w++) {
            $wDir   = Join-Path $parallelDir "w$w"
            New-Item -ItemType Directory -Path $wDir -Force -WhatIf:$false | Out-Null
            $shardFile = Join-Path $wDir 'ids.txt'
            Set-Content -LiteralPath $shardFile -Value ($shards[$w] -join "`r`n") -Encoding ASCII -WhatIf:$false

            $argList = @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
                '-ConfigFile',      "`"$ConfigFile`"",
                '-IdFile',          "`"$shardFile`"",
                '-OutputRoot',      "`"$wDir`"",
                '-WorkDir',         "`"$(Join-Path $wDir 'work')`"",
                '-CredentialFile',  "`"$credPath`"",
                '-IdMap',           "`"$resolvedIdMap`"",
                '-Workers', '1', '-MaxDocuments', '0', '-ExistingResults', 'Restart', '-Mode', $Mode
            )
            $procs += Start-Process -FilePath 'powershell.exe' -ArgumentList $argList `
                        -WindowStyle Hidden -PassThru
            Write-Log "worker $w started (pid $($procs[-1].Id)) with $($shards[$w].Count) document(s)"
        }

        Write-Log "$workerCount worker(s) moving $($pending.Count) document(s). Per-worker logs are under $parallelDir"
        $started = Get-Date

        # Progress from the workers' own results files - no shared state to contend on.
        while ($procs | Where-Object { -not $_.HasExited }) {
            Start-Sleep -Seconds 30
            $moved = 0
            for ($w = 1; $w -le $workerCount; $w++) {
                $wd = Join-Path $parallelDir "w$w"
                Read-WorkerLog -Dir $wd -Label "w$w" -Offsets $logOffsets
                $f = Join-Path $wd 'attachment-results.csv'
                if (Test-Path -LiteralPath $f) {
                    try { $moved += @(Import-Csv -LiteralPath $f | Where-Object { $_.Status -eq 'SUCCESS' }).Count } catch { }
                }
            }
            $elapsed = ((Get-Date) - $started).TotalSeconds
            $alive   = @($procs | Where-Object { -not $_.HasExited }).Count
            if ($moved -gt 0 -and $elapsed -gt 0) {
                $rate = $moved / $elapsed
                $left = $pending.Count - $moved
                $eta  = (Get-Date).AddSeconds($left / [math]::Max($rate, 0.0001))
                Write-Log ("progress {0:N0}/{1:N0} at {2:N2} doc/s, {3} worker(s) alive, ETA {4:yyyy-MM-dd HH:mm}" -f `
                            $moved, $pending.Count, $rate, $alive, $eta)
            }
            else { Write-Log "progress 0/$($pending.Count), $alive worker(s) alive" }
        }

        # Drain whatever each worker wrote between the last poll and exiting.
        for ($w = 1; $w -le $workerCount; $w++) {
            Read-WorkerLog -Dir (Join-Path $parallelDir "w$w") -Label "w$w" -Offsets $logOffsets -MaxLines 50
        }
        foreach ($proc in $procs) {
            if ($proc.ExitCode -ne 0) { Write-Log "worker pid $($proc.Id) exited $($proc.ExitCode) - some documents failed" 'WARN' }
        }

        # Merge every worker's rows back into the one results file the operator reads.
        $merged = New-Object System.Collections.ArrayList
        foreach ($k in $prior.Keys) { [void]$merged.Add($prior[$k]) }
        $seenIds = @{}
        foreach ($k in $prior.Keys) { $seenIds["$k"] = $true }
        $wOk = 0; $wBad = 0
        for ($w = 1; $w -le $workerCount; $w++) {
            $f = Join-Path (Join-Path $parallelDir "w$w") 'attachment-results.csv'
            if (-not (Test-Path -LiteralPath $f)) { Write-Log "worker $w produced no results file" 'WARN'; continue }
            foreach ($row in (Import-Csv -LiteralPath $f)) {
                if ((Get-Field $row 'Status') -eq 'SUCCESS') { $wOk++ } else { $wBad++ }
                if ($seenIds.ContainsKey("$(Get-Field $row 'Id' '')")) { continue }
                [void]$merged.Add($row)
            }
        }
        $merged | Export-Csv -LiteralPath $ResultsCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false

        $secs = ((Get-Date) - $started).TotalSeconds
        Write-Log '----------------------------------------------------------------'
        Write-Log ("Moved $wOk of $($pending.Count) document(s), $wBad failed, in {0:N1} hour(s) across $workerCount worker(s)" -f ($secs / 3600)) $(if ($wBad) { 'WARN' } else { 'OK' })
        Write-Log "Results     : $ResultsCsv"
        Write-Log "Worker logs : $parallelDir"
        Write-Log "Log         : $TranscriptLog"
        if ($wBad -gt 0) { exit 1 }
        exit 0
    }
    finally {
        # The credential file must not outlive the run, even on Ctrl-C.
        if (Test-Path -LiteralPath $credPath) { Remove-Item -LiteralPath $credPath -Force -WhatIf:$false }
    }
}

$results = New-Object System.Collections.ArrayList
function Save-Results {
    $current = @{}
    foreach ($r in $results) { $current["$($r.Key)"] = $r }
    $out = New-Object System.Collections.ArrayList
    $written = @{}
    foreach ($k in $prior.Keys) {
        if ($current.ContainsKey("$k")) { [void]$out.Add($current["$k"]) } else { [void]$out.Add($prior[$k]) }
        $written["$k"] = $true
    }
    foreach ($r in $results) { if (-not $written.ContainsKey("$($r.Key)")) { [void]$out.Add($r) } }
    $out | Export-Csv -LiteralPath $ResultsCsv -NoTypeInformation -Encoding UTF8 -WhatIf:$false
}

$i = 0
$moved     = [long]0
$stat      = @{ Src = 0; Present = 0; Missing = 0; Differs = 0; Attached = 0; NoMap = 0; NoAtt = 0 }
$script:TestStopped = $false

:documents foreach ($srcId in $pending) {
    $i++
    $tgtId     = $docMap[$srcId]
    $docPrefix = "[$i/$($pending.Count)] $srcId -> $tgtId"

    try { $srcAtt = @(Get-DocumentAttachment -Side Source -DocId $srcId) }
    catch {
        Write-Log "$docPrefix - ERROR listing source attachments: $_" 'ERROR'
        continue
    }
    if ($srcAtt.Count -eq 0) { $stat.NoAtt++; continue }
    $stat.Src += $srcAtt.Count

    try { $tgtAtt = @(Get-DocumentAttachment -Side Target -DocId $tgtId) }
    catch {
        Write-Log "$docPrefix - ERROR listing target attachments: $_" 'ERROR'
        continue
    }

    # Filename is the key because it is the key Vault itself uses: posting a name that
    # already exists creates a new version of that attachment, not a second one.
    $tgtByName = @{}
    foreach ($t in $tgtAtt) { $tgtByName[$t.Name.ToLowerInvariant()] = $t }

    foreach ($att in $srcAtt) {
        $key  = "$srcId`:$($att.Id)"
        $name = $att.Name
        $have = $null
        if ($tgtByName.ContainsKey($name.ToLowerInvariant())) { $have = $tgtByName[$name.ToLowerInvariant()] }

        $state = 'MISSING'
        if ($have) {
            $state = 'PRESENT'
            if ($att.Checksum -and $have.Checksum -and $att.Checksum -ne $have.Checksum) { $state = 'DIFFERS' }
        }
        if ($state -eq 'PRESENT') { $stat.Present++ }
        elseif ($state -eq 'DIFFERS') { $stat.Differs++ }
        else { $stat.Missing++ }

        if ($done.ContainsKey($key)) { continue }

        $record = [pscustomobject][ordered]@{
            Key = $key; SourceDocId = $srcId; TargetDocId = $tgtId
            AttachmentId = $att.Id; Name = $name; SizeBytes = $att.Size
            Version = $att.Version; Checksum = $att.Checksum
            Parts = 0
            Status = $state; Message = ''
            StartedUtc = (Get-Date).ToUniversalTime().ToString('s'); FinishedUtc = ''
        }

        $wanted = ($state -eq 'MISSING') -or ($state -eq 'DIFFERS' -and $ReplaceDiffering)

        if ($Mode -eq 'REPORT' -or -not $wanted) {
            if ($state -eq 'DIFFERS' -and -not $ReplaceDiffering) {
                $record.Message = 'same name, different MD5 - left alone. ReplaceDiffering sends it as a new version.'
                Write-Log "$docPrefix - DIFFERS $name" 'WARN'
            }
            $record.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
            [void]$results.Add($record)
            Save-Results
            continue
        }

        $local = $null
        try {
            if ($PSCmdlet.ShouldProcess("attachment $name of document $srcId -> $tgtId", 'Deliver')) {
                $free = Get-FreeSpace -Path $WorkDir
                if ($free -ge 0 -and $att.Size -gt 0 -and ($free - $att.Size) -lt ($ReserveMB * 1MB)) {
                    throw "not enough disk: $(Format-Bytes $att.Size) needed, $(Format-Bytes $free) free, ${ReserveMB}MB reserve"
                }

                Write-Log "$docPrefix - $state $name ($(Format-Bytes $att.Size)) - downloading"
                $local = Save-AttachmentFile -DocId $srcId -AttachmentId $att.Id -FileName $name -Destination $WorkDir
                $record.SizeBytes = $local.Size

                # Straight onto the target document. One call, no staging, and no
                # intermediate state - which is why there is no ATTACH mode any more.
                Write-Log "$docPrefix - attaching to document $tgtId"
                # Vault's ORIGINAL name, not $local.Name. The local copy has to have
                # characters like : * ? scrubbed out to be a legal Windows filename,
                # but uploading under the scrubbed name means the target ends up with
                # "RE_ [EXTERNAL]..." where the source has "RE: [EXTERNAL]...". The
                # names then never match again, so every later run sees it as missing
                # and uploads another copy - duplicates without limit.
                $up = Send-DocumentAttachment -TargetDocId $tgtId -LocalPath $local.Path -FileName $name
                $record.Status  = 'ATTACHED'
                $record.Message = "attachment $($up.AttachmentId) v$($up.Version)"
                $moved += $local.Size
                $stat.Attached++
                # Confirm the attach with what Vault gave back. Without this the log
                # shows "attaching..." and then silence, so success is only visible as
                # the absence of an error, and the new attachment id never appears
                # anywhere but the CSV.
                Write-Log "$docPrefix - OK $name attached as $($up.AttachmentId) v$($up.Version) ($(Format-Bytes $local.Size))" 'OK'
            }
            else {
                $record.Status  = 'WHATIF'
                $record.Message = "would deliver $(Format-Bytes $att.Size)"
                Write-Log "$docPrefix - WhatIf: would deliver $name"
            }
        }
        catch {
            $record.Status  = 'ERROR'
            $record.Message = "$_"
            Write-Log "$docPrefix - ERROR on $name : $_" 'ERROR'
        }
        finally {
            if ($local -and (Test-Path -LiteralPath $local.Path)) {
                try {
                    Remove-Item -LiteralPath $local.Path -Force -WhatIf:$false
                    $freeNow = Get-FreeSpace -Path $WorkDir
                    $freeTxt = if ($freeNow -ge 0) { ", $(Format-Bytes $freeNow) free" } else { '' }
                    Write-Log "$docPrefix - scratch file deleted ($(Format-Bytes $local.Size)$freeTxt)"
                }
                catch { Write-Log "Could not delete $($local.Path): $_" 'WARN' }
            }
        }

        $record.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
        [void]$results.Add($record)
        Save-Results

        if ($Test) {
            $reconciled = if ($Mode -eq 'REPORT') { $stat.Missing } else { $stat.Attached }
            if ($reconciled -ge $TestCount) {
                $what = if ($Mode -eq 'REPORT') { 'missing attachment(s) found' } else { 'attachment(s) reconciled' }
                Write-Log "TEST: $reconciled $what after $i document(s) - stopping" 'OK'
                $script:TestStopped = $true
                break documents
            }
        }
    }
}

Write-Log '----------------------------------------------------------------'
Write-Log ("source attachments {0}   already present {1}   missing {2}   same name different MD5 {3}" -f `
            $stat.Src, $stat.Present, $stat.Missing, $stat.Differs)
Write-Log ("documents with no attachments {0}" -f $stat.NoAtt)
if ($script:TestStopped) {
    Write-Log "TEST run - stopped early after $i of $($pending.Count) document(s). These totals are NOT the whole set." 'WARN'
}
if ($Mode -ne 'REPORT') { Write-Log ("attached {0}" -f $stat.Attached) }

# Scratch should be empty. Anything still here is a file a crash or a kill left
# behind, and it will sit there consuming disk until someone notices.
$leftovers = @(Get-ChildItem -LiteralPath $WorkDir -File -ErrorAction SilentlyContinue)
if ($leftovers.Count) {
    $bytes = ($leftovers | Measure-Object -Property Length -Sum).Sum
    Write-Log "$($leftovers.Count) file(s) left in $WorkDir taking $(Format-Bytes $bytes) - safe to delete" 'WARN'
}

# These must match the statuses the loop actually writes: PRESENT, MISSING, DIFFERS,
# STAGED, ATTACHED, ERROR, WHATIF. They were still looking for SUCCESS and LISTED, left
# over from before this became a reconcile - so every compared attachment counted as a
# failure, and a REPORT that worked perfectly ended "361 failed" and exited 1.
$ok     = @($results | Where-Object { $_.Status -eq 'ATTACHED' }).Count
$bad    = @($results | Where-Object { $_.Status -eq 'ERROR' }).Count

Write-Log '----------------------------------------------------------------'
if ($Mode -eq 'REPORT') {
    $missing = @($results | Where-Object { $_.Status -eq 'MISSING' })
    $bytes   = 0
    if ($missing.Count) { $bytes = ($missing | Measure-Object -Property SizeBytes -Sum).Sum }
    Write-Log "REPORT only - nothing was moved." 'OK'
    Write-Log "$($missing.Count) attachment(s) to deliver, $(Format-Bytes $bytes)"
    if ($bad) { Write-Log "$bad error(s) - see the rows marked ERROR" 'WARN' }
    Write-Log 'Set Mode = SYNC and run with -Test when the numbers look right.'
}
else {
    Write-Log "Attached $ok attachment(s), $bad failed, $(Format-Bytes $moved) transferred" $(if ($bad) { 'WARN' } else { 'OK' })

}
Write-Log "Results : $ResultsCsv"
Write-Log "Log     : $TranscriptLog"

# Clear the lock explicitly as well as on the exit event - a run that ends badly may
# never reach the event, and a lock left behind blocks the next refresh.
if ($script:LockFile) { Remove-Item -LiteralPath $script:LockFile -Force -ErrorAction SilentlyContinue -WhatIf:$false }

if ($bad -gt 0) { exit 1 }
