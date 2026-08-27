<#
.SYNOPSIS
    Copy document ATTACHMENTS from one Vault to another, one file at a time.

.DESCRIPTION
    Same shape as Transfer-VaultDocuments.ps1, one level down: for every document id in
    the list it enumerates that document's attachments, then for each attachment
    downloads it from the SOURCE vault, uploads it to the TARGET vault's File Staging,
    and deletes the local copy.

    A document has zero or many attachments, so the unit of work here is the attachment,
    not the document. The results file has one row per attachment and resume is keyed on
    document id plus attachment id.

    MODE = REPORT lists what is there and projects the total size without moving
    anything. Start there - attachment volume is not knowable from the document count.

.NOTES
    Windows PowerShell 5.1 compatible.
    SOURCE, relative to https://<SourceVaultDNS>/api/<ApiVersion>:
      POST /auth
      GET  /objects/documents/{id}/attachments                  list, with size and name
      GET  /objects/documents/{id}/attachments/{aid}/file        the attachment itself
    TARGET:
      POST /auth
      POST /services/file_staging/upload                         resumable session
      PUT  /services/file_staging/upload/{id}                    one part
      POST /services/file_staging/upload/{id}                    commit

    Attaching the staged files to documents in the TARGET vault is a separate step and
    is NOT done here - see the note at the end of attachments.ini. It needs a source
    document id to target document id mapping, which nothing in this repo has yet.
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

    # Folder on the TARGET vault's File Staging to upload into. As a Vault Owner or
    # System Admin this is an absolute path from the staging root, e.g.
    # /u11280389/wave1. A non-Admin gives a path relative to their own user folder.
    # Uploading into Inbox is not neutral - it creates Staged documents.
    [string] $TargetPath = '',

    [ValidatePattern('^v\d+\.\d+$')]
    [string] $ApiVersion = 'v26.2',

    # ---- What to do ----
    # REPORT   = list every attachment and project the total size. Moves nothing.
    # TRANSFER = download each attachment and upload it to the target vault's staging.
    #
    # Always start at REPORT. A document count says nothing about attachment volume -
    # one document can carry dozens, most carry none.
    [ValidateSet('REPORT', 'TRANSFER')]
    [string] $Mode       = 'REPORT',

    # ---- What to move ----
    [string] $IdFile     = 'sourcedocids.txt',
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

$ScriptVersion = '2026.08.27-3'

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

$IntKeys    = @('MaxDocuments', 'ReserveMB', 'PartSizeMB', 'MaxRetries', 'Workers')
$SwitchKeys = @('SeparateCredentials')

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

if ($Mode -eq 'TRANSFER' -and [string]::IsNullOrWhiteSpace($TargetPath)) {
    throw @'
TargetPath is not set.

Uploading to the staging ROOT is almost never what is wanted, so this will not
guess. Run probe.bat against the TARGET vault to get its user folder id and
whether your account is Admin there, then set TargetPath - for example
/u<target user id>/wave1 for an Admin, or /wave1 for a non-Admin.
'@
}

$needTarget = @('SourceVaultDNS', 'OutputRoot')
if ($Mode -eq 'TRANSFER') { $needTarget = @('SourceVaultDNS', 'TargetVaultDNS', 'OutputRoot') }
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

