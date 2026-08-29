<#
.SYNOPSIS
    One command for the Vault migration work.

.DESCRIPTION
    powershell -ExecutionPolicy Bypass -File .\vault.ps1 <command> [subcommand] [options]

    Or, once per PowerShell window:

        Set-ExecutionPolicy -Scope Process Bypass
        .\vault.ps1 <command> [subcommand] [options]

    Everything lives in one folder: this script, the VaultKit\ module beside it,
    vault.ini, and whatever the runs write. `vault.ps1 update` fetches the first three
    from GitHub and never touches the fourth.

    Authentication is its own flow: `vault.ps1 login` prompts for each vault in turn and
    caches the sessions to .vault-session.json. Every other command reads that file and
    never prompts - unless it is missing, in which case the command logs in itself, so a
    first run works without knowing login exists.

.NOTES
    Windows PowerShell 5.1 compatible. No modules to install.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)][string]$Command = 'help',
    [Parameter(Position = 1)][string]$Subcommand = '',
    [string]$ConfigFile = '',

    # Local folder for logs, results, and the scratch space a file passes through while
    # it is in flight. The only place anything is written. Overrides [paths] output.
    [Alias('Out', 'LogDir', 'WorkDir')]
    [string]$OutputRoot = '',
    [switch]$NoPrompt,

    # login: one credential for every vault, instead of one prompt each.
    [switch]$Shared,

    # Work out what would happen and report it, changing nothing.
    [switch]$Plan,
    # Stop once this many items are genuinely done - not this many examined. Most
    # documents carry no attachments, so capping by document can prove nothing.
    [int]$Test = 0,
    # Cap the input examined.
    [int]$Limit = 0,
    # FAST compares the MD5 each vault records; DEEP downloads both copies and hashes.
    [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
    # Send a same-name attachment whose bytes differ, as a new version.
    [switch]$ReplaceDiffering,
    [ValidateSet('Prompt', 'Resume', 'Fresh')][string]$Existing = 'Resume',
    # documents: the folder on the target vault's File Staging to upload into.
    # Overrides [documents] path.
    [string]$TargetPath = '',
    # verify: check what is on the target, rather than everything in the id list.
    [switch]$Staged,
    # update: go ahead even though a run is holding a lock.
    [switch]$Force,
    # update: fetch this exact commit instead of whatever main points at. Pins a known
    # good version, rolls one back, and bypasses the raw CDN's branch cache outright.
    [ValidatePattern('^$|^[0-9a-fA-F]{7,40}$')]
    [string]$Commit = '',
    # Skip the "are these the right two vaults" confirmation.
    [switch]$Yes,

    # ---- Set by the supervisor on the workers it launches ----
    # Overrides the id list named in the config, so a worker reads only its own shard.
    [string]$IdFile = '',
    # Marks a worker. A worker must not write the session file it shares with the
    # supervisor and its siblings: several processes rewriting one JSON file the moment
    # their sessions expire is how a torn file gets written.
    [switch]$Worker,
    # Credentials exported by the supervisor, when it had any. A worker runs hidden and
    # cannot be asked, so without this it cannot renew an expired session.
    [string]$CredentialFile = '',
    # How many processes move the work. 0 means "whatever [limits] workers says".
    [ValidateRange(0, 16)]
    [int]$Workers = 0
)

$ScriptVersion = '2026.08.29-20'

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$here = $PSScriptRoot
if (-not $here) { $here = (Get-Location).ProviderPath }

$Repo = 'kevinnassery/veeva'

# The module, in load order, and the manifest `update` fetches. Derived from one list so
# that adding a part cannot leave it undelivered - a dispatcher calling a function from a
# file nobody downloads is the failure this arrangement exists to make impossible.
$VaultKitParts = @('Log', 'Config', 'Auth', 'Http', 'Ids', 'Run', 'Workers', 'Attachments', 'Documents')

# vault.ps1 goes LAST: it is the file being executed, and it is the one whose failure to
# land leaves the least broken folder behind.
$Manifest = @($VaultKitParts | ForEach-Object { "VaultKit/$_.ps1" }) + @('README.md', 'vault.ps1')