function New-StagingFolder {
    # Create the per-document folder. On a re-run it is already there and Vault objects,
    # which is fine and expected.
    #
    # Deliberately NOT matched on the error text: I have not seen what Vault actually
    # returns for "folder exists", and a guessed string match that misses would break
    # every re-run. Any failure here is a warning, because the upload on the very next
    # line is the real test - if the folder genuinely could not be created, that fails
    # loudly and with Vault's own message.
    param([Parameter(Mandatory)][string]$Path)
    try {
        Invoke-VaultApi -Side Target -Method POST -Path '/services/file_staging/items' `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{ kind = 'folder'; path = $Path; overwrite = 'false' } | Out-Null
    }
    catch {
        Write-Log "Folder $Path was not created (it may already exist): $_" 'WARN'
    }
}

function Send-StagingPart {
    # One file part, over HttpWebRequest rather than Invoke-WebRequest.
    #
    # Invoke-WebRequest was sent $buf[0..($read-1)], which on a byte[] produces an
    # Object[], not a byte[]. It then stringifies that - so 877KB of binary went up as a
    # much larger text body and Vault rejected it with OPERATION_NOT_ALLOWED: "Unable to
    # upload additional file parts/bytes". Writing an exact byte count straight to the
    # request stream removes the conversion entirely, and matches how the download side
    # already works.
    param(
        [Parameter(Mandatory)][string]$SessionId,
        [Parameter(Mandatory)][byte[]]$Buffer,
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][int]$PartNumber
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $uri = "https://$($script:Dns['Target'])/api/$ApiVersion/services/file_staging/upload/$SessionId"
        $req = [Net.HttpWebRequest]::Create($uri)
        $req.Method            = 'PUT'
        $req.ContentType       = 'application/octet-stream'
        $req.ContentLength     = $Count
        $req.Timeout           = 900000
        $req.ReadWriteTimeout  = 900000
        # Accept is a RESTRICTED header on HttpWebRequest - Headers.Add throws
        # "The 'Accept' header must be modified using the appropriate property or
        # method". It has to go through the property. Same family as Content-Type and
        # Content-Length, both already set as properties above. Authorization and the
        # X-VaultAPI-* headers are not restricted, so those are fine via Headers.Add.
        $req.Accept = 'application/json'
        $req.Headers.Add('Authorization', $script:Session['Target'])
        $req.Headers.Add('X-VaultAPI-FilePartNumber', "$PartNumber")

        try {
            $rs = $req.GetRequestStream()
            try { $rs.Write($Buffer, 0, $Count) } finally { $rs.Dispose() }

            $resp = $req.GetResponse()
            try {
                $sr   = New-Object IO.StreamReader($resp.GetResponseStream())
                $body = $sr.ReadToEnd(); $sr.Dispose()
                $json = $null
                try { $json = $body | ConvertFrom-Json } catch { }
                if ($json -and (Get-Field $json 'responseStatus') -eq 'FAILURE') {
                    $errs = @(Get-Field $json 'errors' @())
                    throw 'part ' + $PartNumber + ' rejected -- ' + (($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; ')
                }
                return
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
                Write-Log "Target HTTP 429 on part $PartNumber - waiting 60s" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = [math]::Pow(2, $attempt) * 5
                Write-Log "Target transient error on part $PartNumber (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            throw "part $PartNumber failed (HTTP $status): $($_.Exception.Message) $detail"
        }
    }
    throw "part $PartNumber failed after $MaxRetries attempts"
}

function Send-StagingFile {
    param(
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$RemotePath,
        [Parameter(Mandatory)][long]$Size
    )
    $dns  = $script:Dns['Target']
    $open = Invoke-VaultApi -Side Target -Method POST -Path '/services/file_staging/upload' `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body @{ path = $RemotePath; size = $Size; overwrite = 'true' }
    $sid = "$(Get-Field (Get-Field $open 'data' $null) 'id' '')"
    if (-not $sid) { throw "Target did not return an upload session id: $($open | ConvertTo-Json -Depth 5 -Compress)" }

    try {
        $part     = 0
        $partSize = $PartSizeMB * 1MB
        $sent     = [long]0
        $fs = [IO.File]::OpenRead($LocalPath)
        try {
            $buf = New-Object byte[] $partSize
            while (($read = $fs.Read($buf, 0, $buf.Length)) -gt 0) {
                $part++
                Send-StagingPart -SessionId $sid -Buffer $buf -Count $read -PartNumber $part
                $sent += $read
            }
        }
        finally { $fs.Dispose() }
        if ($sent -ne $Size) { throw "uploaded $sent bytes but the session declared $Size" }

        $commit = Invoke-VaultApi -Side Target -Method POST -Path "/services/file_staging/upload/$sid"
        return [pscustomobject]@{ Parts = $part; Session = $sid; Response = $commit }
    }
    catch {
        # Leave no half-finished session behind - they hold quota and expire slowly.
        try { Invoke-VaultApi -Side Target -Method DELETE -Path "/services/file_staging/upload/$sid" | Out-Null }
        catch { Write-Log "Could not abort upload session ${sid}: $_" 'WARN' }
        throw
    }
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
    # Every attachment on the latest version of a document. The listing carries name and
    # size, so the size projection costs nothing extra and no file has to be fetched to
    # find out how big it is.
    param([Parameter(Mandatory)][string]$DocId)
    $r = Invoke-VaultApi -Side Source -Method GET -Path "/objects/documents/$DocId/attachments"
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

Write-Log "Transfer-VaultAttachments.ps1 $ScriptVersion"
Write-Log "Source: $SourceVaultDNS"
Write-Log "Target: $TargetVaultDNS  ->  $(if ($TargetPath) { $TargetPath } else { '(staging root)' })"
Write-Log "Work  : $WorkDir"

if (-not (Test-Path -LiteralPath $IdFile)) {
    $here2 = $PSScriptRoot
    if (-not $here2) { $here2 = (Get-Location).ProviderPath }
    $beside = Join-Path $here2 $IdFile
    if (Test-Path -LiteralPath $beside) { $IdFile = $beside }
}
if (-not (Test-Path -LiteralPath $IdFile)) { throw "IdFile not found: $IdFile" }

$ids  = New-Object System.Collections.ArrayList
$seen = @{}
$n = 0
foreach ($raw in (Get-Content -LiteralPath $IdFile)) {
    $n++
    $t = "$raw".Trim().Trim([char]0xFEFF).Trim('"', "'").TrimEnd(',').Trim()
    if (-not $t -or $t.StartsWith('#')) { continue }
    if ($n -eq 1 -and $t -match '^(id|document.?id)$') { continue }
    if ($t -notmatch '^\d+$') { Write-Log "line ${n}: '$t' is not a document id - skipped" 'WARN'; continue }
    if ($seen.ContainsKey($t)) { continue }
    $seen[$t] = $true
    [void]$ids.Add($t)
}
if ($ids.Count -eq 0) { throw "No document ids found in $IdFile" }
Write-Log "$($ids.Count) document id(s) from $IdFile" 'OK'

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
            if ((Get-Field $row 'Status') -eq 'SUCCESS') { $done[$rk] = $true }
        }
        if ($done.Count) { Write-Log "$($done.Count) already transferred - skipping them" }
    }
}