# Fetched only when it is absent. It holds the vault hostnames someone typed in, and an
# update that overwrote them would be data loss dressed up as a refresh.
$ManifestIfAbsent = @('vault.ini')

$verb = "$Command".ToLowerInvariant()
$sub  = "$Subcommand".ToLowerInvariant()

# `update` has to run with nothing but this file on disk. A first run is exactly the case
# where VaultKit\ is not there yet, and a bootstrap that needs eight files fetched by
# hand to reach the command that fetches files is not a bootstrap. version and help are
# answerable without the module too, so they load nothing either.
if ($verb -notin @('update', 'version', 'help', '')) {
    foreach ($part in $VaultKitParts) {
        $f = Join-Path (Join-Path $here 'VaultKit') "$part.ps1"
        if (-not (Test-Path -LiteralPath $f)) {
            throw "VaultKit\$part.ps1 is missing next to vault.ps1. Run: .\vault.ps1 update"
        }
        . $f
    }
}

# --------------------------------------------------------------------------------------
# Config and logging, needed by everything except help
# --------------------------------------------------------------------------------------

function Initialize-VaultRun {
    param([string]$LogName)
    Set-VaultNoPrompt -Value ([bool]$NoPrompt)
    if (-not $ConfigFile) { $ConfigFile = Join-Path $here 'vault.ini' }
    $script:Cfg        = Import-VaultConfig -Path $ConfigFile
    $script:CfgPath    = $ConfigFile
    $script:Api        = Get-VaultSetting -Config $script:Cfg -Section vault -Key api -Default 'v26.2'
    $script:SourceHost = Get-VaultHostName (Get-VaultSetting -Config $script:Cfg -Section vault -Key source)
    $script:TargetHost = Get-VaultHostName (Get-VaultSetting -Config $script:Cfg -Section vault -Key target)

    $root = $OutputRoot
    if (-not $root) { $root = Get-VaultSetting -Config $script:Cfg -Section paths -Key output -Default '.' }
    $root = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $root))
    if ($root.Length -gt 3) { $root = $root.TrimEnd('\') }   # not on a bare drive root: C:\ trimmed to C: means the CWD on C:
    $script:Out = $root

    if ($LogName) { [void](Start-VaultLog -Directory $root -Name $LogName) }

    if ($Worker) {
        Set-VaultSessionPersist -Value $false
        Set-VaultLockEnabled -Value $false
    }
    if ($CredentialFile) {
        $n = Import-VaultCredentials -Path $CredentialFile
        Write-VaultLog "worker: $n credential(s) loaded"
    }
}

function New-VaultContext {
    # Everything a workflow needs, resolved once. Passed as one object so a command
    # signature stays readable and nothing reaches for a script-scope global.
    param([string]$Section = '', [string]$MapKey = '', [string]$IdsKey = '')
    $map = $null
    $ids = @()
    if ($MapKey) {
        $file = Get-VaultSetting -Config $script:Cfg -Section $Section -Key $MapKey -Default ''
        if (-not $file) { throw "[$Section] $MapKey is not set in $($script:CfgPath)" }
        $map = Import-VaultIdMap -Path $file -LegacyNames @('map.csv')
    }
    if ($IdsKey) {
        $file = $IdFile
        if (-not $file) { $file = Get-VaultSetting -Config $script:Cfg -Section $Section -Key $IdsKey -Default '' }
        if (-not $file) { throw "[$Section] $IdsKey is not set in $($script:CfgPath)" }
        $ids = Import-VaultIdList -Path $file -LegacyNames @('sourcedocids.txt')
    }

    $tpath = $TargetPath
    if (-not $tpath) { $tpath = Get-VaultSetting -Config $script:Cfg -Section documents -Key path -Default '' }

    # Vault requires parts of at least 5MB (except the last) and at most 52MB. Clamped
    # rather than rejected: a number outside the range in an ini is a typo, and failing
    # the whole run over it hours into a migration helps nobody.
    $part = [int](Get-VaultSetting -Config $script:Cfg -Section limits -Key part -Default 25)
    if ($part -lt 5)  { $part = 5 }
    if ($part -gt 52) { $part = 52 }

    $nWorkers = $Workers
    if ($nWorkers -le 0) { $nWorkers = [int](Get-VaultSetting -Config $script:Cfg -Section limits -Key workers -Default 1) }
    if ($nWorkers -lt 1)  { $nWorkers = 1 }
    if ($nWorkers -gt 16) { $nWorkers = 16 }

    return [pscustomobject]@{
        Api        = $script:Api
        ScriptPath = (Join-Path $here 'vault.ps1')
        ConfigPath = $script:CfgPath
        Workers    = $nWorkers
        SourceHost = $script:SourceHost
        TargetHost = $script:TargetHost
        Out        = $script:Out
        Scratch    = (New-VaultScratch -Root $script:Out -Name 'scratch')
        Map        = $map
        Ids        = $ids
        TargetPath = $tpath
        PartSizeMB = $part
        ReserveMB  = [int](Get-VaultSetting -Config $script:Cfg -Section limits -Key reserve -Default 2048)
        Existing   = $Existing
        WhatIf     = [bool]$WhatIfPreference
    }
}

function Confirm-VaultsForRun {
    # Both vaults established, proven and shown before any work starts. Prompted for
    # separately, because the source is a production vault and the target belongs to a
    # different organisation - finding out which of the two credentials was wrong hours
    # into a transfer is exactly what this prevents.
    $vaults = @()
    if ($script:SourceHost) { $vaults += @{ Role = 'source'; Name = $script:SourceHost } }
    if ($script:TargetHost -and $script:TargetHost -ne $script:SourceHost) {
        $vaults += @{ Role = 'target'; Name = $script:TargetHost }
    }
    if (-not $vaults.Count) { throw "No vaults configured. Set [vault] source = ... in $($script:CfgPath)" }
    return Confirm-VaultSessions -Vaults $vaults -ApiVersion $script:Api -Yes:$Yes
}

function Get-ConfiguredHosts {
    $hosts = @()
    if ($script:SourceHost) { $hosts += $script:SourceHost }
    if ($script:TargetHost -and $script:TargetHost -ne $script:SourceHost) { $hosts += $script:TargetHost }
    if (-not $hosts.Count) { throw "No vaults configured. Set [vault] source = ... in $($script:CfgPath)" }
    return $hosts
}

# --------------------------------------------------------------------------------------
# Update
#
# Self-contained on purpose: nothing here may call into VaultKit, because the folder this
# runs in may not have VaultKit yet.
#
# Overwriting vault.ps1 while it is the script being executed is safe. PowerShell reads
# and parses the whole file before running any of it, and holds no handle on it after
# that. cmd.exe reads a .bat line by line as it goes, which is why the fetcher this
# replaces could never update itself without risking a half-read script.
# --------------------------------------------------------------------------------------

function Get-VaultHeadSha {
    # One call for the head commit. raw.githubusercontent.com caches the branch URL for
    # five minutes and ignores no-cache, so pulling from /main can hand back the PREVIOUS
    # version of a file - which looks exactly like a fix that did not work. A SHA-pinned
    # URL is immutable and always current. This endpoint returns the bare SHA and is not
    # behind that cache.
    try {
        $r = Invoke-WebRequest -Uri "https://api.github.com/repos/$Repo/commits/main" `
                 -Headers @{ Accept = 'application/vnd.github.sha' } -UseBasicParsing -TimeoutSec 30
        $body = $r.Content
        if ($body -is [byte[]]) { $body = [Text.Encoding]::ASCII.GetString($body) }
        $sha = "$body".Trim()
        if ($sha -match '^[0-9a-f]{40}$') { return $sha }
    }
    catch { }
    return ''
}

function Get-VaultFileVersion {
    param([Parameter(Mandatory)][string]$Path)
    try {
        foreach ($line in (Get-Content -LiteralPath $Path -TotalCount 80)) {
            if ($line -like '$ScriptVersion = *') {
                $parts = $line.Split("'")
                if ($parts.Count -ge 2) { return $parts[1] }
            }
        }
    }
    catch { }
    return ''
}

function Test-VaultRunInProgress {
    # A lock only means something if its process is still alive. A crash leaves the file
    # behind, and making someone delete it by hand to get on with their day is a bad
    # trade for a guard that is meant to protect them.
    param([Parameter(Mandatory)][string]$Folder)
    $busy = $false
    foreach ($lock in @(Get-ChildItem -LiteralPath $Folder -Filter '.run-*.lock' -File -ErrorAction SilentlyContinue)) {
        $owner = ''
        foreach ($line in @(Get-Content -LiteralPath $lock.FullName -ErrorAction SilentlyContinue)) {
            if ($line -match '^pid=(\d+)') { $owner = $Matches[1] }
        }
        $alive = $false
        if ($owner) { $alive = [bool](Get-Process -Id ([int]$owner) -ErrorAction SilentlyContinue) }
        if ($alive) {
            Write-Host "    $($lock.Name) - pid $owner is still running" -ForegroundColor Yellow
            $busy = $true
        }
        else {
            Write-Host "  cleared stale lock $($lock.Name) (pid $owner is not running)"
            try { Remove-Item -LiteralPath $lock.FullName -Force -WhatIf:$false } catch { }
        }
    }
    return $busy
}

function Invoke-Update {
    Write-Host ''
    Write-Host "vault $ScriptVersion - update"
    Write-Host "Folder : $here"

    if (Test-VaultRunInProgress -Folder $here) {
        if (-not $Force) {
            Write-Host ''
            Write-Host '  REFUSING TO UPDATE - a run is still going. Let it finish, or pass -Force.' -ForegroundColor Red
            exit 1
        }
        Write-Host '  -Force given: updating over a running job.' -ForegroundColor Yellow
    }

    if ($Commit) {
        # Asked for by hash: no API call, no branch, nothing to resolve. Immutable, so
        # the CDN cache cannot serve anything else under it.
        $sha  = $Commit.ToLowerInvariant()
        $base = "https://raw.githubusercontent.com/$Repo/$sha"
        Write-Host "Commit : $sha (pinned)"
    }
    else {
        $sha = Get-VaultHeadSha
        if ($sha) {
            $base = "https://raw.githubusercontent.com/$Repo/$sha"
            Write-Host "Commit : $sha"
        }
        else {
            $base = "https://raw.githubusercontent.com/$Repo/main"
            Write-Host '  WARNING: could not read the head commit - falling back to the main branch,' -ForegroundColor Yellow
            Write-Host '  which the CDN caches for five minutes. Files may be out of date, and an old' -ForegroundColor Yellow
            Write-Host '  one looks exactly like a fix that did not work. Pass -Commit <sha> to pin.' -ForegroundColor Yellow
        }
    }
    Write-Host ''

    # Everything is fetched to a staging folder first and only moved into place once all
    # of it has arrived. A half-applied update leaves a dispatcher from one version
    # calling a module from another; the fetcher this replaces could only warn about that
    # after the fact, having already made the mess.
    $stage = Join-Path $here ('.update-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $stage -Force -WhatIf:$false | Out-Null
    try {
        $staged = [ordered]@{}
        foreach ($rel in $Manifest) {
            $tmp = Join-Path $stage ($rel -replace '[\\/]', '_')
            try {
                Invoke-WebRequest -Uri "$base/$rel" -OutFile $tmp -UseBasicParsing -TimeoutSec 120
            }
            catch {
                Write-Host "  FAILED    $rel" -ForegroundColor Red
                Write-Host "            $_" -ForegroundColor Red
                Write-Host ''
                Write-Host '  Nothing here was changed. Run update again.' -ForegroundColor Red
                exit 1
            }
            $staged[$rel] = $tmp
        }

        # One version across the whole set. They all come from one commit, so a mismatch
        # means the repo itself shipped inconsistent files rather than that a download
        # was missed - either way it is worth saying out loud before anything runs.
        $versions = @()
        foreach ($rel in $staged.Keys) {
            $v = Get-VaultFileVersion -Path $staged[$rel]
            if ($v) { $versions += $v }
        }
        $versions = @($versions | Sort-Object -Unique)

        foreach ($rel in $staged.Keys) {
            $dest = [IO.Path]::GetFullPath((Join-Path $here $rel))
            $dir  = Split-Path -Parent $dest
            if (-not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false | Out-Null
            }
            $same = $false
            if (Test-Path -LiteralPath $dest) {
                try {
                    $same = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -eq
                            (Get-FileHash -LiteralPath $staged[$rel] -Algorithm SHA256).Hash
                }
                catch { $same = $false }
            }
            if ($same) {
                Write-Host "  unchanged $rel"
                continue
            }
            try {
                Move-Item -LiteralPath $staged[$rel] -Destination $dest -Force -WhatIf:$false
                Write-Host "  updated   $rel" -ForegroundColor Green
            }
            catch {
                Write-Host "  FAILED    $rel - could not replace it: $_" -ForegroundColor Red
                Write-Host '  Some files were already updated. Run update again.' -ForegroundColor Red
                exit 1
            }
        }

        Write-Host ''
        if ($sha) { Write-Host "Repeat this exact set with:  .\vault.ps1 update -Commit $sha" }
        if ($versions.Count -eq 1) { Write-Host "All files at version $($versions[0])." }
        elseif ($versions.Count -gt 1) {
            Write-Host "  WARNING: $($versions.Count) different versions in this folder: $($versions -join ', ')" -ForegroundColor Yellow
        }
    }
    finally { Remove-Item -LiteralPath $stage -Recurse -Force -WhatIf:$false -ErrorAction SilentlyContinue }

    foreach ($rel in $ManifestIfAbsent) {
        $dest = [IO.Path]::GetFullPath((Join-Path $here $rel))
        if (Test-Path -LiteralPath $dest) {
            Write-Host "  yours     $rel (left alone)"
            continue
        }
        try {
            Invoke-WebRequest -Uri "$base/$rel" -OutFile $dest -UseBasicParsing -TimeoutSec 120
            Write-Host "  written   $rel - fill in [vault] source and target before running anything" -ForegroundColor Yellow
        }
        catch { Write-Host "  FAILED    $rel - $_" -ForegroundColor Red }
    }

    # Files from the flat layout this replaces. Reported, never deleted: they are in
    # someone's working folder, and a tidy-up that removed the wrong file in the middle
    # of a migration would be a bad trade.
    $retired = @('attachments.bat', 'validator.bat', 'refresh.bat', 'starting-cleanup.bat', 'vault.bat',
                 'Sync-VaultAttachments.ps1', 'Validate-VaultAttachments.ps1', 'Transfer-VaultAttachments.ps1',
                 'Transfer-VaultDocuments.ps1', 'Get-VaultSession.ps1', 'Probe-Vault.ps1')
    $found = @($retired | Where-Object { Test-Path -LiteralPath (Join-Path $here $_) })
    if ($found.Count) {
        Write-Host ''
        Write-Host "  $($found.Count) file(s) here are from the old layout and nothing loads them:" -ForegroundColor Yellow
        Write-Host "    $($found -join ', ')" -ForegroundColor Yellow
        Write-Host '  Delete them once you are sure nothing of yours depends on them.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host 'Next: .\vault.ps1 login' -ForegroundColor Green
    Write-Host ''
}

# --------------------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------------------

function Invoke-Login {
    Initialize-VaultRun -LogName 'login'
    $hosts = Get-ConfiguredHosts
    Write-VaultLog "vault $ScriptVersion - logging in to $($hosts.Count) vault(s)"

    # One prompt per vault. A production vault and the vault being migrated into are
    # commonly two separate accounts with two separate passwords, and reusing the first
    # answer against the second vault fails in a way that reads like a wrong password
    # rather than the wrong account. -Shared is the opt-in for one account that genuinely
    # does exist on both sides.
    if ($Shared) {
        Write-VaultLog "-Shared: one credential for all $($hosts.Count) vault(s)"
        $cred = Get-VaultCredential -VaultHost $hosts[0] -Message "Vault credentials (used for all $($hosts.Count) vault(s))"
        foreach ($h in $hosts) { Set-VaultCredential -VaultHost $h -Credential $cred }
    }

    # Every vault is tried, not just up to the first failure. Stopping at the source
    # means never finding out whether the target credentials were right either, so a
    # wrong password costs two rounds of prompting instead of one.
    $failed = @()
    foreach ($h in $hosts) {
        $role = if ($h -eq $script:SourceHost) { 'source' } else { 'target' }
        Write-VaultLog "$role vault: $h"
        try { [void](Connect-VaultHost -VaultHost $h -ApiVersion $script:Api) }
        catch {
            $failed += $h
            Write-VaultLog "$_" 'ERROR'
        }
    }
    if ($failed.Count) {
        Write-VaultLog '----------------------------------------------------------------'
        Write-VaultLog "$($failed.Count) of $($hosts.Count) vault(s) did not authenticate: $($failed -join ', ')" 'ERROR'
        if ($failed.Count -lt $hosts.Count) {
            Write-VaultLog 'The others are cached, so only the failures above need another try.' 'WARN'
        }
        exit 1
    }

    [void](Confirm-VaultSessions -Vaults @($hosts | ForEach-Object {
        @{ Role = $(if ($_ -eq $script:SourceHost) { 'source' } else { 'target' }); Name = $_ }
    }) -ApiVersion $script:Api -Yes)

    Write-VaultLog "Sessions cached in $(Get-VaultSessionPath)" 'OK'
    Write-VaultLog 'That file is a live token for your account. Treat it like a password; vault logout removes it.' 'WARN'
}

function Invoke-Whoami {
    Initialize-VaultRun
    $sessions = Read-VaultSessions
    if (-not $sessions.Count) {
        Write-VaultLog "No cached sessions. Run: .\vault.ps1 login" 'WARN'
        return
    }
    foreach ($h in ($sessions.Keys | Sort-Object)) {
        $e   = $sessions[$h]
        $age = ''
        try {
            $t = [datetime]::Parse("$(Get-VaultField $e 'obtained' '')").ToUniversalTime()
            $age = ' ({0:N0} min ago)' -f ((Get-Date).ToUniversalTime() - $t).TotalMinutes
        } catch { }
        Write-VaultLog ("{0}  userId {1}  vaultId {2}{3}" -f $h, (Get-VaultField $e 'userId' '?'), (Get-VaultField $e 'vaultId' '?'), $age)
    }
    Write-VaultLog "Session file: $(Get-VaultSessionPath)"
}

function Invoke-Logout {
    Initialize-VaultRun
    if (Clear-VaultSessions) { Write-VaultLog 'Session file deleted.' 'OK' }
    else { Write-VaultLog 'No session file to delete.' }
}

function Invoke-Probe {
    Initialize-VaultRun -LogName 'probe'
    Write-VaultLog "vault $ScriptVersion - probe (read only, nothing is changed)"

    foreach ($h in (Get-ConfiguredHosts)) {
        $role = if ($h -eq $script:SourceHost) { 'source' } else { 'target' }
        Write-VaultLog '----------------------------------------------------------------'
        Write-VaultLog "$role vault: $h"

        # One attempt, no backoff. Probe is a diagnostic: four retries with exponential
        # waits means an unreachable vault takes five minutes to report itself, which is
        # the opposite of what someone running a probe wants.
        $me = $null
        try { $me = Invoke-VaultApi -VaultHost $h -ApiVersion $script:Api -Method GET -Path '/objects/users/me' -MaxRetries 1 }
        catch { Write-VaultLog "Could not read the user: $_" 'ERROR'; continue }

        $u       = Get-VaultField (@(Get-VaultField $me 'users' @()) | Select-Object -First 1) 'user' $null
        $uid     = "$(Get-VaultField $u 'id' '')"
        $profile = "$(Get-VaultField $u 'security_profile__v' '')"
        $isAdmin = ($profile -match 'vault_owner|system_admin')

        Write-VaultLog "  user      $(Get-VaultField $u 'user_name__v' '')"
        Write-VaultLog "  id        $uid"
        Write-VaultLog "  profile   $profile"
        Write-VaultLog "  staging   /u$uid  $(if ($isAdmin) { '(admin: paths are absolute from the staging root)' } else { '(non-admin: paths are relative to this folder)' })"

        try {
            $items = Invoke-VaultApi -VaultHost $h -ApiVersion $script:Api -Method GET `
                        -Path '/services/file_staging/items/?recursive=false&limit=20' -MaxRetries 1
            $n = @(Get-VaultField $items 'data' @()).Count
            Write-VaultLog "  staging root is listable ($n item(s) visible)" 'OK'
        }
        catch { Write-VaultLog "  staging root not listable: $_" 'WARN' }
    }
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "Log: $script:VaultLogFile"
}

function Invoke-Attachments {
    param([string]$Action)
    switch ($Action) {
        'sync' {
            Initialize-VaultRun -LogName 'attachments-sync'
            Start-VaultLock -Name 'attachments'
            try {
                Write-VaultLog "vault $ScriptVersion - attachments sync"
                [void](Confirm-VaultsForRun)
                $ctx = New-VaultContext -Section 'attachments' -MapKey 'map'
                $bad = Invoke-VaultAttachmentsSync -Context $ctx -Plan:$Plan `
                          -ReplaceDiffering:$ReplaceDiffering -TestCount $Test -Limit $Limit
                Write-VaultLog "Log: $script:VaultLogFile"
                if ($bad -gt 0) { exit 1 }
            }
            finally { Stop-VaultLock }
        }
        'verify' {
            Initialize-VaultRun -LogName 'attachments-verify'
            Start-VaultLock -Name 'attachments'
            try {
                Write-VaultLog "vault $ScriptVersion - attachments verify ($Depth)"
                [void](Confirm-VaultsForRun)
                $ctx = New-VaultContext -Section 'attachments' -MapKey 'map'
                $bad = Invoke-VaultAttachmentsVerify -Context $ctx -Depth $Depth -TestCount $Test -Limit $Limit
                Write-VaultLog "Log: $script:VaultLogFile"
                if ($bad -gt 0) { exit 1 }
            }
            finally { Stop-VaultLock }
        }
        default {
            Write-Host "vault.ps1 attachments <sync|verify>" -ForegroundColor Red
            exit 2
        }
    }
}

function Invoke-Documents {
    param([string]$Action)
    switch ($Action) {
        { $_ -in @('stage', 'transfer') } {
            Initialize-VaultRun -LogName 'documents-stage'
            Start-VaultLock -Name 'documents'
            try {
                Write-VaultLog "vault $ScriptVersion - documents stage"
                [void](Confirm-VaultsForRun)
                $ctx = New-VaultContext -Section 'documents' -IdsKey 'ids'
                $bad = Invoke-VaultDocumentsStage -Context $ctx -Plan:$Plan -TestCount $Test -Limit $Limit
                Write-VaultLog "Log: $script:VaultLogFile"
                if ($bad -gt 0) { exit 1 }
            }
            finally { Stop-VaultLock }
        }
        'verify' {
            # A command of its own, never chained onto the end of a transfer: a check
            # that only runs as the last step of the thing it checks cannot be re-run
            # against a finished migration, and stops running exactly when the transfer
            # fails - which is when it is worth the most.
            Initialize-VaultRun -LogName 'documents-verify'
            Start-VaultLock -Name 'documents'
            try {
                Write-VaultLog "vault $ScriptVersion - documents verify ($Depth)"
                [void](Confirm-VaultsForRun)
                $ctx = New-VaultContext -Section 'documents' -IdsKey 'ids'
                $bad = Invoke-VaultDocumentsVerify -Context $ctx -Depth $Depth -TestCount $Test -Limit $Limit -Staged:$Staged
                Write-VaultLog "Log: $script:VaultLogFile"
                if ($bad -gt 0) { exit 1 }
            }
            finally { Stop-VaultLock }
        }
        'list' {
            Initialize-VaultRun -LogName 'documents-list'
            Write-VaultLog "vault $ScriptVersion - documents list (read only, nothing is changed)"
            [void](Confirm-VaultsForRun)
            $ctx = New-VaultContext -Section 'documents'
            [void](Invoke-VaultDocumentsList -Context $ctx)
            Write-VaultLog "Log: $script:VaultLogFile"
        }
        default {
            Write-Host "vault.ps1 documents <stage|verify|list>" -ForegroundColor Red
            exit 2
        }
    }
}

function Invoke-Help {
    $v = $ScriptVersion
    Write-Host @"

vault $v

  powershell -ExecutionPolicy Bypass -File .\vault.ps1 <command> [options]

  update                   Fetch the latest scripts from GitHub into this folder
  login                    Log in to every configured vault, cache the sessions
  whoami                   Who each cached session belongs to, and its age
  logout                   Delete the cached sessions
  probe                    Read-only survey of each vault. Changes nothing

  documents stage          Copy document source files into the target's File Staging
  documents list           How much is on the target already, and whether it looks right
  documents verify         Prove what landed in File Staging matches the source
  attachments sync         Deliver document attachments the target is missing
  attachments verify       Prove both vaults hold the same bytes
  version                  Print the version
  help                     This

Options
  -ConfigFile <path>       Default: vault.ini beside this script
  -Out <dir>               Logs, results and scratch go here. Overrides [paths] output
                           (also spelled -OutputRoot, -LogDir, -WorkDir)
  -NoPrompt                Fail instead of asking for credentials
  -Shared                  login: one credential for every vault, not one prompt each
  -Plan                    Report what would happen, change nothing
  -Test <n>                Stop once n items are genuinely done (not n examined)
  -Limit <n>               Cap the input examined
  -TargetPath <path>       documents: overrides [documents] path
  -Staged                  verify: check what is ON the target, not the whole id list
  -Workers <n>             Move the work with n processes. Overrides [limits] workers
  -Depth FAST|DEEP         verify: sizes and recorded MD5, or download both and hash
  -ReplaceDiffering        sync: send same-name attachments whose bytes differ
  -Existing Resume|Fresh   Keep earlier results, or rotate them aside
  -Yes                     Skip the "are these the right two vaults" confirmation
  -Commit <sha>            update: fetch this exact commit, not whatever main points at
  -Force                   update: go ahead even though a run holds a lock
  -WhatIf                  Withhold every write to Vault

Config is vault.ini, sectioned:

  [vault]
  source = your-source-vault.veevavault.com
  target = your-target-vault.veevavault.com
  api    = v26.2

  [paths]
  output = C:\vault-work

  [documents]
  ids  = documents-ids.txt
  path = /u<target user id>/wave1

Each vault is logged into separately, so a production vault and the vault being
migrated into can be two different accounts. Pass -Shared when one account covers
both. Sessions are cached in .vault-session.json beside this script, keyed by vault
host. It holds live tokens: treat it like a password, and log out when finished.

Not yet ported from legacy\: submissions import, and the object record pull that
get-attachments.bat does today.

"@
}

# --------------------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------------------

switch ($verb) {
    'update'      { Invoke-Update }
    'login'       { Invoke-Login }
    'whoami'      { Invoke-Whoami }
    'logout'      { Invoke-Logout }
    'probe'       { Invoke-Probe }
    'attachments' { Invoke-Attachments -Action $sub }
    'documents'   { Invoke-Documents -Action $sub }
    'version'     { Write-Host $ScriptVersion }
    'help'        { Invoke-Help }
    ''            { Invoke-Help }
    default   {
        Write-Host "Unknown command '$Command'." -ForegroundColor Red
        if ($sub) { Write-Host "(subcommand '$Subcommand' was also given)" -ForegroundColor Red }
        Invoke-Help
        exit 2
    }
}