# Every document is still visited - its attachment list is what says whether there is
# anything left to do, and that is only knowable from the source vault. Attachments
# already moved are skipped individually, inside the loop.
$pending = @($ids)
if ($MaxDocuments -gt 0 -and $pending.Count -gt $MaxDocuments) {
    Write-Log "MaxDocuments $MaxDocuments - this run moves the first $MaxDocuments of $($pending.Count) outstanding" 'WARN'
    $pending = @($pending | Select-Object -First $MaxDocuments)
}
Write-Log "$($pending.Count) document(s) to move"

if (-not $script:Session['Source']) { Connect-Vault -Side Source } else { Write-Log 'Source: using the configured session id' }
if ($Mode -eq 'TRANSFER') {
    if (-not $script:Session['Target']) { Connect-Vault -Side Target } else { Write-Log 'Target: using the configured session id' }
}
else { Write-Log 'REPORT mode - the target vault is not contacted' }

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

if ($Mode -eq 'TRANSFER' -and $Workers -gt 1 -and $pending.Count -gt 1) {

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
                '-Workers', '1', '-MaxDocuments', '0', '-ExistingResults', 'Restart', '-Mode', 'TRANSFER'
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
$moved = [long]0
$seenAttachments = 0

foreach ($id in $pending) {
    $i++
    $docPrefix = "[$i/$($pending.Count)] doc $id"

    # A document with no attachments is the common case, so it must be cheap and quiet.
    try { $attachments = @(Get-DocumentAttachment -DocId $id) }
    catch {
        Write-Log "$docPrefix - ERROR listing attachments: $_" 'ERROR'
        [void]$results.Add([pscustomobject][ordered]@{
            Key = "$id`:LIST"; DocId = $id; AttachmentId = ''; Name = ''; SizeBytes = 0
            Version = ''; TargetPath = ''; Parts = 0; Status = 'ERROR'; Message = "$_"
            StartedUtc = (Get-Date).ToUniversalTime().ToString('s')
            FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
        })
        Save-Results
        continue
    }

    if ($attachments.Count -eq 0) { continue }
    $seenAttachments += $attachments.Count
    $totalBytes = ($attachments | Measure-Object -Property Size -Sum).Sum
    Write-Log "$docPrefix - $($attachments.Count) attachment(s), $(Format-Bytes $totalBytes)"

    $n = 0
    foreach ($att in $attachments) {
        $n++
        $key    = "$id`:$($att.Id)"
        $prefix = "$docPrefix att $n/$($attachments.Count) [$($att.Id)]"

        if ($done.ContainsKey($key)) { Write-Log "$prefix - skipped (already transferred)"; continue }

        $record = [ordered]@{
            Key = $key; DocId = $id; AttachmentId = $att.Id; Name = $att.Name
            SizeBytes = $att.Size; Version = $att.Version; TargetPath = ''; Parts = 0
            Status = ''; Message = ''
            StartedUtc = (Get-Date).ToUniversalTime().ToString('s'); FinishedUtc = ''
        }
        $local = $null
        try {
            if ($Mode -eq 'REPORT') {
                $record.Status  = 'LISTED'
                $record.Message = 'REPORT only'
                Write-Log "$prefix - $($att.Name), $(Format-Bytes $att.Size)"
            }
            elseif ($PSCmdlet.ShouldProcess("attachment $($att.Id) of document $id", 'Transfer')) {
                $free = Get-FreeSpace -Path $WorkDir
                if ($free -ge 0 -and $att.Size -gt 0 -and ($free - $att.Size) -lt ($ReserveMB * 1MB)) {
                    throw "not enough disk: $(Format-Bytes $att.Size) needed, $(Format-Bytes $free) free, ${ReserveMB}MB reserve"
                }

                Write-Log "$prefix - downloading $($att.Name) ($(Format-Bytes $att.Size))"
                $local = Save-AttachmentFile -DocId $id -AttachmentId $att.Id -FileName $att.Name -Destination $WorkDir
                $record.SizeBytes = $local.Size

                # One folder per source document id, then per attachment id, so two
                # attachments sharing a filename on the same document cannot collide
                # either - which the document-level layout alone would not prevent.
                $folder = if ($TargetPath) { $TargetPath.TrimEnd('/') + "/$id/attachments/$($att.Id)" }
                          else { "/$id/attachments/$($att.Id)" }
                $remote = $folder + '/' + $local.Name
                $record.TargetPath = $remote
                New-StagingFolder -Path $folder

                Write-Log "$prefix - uploading to $remote"
                $up = Send-StagingFile -LocalPath $local.Path -RemotePath $remote -Size $local.Size
                $record.Parts  = $up.Parts
                $record.Status = 'SUCCESS'
                $moved += $local.Size
                Write-Log "$prefix - OK ($($local.Name), $(Format-Bytes $local.Size), $($up.Parts) part(s))" 'OK'
            }
            else {
                $record.Status  = 'WHATIF'
                $record.Message = "would move $(Format-Bytes $att.Size)"
                Write-Log "$prefix - WhatIf: would move $($att.Name) ($(Format-Bytes $att.Size))"
            }
        }
        catch {
            $record.Status  = 'ERROR'
            $record.Message = "$_"
            Write-Log "$prefix - ERROR: $_" 'ERROR'
        }
        finally {
            if ($local -and (Test-Path -LiteralPath $local.Path)) {
                try {
                    Remove-Item -LiteralPath $local.Path -Force -WhatIf:$false
                    $freeNow = Get-FreeSpace -Path $WorkDir
                    $freeTxt = if ($freeNow -ge 0) { ", $(Format-Bytes $freeNow) free" } else { '' }
                    Write-Log "$prefix - scratch file deleted ($(Format-Bytes $local.Size)$freeTxt)"
                }
                catch { Write-Log "Could not delete $($local.Path): $_" 'WARN' }
            }
        }
        $record.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
        [void]$results.Add([pscustomobject]$record)
        Save-Results
    }
}

Write-Log "$seenAttachments attachment(s) found across $($pending.Count) document(s)"

# Scratch should be empty. Anything still here is a file a crash or a kill left
# behind, and it will sit there consuming disk until someone notices.
$leftovers = @(Get-ChildItem -LiteralPath $WorkDir -File -ErrorAction SilentlyContinue)
if ($leftovers.Count) {
    $bytes = ($leftovers | Measure-Object -Property Length -Sum).Sum
    Write-Log "$($leftovers.Count) file(s) left in $WorkDir taking $(Format-Bytes $bytes) - safe to delete" 'WARN'
}

$ok     = @($results | Where-Object { $_.Status -eq 'SUCCESS' }).Count
$listed = @($results | Where-Object { $_.Status -eq 'LISTED' })
$bad    = @($results | Where-Object { $_.Status -notin @('SUCCESS','WHATIF','LISTED') }).Count
Write-Log '----------------------------------------------------------------'
if ($listed.Count) {
    $bytes = ($listed | Measure-Object -Property SizeBytes -Sum).Sum
    Write-Log "REPORT: $($listed.Count) attachment(s) totalling $(Format-Bytes $bytes)" 'OK'
    Write-Log 'Nothing was moved. Set Mode = TRANSFER when the numbers look right.'
}
Write-Log "Moved $ok attachment(s), $bad failed, $(Format-Bytes $moved) transferred" $(if ($bad) { 'WARN' } else { 'OK' })
Write-Log "Results : $ResultsCsv"
Write-Log "Log     : $TranscriptLog"
if ($bad -gt 0) { exit 1 }
