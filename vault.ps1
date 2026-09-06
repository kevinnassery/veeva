<#
.SYNOPSIS
    One command for the Vault migration work.

.DESCRIPTION
    powershell -ExecutionPolicy Bypass -File .\vault.ps1 <command> [subcommand] [options]

    Or, once per PowerShell window:

        Set-ExecutionPolicy -Scope Process Bypass
        .\vault.ps1 <command> [subcommand] [options]

    Everything lives in one folder: this script, vault.ini, and whatever the runs write.
    The script is self-contained - the VaultKit module is built into it - so `vault.ps1
    update` fetches two files and never overwrites a vault.ini you have filled in.

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
    # attachments sync: ask the vault which documents carry attachments and examine only
    # those, instead of listing every mapped document to find out. Vault's 2,000-calls-
    # per-five-minutes allowance is per user, so this is the only lever that makes a
    # large map faster - workers cannot outrun a budget they share.
    [switch]$Prefilter,
    [ValidateSet('Prompt', 'Resume', 'Fresh')][string]$Existing = 'Resume',
    # documents: the folder on the target vault's File Staging to upload into.
    # Overrides [documents] path.
    [string]$TargetPath = '',
    # submissions: which vault holds the Submissions Archive. Overrides
    # [submissions] vault, which in turn overrides [vault] target. The legacy importer
    # had its own VaultDNS and was not tied to the migration's two vaults; folding it
    # onto the target silently pointed it at the wrong one.
    [string]$VaultHost = '',
    # verify: check what is on the target, rather than everything in the id list.
    [switch]$Staged,

    # ---- roles ----
    # Name the documents with a VQL condition instead of a map.
    [string]$Where = '',
    # Where the desired state comes from.
    [ValidateSet('Lifecycle', 'Document', 'Table')][string]$DesiredFrom = 'Lifecycle',
    # Assign groups, users, or both.
    [ValidateSet('Both', 'Groups', 'Users')][string]$Assign = 'Both',
    # Apply the document type's default security alongside the lifecycle rules.
    [switch]$WithTypeDefaults,
    # A defaults table. Overrides [roles] defaults.
    [string]$Defaults = '',
    # Only these roles, or all but these.
    [string[]]$Role = @(),
    [string[]]$ExcludeRole = @(),
    [ValidateRange(1, 1000)][int]$BatchSize = 200,
    # The permission sync touches only documents created by this user within this many
    # hours before now. The user defaults to whoever the session belongs to, since the
    # account doing the repair is the account that made them; the window has no sensible
    # default and is required, because a run that grants people access must not be able
    # to reach further back than it was told to.
    [string]$CreatedBy = 'me',
    [int]$WithinHours = 0,
    # The fields the window and the creator are matched on. Defaults confirmed against
    # the vault with `verify fields`; overridable because another vault may differ.
    [string]$DateField = 'document_creation_date__v',
    [string]$CreatorField = 'created_by__v',
    # Optional: a file of document ids, one per line, that the scope query is expected to
    # return. Reported both ways, because a count agreeing is not the sets agreeing.
    [string]$ExpectIds = '',
    # roles assign: skip documents an earlier run already finished, rather than reading
    # every one of them again. roles verify is what confirms the skipped ones.
    [switch]$Resume,

    # ---- verify ----
    # trial: a fixed handful, at random. sample: sized for a confidence level.
    [int]$TrialSize = 25,
    [ValidateSet(90, 95, 99)][int]$Confidence = 95,
    [ValidateRange(0.1, 50)][double]$Margin = 5,
    # Fixing this makes a sample reproducible, which is what makes it evidence.
    [int]$Seed = 0,
    # Also check each document's roles against the lifecycle rules, not just that they
    # are populated. Two extra reads per document.
    [switch]$WithRoleRules,
    # roles verify: read each document's roles individually instead of in bulk.
    [switch]$Slow,
    # roles verify: check every document the run touched, not only the ones it changed.
    [switch]$All,
    # verify map: the target document field that holds the source document's id.
    [string]$Anchor = '',
    # verify fields: show only fields whose name matches this.
    [string]$Match = '',
    # roles mdl: which document type, and optionally which subtype.
    [string]$Type = '',
    [string]$Subtype = '',
    [string]$Classification = '',
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
    # The same, for workflows whose input is a map rather than a list.
    [string]$MapFile = '',
    # Name the id columns rather than letting the header wording decide.
    [string]$SourceColumn = '',
    [string]$TargetColumn = '',
    # map write: where the canonical copy goes.
    [string]$OutFile = '',
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

$ScriptVersion = '2026.09.06-5'

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
$VaultKitParts = @('Log', 'Config', 'Auth', 'Http', 'Ids', 'Run', 'Workers', 'Attachments', 'Documents', 'Submissions', 'Roles', 'Verify')

# vault.ps1 goes LAST: it is the file being executed, and it is the one whose failure to
# land leaves the least broken folder behind.
# Two files. The module is inside vault.ps1 in the built script, so there is nothing else
# to fetch and nothing that can arrive at a different version from the dispatcher that
# calls it - which is the whole reason the parts were folded in.
$Manifest = @('README.md', 'vault.ps1')

# Fetched only when it is absent. It holds the vault hostnames someone typed in, and an
# update that overwrote them would be data loss dressed up as a refresh.
$ManifestIfAbsent = @('vault.ini')

$verb = "$Command".ToLowerInvariant()
$sub  = "$Subcommand".ToLowerInvariant()

# `update` has to run with nothing but this file on disk. A first run is exactly the case
# where VaultKit\ is not there yet, and a bootstrap that needs eight files fetched by
# hand to reach the command that fetches files is not a bootstrap. version and help are
# answerable without the module too, so they load nothing either.
# ----------------------------------------------------------------------------------
# VaultKit, folded in at build time by build.sh. DO NOT EDIT THIS FILE.
# Edit src/vault.ps1 or VaultKit/<part>.ps1 and run ./build.sh.
# ----------------------------------------------------------------------------------

# ===== VaultKit/Log.ps1 =====

# Logging. Console and file, one level vocabulary across every command.
#
# Every write here is -WhatIf:$false on purpose. -WhatIf means "do not write to Vault";
# the log and the reports are how an operator sees what a dry run WOULD do, so
# suppressing them defeats the point. Add-Content honours -WhatIf, and the previous
# generation of these tools silently produced no log at all under -WhatIf because of it.

$script:VaultLogFile = ''

function Start-VaultLog {
    param([Parameter(Mandatory)][string]$Directory, [Parameter(Mandatory)][string]$Name)
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force -WhatIf:$false | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:VaultLogFile = Join-Path $Directory "$Name-$stamp.log"
    return $script:VaultLogFile
}

function Write-VaultLog {
    param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Message,
        # Position 1 matters: every call site passes the level positionally, as
        # Write-VaultLog "..." 'WARN'. Giving Message an explicit position and not Level
        # makes Level named-only, and every one of those calls fails at runtime with
        # "A positional parameter cannot be found that accepts argument 'WARN'".
        [Parameter(Position = 1)][ValidateSet('INFO', 'OK', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line }
    }
    if ($script:VaultLogFile) {
        try { Add-Content -LiteralPath $script:VaultLogFile -Value $line -Encoding UTF8 -WhatIf:$false }
        catch { }
    }
}

function Get-VaultField {
    # Strict-mode-safe property read. Set-StrictMode turns a missing property into a
    # terminating error, which has twice killed a run inside a log line - reading
    # $response.vaultId purely to print it, after the call had already succeeded.
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

function Format-VaultBytes {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}

# ===== VaultKit/Config.ps1 =====

# One config file, read once.
#
# Sectioned, unlike the flat inis it replaces. That is not decoration: the attachment
# sync wanted Mode = REPORT|SYNC and the validator wanted FAST|DEEP, and sharing one flat
# file meant whichever ran second was misconfigured. Sections give each command its own
# namespace and let the vaults be declared once.
#
#   [vault]
#   source = your-source-vault.veevavault.com
#   target = your-target-vault.veevavault.com
#   api    = v26.2
#
#   [paths]
#   output = C:\Users\you\vault-work
#
#   [attachments]
#   map = attachments-map.csv

function Import-VaultConfig {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "Config not found: $Path" }

    $cfg     = @{}
    $section = 'general'
    $cfg[$section] = @{}

    foreach ($raw in (Get-Content -LiteralPath $Path)) {
        $line = "$raw".Trim().TrimStart([char]0xFEFF)
        if (-not $line -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }

        if ($line.StartsWith('[') -and $line.EndsWith(']')) {
            $section = $line.Trim('[', ']').Trim().ToLowerInvariant()
            if (-not $cfg.ContainsKey($section)) { $cfg[$section] = @{} }
            continue
        }

        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $line.Substring(0, $eq).Trim().ToLowerInvariant()
        $val = $line.Substring($eq + 1).Trim()

        # An inline comment is whitespace then # or ; - but only outside quotes, so a
        # value like "C:\x # y" survives if it is quoted.
        if ($val -notmatch '^["'']') { $val = ($val -split '\s+[#;]', 2)[0].TrimEnd() }
        $val = $val.Trim('"', "'")
        $cfg[$section][$key] = [Environment]::ExpandEnvironmentVariables($val)
    }
    return $cfg
}

function Get-VaultSetting {
    # Read one setting, with the default applied when the key is absent OR blank. Blank
    # has to count as absent: an operator clearing a value expects the default back, not
    # an empty string threaded into a path.
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        $Default = ''
    )
    $s = $Section.ToLowerInvariant()
    $k = $Key.ToLowerInvariant()
    if (-not $Config.ContainsKey($s)) { return $Default }
    if (-not $Config[$s].ContainsKey($k)) { return $Default }
    $v = $Config[$s][$k]
    if ($null -eq $v -or ($v -is [string] -and [string]::IsNullOrWhiteSpace($v))) { return $Default }
    return $v
}

function Get-VaultRequired {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$ConfigPath
    )
    $v = Get-VaultSetting -Config $Config -Section $Section -Key $Key
    if (-not $v) { throw "[$Section] $Key is not set in $ConfigPath" }
    return $v
}

function Set-VaultSetting {
    # Write ONE key back into the ini, leaving everything else exactly as it was.
    #
    # Line surgery rather than re-serialising the parsed config: vault.ini is mostly
    # comments explaining why each setting is what it is, and a writer that round-tripped
    # through the hashtable would hand back a correct file with all of that deleted.
    # `update` deliberately never overwrites this file; neither does this.
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    $lines = @(Get-Content -LiteralPath $Path)
    $sec   = $Section.ToLowerInvariant()
    # $keyLc, not $key: PowerShell variable names are case-insensitive, so assigning to
    # $key overwrites the $Key parameter - and the lines written below quote $Key.
    $keyLc = $Key.ToLowerInvariant()

    # Where the section starts, and where it ends - the next header, or the end.
    $start = -1; $end = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = "$($lines[$i])".Trim().TrimStart([char]0xFEFF)
        if ($t.StartsWith('[') -and $t.EndsWith(']')) {
            $name = $t.Trim('[', ']').Trim().ToLowerInvariant()
            if ($start -lt 0) { if ($name -eq $sec) { $start = $i } }
            else              { $end = $i; break }
        }
    }

    $out = New-Object System.Collections.ArrayList
    if ($start -lt 0) {
        # No such section: append it rather than guessing where it belongs.
        foreach ($l in $lines) { [void]$out.Add($l) }
        [void]$out.Add('')
        [void]$out.Add("[$Section]")
        [void]$out.Add("$Key = $Value")
    }
    else {
        $hit = -1
        for ($i = $start + 1; $i -lt $end; $i++) {
            $t = "$($lines[$i])".Trim()
            if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';')) { continue }
            $eq = $t.IndexOf('=')
            if ($eq -lt 1) { continue }
            if ($t.Substring(0, $eq).Trim().ToLowerInvariant() -eq $keyLc) { $hit = $i; break }
        }
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($hit -ge 0 -and $i -eq $hit) { [void]$out.Add("$Key = $Value"); continue }
            [void]$out.Add($lines[$i])
            # Key absent from an existing section: put it directly under the header,
            # where the comments above it still apply to it.
            if ($hit -lt 0 -and $i -eq $start) { [void]$out.Add("$Key = $Value") }
        }
    }

    [IO.File]::WriteAllLines($Path, $out, (New-Object Text.UTF8Encoding $false))
}

function Get-VaultHostName {
    # Accepts a full URL or a bare host and returns the host. Operators paste what is in
    # the address bar, which includes the scheme and a path.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $h = $Value -replace '^https?://', ''
    $h = ($h -split '/')[0]
    return $h.Trim().TrimEnd('/')
}

# ===== VaultKit/Auth.ps1 =====

# Authentication, as a flow of its own.
#
# `vault login` owns credentials. Every other command reads the session file and never
# prompts - unless the file is missing or has no entry for the host it needs, in which
# case it prompts itself, so a first run works without knowing `login` exists.
#
# The file is keyed by VAULT HOST, not a single flat value. The same account has a
# different user id in each vault - and staging paths are built from that id - so a lone
# session id could not say which vault it belonged to. That is exactly why the previous
# login.bat was unusable by anything that talked to two vaults.
#
# Stored as plain JSON. A session id is a bearer token: anyone holding it acts as that
# user until it expires. The file is ACL'd to the current user where Windows allows it,
# but it is not encrypted - treat it like a password, and `vault logout` when done.
#
# Credentials are held per host too, for the same reason. A prod vault and the vault it
# is being migrated into are commonly two separate accounts with two separate passwords,
# so one credential slot shared across both hosts meant the second vault was
# authenticated with the first vault's password - which surfaces as a login failure
# against a vault whose password you know is right.

$script:VaultSessions   = $null
$script:VaultSessionPath = ''
$script:VaultCredentials = @{}    # per host, in memory only, for silent re-auth mid-run

# Workers share one session file with the supervisor that launched them. They read it
# happily; they must not write it, because several processes rewriting one JSON file the
# moment their sessions expire is how a torn file gets written and every worker then
# fails to parse it.
$script:VaultSessionPersist = $true

function Get-VaultSessionPath {
    if ($script:VaultSessionPath) { return $script:VaultSessionPath }
    $here = $PSScriptRoot
    if ($here) { $here = Split-Path -Parent $here } else { $here = (Get-Location).ProviderPath }
    $script:VaultSessionPath = Join-Path $here '.vault-session.json'
    return $script:VaultSessionPath
}

function Read-VaultSessions {
    $path = Get-VaultSessionPath
    if ($script:VaultSessions) { return $script:VaultSessions }
    $script:VaultSessions = @{}
    if (Test-Path -LiteralPath $path) {
        try {
            $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            foreach ($p in $json.PSObject.Properties) {
                $script:VaultSessions[$p.Name] = $p.Value
            }
        }
        catch { Write-VaultLog "Session file unreadable, ignoring it: $_" 'WARN' }
    }
    return $script:VaultSessions
}

function Set-VaultSessionPersist {
    param([bool]$Value)
    $script:VaultSessionPersist = $Value
}

function Write-VaultSessions {
    if (-not $script:VaultSessionPersist) { return }
    $path = Get-VaultSessionPath
    $obj  = [ordered]@{}
    foreach ($k in ($script:VaultSessions.Keys | Sort-Object)) { $obj[$k] = $script:VaultSessions[$k] }
    ($obj | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $path -Encoding UTF8 -WhatIf:$false

    # Restrict to the current user. Windows only; on anything else this is a no-op and
    # the file simply inherits the directory's permissions.
    try {
        $acl = Get-Acl -LiteralPath $path
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($r in @($acl.Access)) { [void]$acl.RemoveAccessRule($r) }
        $me   = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $path -AclObject $acl
    }
    catch { }
}

$script:VaultNoPrompt = $false

function Set-VaultNoPrompt {
    param([bool]$Value)
    $script:VaultNoPrompt = $Value
}

function Test-VaultCanPrompt {
    # Is there a person here who can answer a question?
    #
    # One function rather than the same four lines in every prompting site, because they
    # had already started to drift and because a prompt is only as good as the check that
    # decides whether to show it. -NoPrompt says no outright; otherwise a redirected stdin
    # means a scheduled run, a pipeline or an SSH command, where Read-Host does not fail -
    # it blocks for ever on an answer nobody is there to give.
    #
    # It is also the seam the tests need: the interactive branches are the whole point of
    # these prompts, and they cannot be reached at all from a test host without one
    # function to stand in for.
    if ($script:VaultNoPrompt) { return $false }
    try { if ([Console]::IsInputRedirected) { return $false } } catch { }
    return $true
}

function Get-VaultCredential {
    # The credential for one vault. Cached per host, so a long run re-authenticates
    # silently against the right vault and a shared account is still only typed once.
    #
    # Refuse to prompt where nobody can answer. Get-Credential blocks indefinitely when
    # stdin is redirected - a scheduled run, a pipeline, anything non-interactive - so a
    # command with no cached session hangs for ever instead of failing. Fail loudly
    # instead, naming the fix.
    param([Parameter(Mandatory)][string]$VaultHost, [string]$Message = '')
    if ($script:VaultCredentials.ContainsKey($VaultHost)) { return $script:VaultCredentials[$VaultHost] }

    if (-not (Test-VaultCanPrompt)) {
        throw "No cached session for $VaultHost and no way to ask for credentials here. Run 'vault login' from a console first."
    }

    if (-not $Message) { $Message = "Vault credentials for $VaultHost" }
    $cred = Get-Credential -Message $Message
    if (-not $cred) { throw "No credentials given for $VaultHost." }
    $script:VaultCredentials[$VaultHost] = $cred
    return $cred
}

function Set-VaultCredential {
    # Register one credential against a host without prompting. `vault login -Shared`
    # uses this to reuse a single answer across every vault when the same account really
    # does exist on both sides.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][pscredential]$Credential)
    $script:VaultCredentials[$VaultHost] = $Credential
}

function Clear-VaultCredentials {
    $script:VaultCredentials = @{}
}

function Export-VaultCredentials {
    # Hand the workers what they need to re-authenticate, without a password ever
    # appearing on a command line, in the environment, or in a process listing.
    #
    # Export-CliXml keeps each SecureString DPAPI-protected for the current user on
    # Windows, so the file is useless to anyone else on the machine and useless on any
    # other machine. It still must not outlive the run - the caller deletes it in a
    # finally block, so a Ctrl-C does not leave it behind.
    param([Parameter(Mandatory)][string]$Path)
    $bag = @{}
    foreach ($h in $script:VaultCredentials.Keys) { $bag[$h] = $script:VaultCredentials[$h] }
    $bag | Export-Clixml -LiteralPath $Path -WhatIf:$false
    return $bag.Count
}

function Import-VaultCredentials {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    $bag = Import-Clixml -LiteralPath $Path
    $n = 0
    foreach ($h in $bag.Keys) { $script:VaultCredentials[$h] = $bag[$h]; $n++ }
    return $n
}

function Connect-VaultHost {
    # Authenticate one vault and record the session. Every field is read defensively:
    # under Set-StrictMode a missing property is a terminating error, and reaching
    # straight for $r.vaultId to print it has killed a run AFTER the login succeeded -
    # which also hid the response that would have explained why the field was absent.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [pscredential]$Credential
    )
    if (-not $Credential) { $Credential = Get-VaultCredential -VaultHost $VaultHost }

    # Remember it against this host, so Reset-VaultSession can re-authenticate mid-run
    # with the password that actually worked here rather than whichever was typed first.
    Set-VaultCredential -VaultHost $VaultHost -Credential $Credential

    $body = @{ username = $Credential.UserName; password = $Credential.GetNetworkCredential().Password }
    $r = Invoke-RestMethod -Method Post -Uri "https://$VaultHost/api/$ApiVersion/auth" `
            -Body $body -ContentType 'application/x-www-form-urlencoded' `
            -Headers @{ Accept = 'application/json' }

    if ((Get-VaultField $r 'responseStatus') -ne 'SUCCESS') {
        # Vault's own words, not the whole JSON body. A failed login is the most common
        # error there is and the least deserving of a stack trace over a raw response.
        $errs  = @(Get-VaultField $r 'errors' @())
        $types = @($errs | ForEach-Object { "$(Get-VaultField $_ 'type' '')" })
        $msg   = (($errs | ForEach-Object { "$(Get-VaultField $_ 'message' '')" }) -join '; ')
        if (-not $msg) { $msg = "$(Get-VaultField $r 'responseMessage' 'no detail given')" }

        if ($types -contains 'USERNAME_OR_PASSWORD_INCORRECT') {
            $msg += [Environment]::NewLine +
                    '    Sign in to that vault in a browser as the same user to check the password.' + [Environment]::NewLine +
                    '    If that account uses SSO it has no Vault password, and API login cannot work' + [Environment]::NewLine +
                    '    for it at all - it needs a Vault-local password or a different account.' + [Environment]::NewLine +
                    '    Vault locks an account after repeated failures, so do not simply retry.'
        }
        throw "Authentication failed for $VaultHost as $($Credential.UserName): $msg"
    }
    $sid = "$(Get-VaultField $r 'sessionId' '')"
    if (-not $sid) {
        throw "Authentication for $VaultHost returned no sessionId. Vault said: $($r | ConvertTo-Json -Depth 5 -Compress)"
    }

    $sessions = Read-VaultSessions
    $sessions[$VaultHost] = [pscustomobject]@{
        sessionId = $sid
        userId    = "$(Get-VaultField $r 'userId' '')"
        vaultId   = "$(Get-VaultField $r 'vaultId' '')"
        api       = $ApiVersion
        obtained  = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    }
    Write-VaultSessions
    Write-VaultLog "$VaultHost - authenticated (vaultId $(Get-VaultField $r 'vaultId' '?'), userId $(Get-VaultField $r 'userId' '?'))" 'OK'
    return $sessions[$VaultHost]
}

function Get-VaultSessionId {
    # The session for one host, from the cache. Missing means prompt and log in, so any
    # command works on a machine that has never run `vault login`.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [switch]$NoPrompt
    )
    $sessions = Read-VaultSessions
    if ($sessions.ContainsKey($VaultHost)) {
        $sid = "$(Get-VaultField $sessions[$VaultHost] 'sessionId' '')"
        if ($sid) { return $sid }
    }
    if ($NoPrompt) { throw "No cached session for $VaultHost. Run: vault login" }
    Write-VaultLog "No cached session for $VaultHost - logging in" 'WARN'
    $entry = Connect-VaultHost -VaultHost $VaultHost -ApiVersion $ApiVersion
    return "$(Get-VaultField $entry 'sessionId' '')"
}

function Reset-VaultSession {
    # Called when Vault rejects a session mid-run. Re-authenticates from the credential
    # held in memory, so a long job outlives its session without stopping. With no
    # credential in memory - a session pasted into the config, say - this prompts once.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion)
    Write-VaultLog "$VaultHost - session expired, re-authenticating" 'WARN'
    $entry = Connect-VaultHost -VaultHost $VaultHost -ApiVersion $ApiVersion
    return "$(Get-VaultField $entry 'sessionId' '')"
}

function Clear-VaultSessions {
    $path = Get-VaultSessionPath
    $script:VaultSessions = @{}
    Clear-VaultCredentials
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -WhatIf:$false
        return $true
    }
    return $false
}

# --------------------------------------------------------------------------------------
# Pre-flight
#
# Every workflow talks to two vaults, and finding out which credential was wrong two
# hours into a transfer is the failure this exists to prevent. Both sides are established
# and shown BEFORE any work starts.
# --------------------------------------------------------------------------------------

function Get-VaultWhoAmI {
    # Who the cached session actually belongs to, proven by using it. A session id that
    # parses is not a session that works, and the only way to tell them apart is a call.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion)
    try {
        $me = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path '/objects/users/me' -MaxRetries 1
        $u  = Get-VaultField (@(Get-VaultField $me 'users' @()) | Select-Object -First 1) 'user' $null
        $sessions = Read-VaultSessions
        $entry = $null
        if ($sessions.ContainsKey($VaultHost)) { $entry = $sessions[$VaultHost] }
        return [pscustomobject]@{
            User    = "$(Get-VaultField $u 'user_name__v' '')"
            UserId  = "$(Get-VaultField $u 'id' '')"
            VaultId = "$(Get-VaultField $entry 'vaultId' '?')"
        }
    }
    catch { return $null }
}

function Confirm-VaultSessions {
    # Establish and confirm a session for every vault the command needs, up front.
    #
    # Opportunistic: a cached session that still answers is reused, so a second command
    # in the same hour asks for nothing. Only what is missing or expired is prompted for,
    # and each vault is prompted for separately - the source is a production vault and
    # the target is somebody else's, and they are not the same account.
    param(
        [Parameter(Mandatory)][array]$Vaults,      # @{ Role = 'source'; Name = 'host' }
        [Parameter(Mandatory)][string]$ApiVersion,
        [switch]$Yes
    )
    $rows = @()
    foreach ($v in $Vaults) {
        $who = $null
        $sessions = Read-VaultSessions
        if ($sessions.ContainsKey($v.Name)) {
            $who = Get-VaultWhoAmI -VaultHost $v.Name -ApiVersion $ApiVersion
            if ($who) { Write-VaultLog "$($v.Role) vault $($v.Name) - cached session still valid" }
            else      { Write-VaultLog "$($v.Role) vault $($v.Name) - cached session no longer works, logging in again" 'WARN' }
        }
        if (-not $who) {
            Write-VaultLog "$($v.Role) vault $($v.Name) - credentials needed"
            [void](Connect-VaultHost -VaultHost $v.Name -ApiVersion $ApiVersion)
            $who = Get-VaultWhoAmI -VaultHost $v.Name -ApiVersion $ApiVersion
        }
        if (-not $who) { throw "Could not establish a working session for $($v.Name)." }
        $rows += [pscustomobject]@{
            Role = $v.Role; VaultHost = $v.Name
            User = $who.User; UserId = $who.UserId; VaultId = $who.VaultId
        }
    }

    Write-VaultLog '----------------------------------------------------------------'
    foreach ($r in $rows) {
        Write-VaultLog ("  {0,-6}  {1}" -f $r.Role, $r.VaultHost) 'OK'
        Write-VaultLog ("          {0}  userId {1}  vaultId {2}" -f $r.User, $r.UserId, $r.VaultId)
    }
    Write-VaultLog '----------------------------------------------------------------'

    if ($Yes) { return $rows }

    # A console can answer; a scheduled run cannot, and blocking it for ever waiting on
    # an answer nobody is there to give would be worse than proceeding.
    $canAsk = Test-VaultCanPrompt
    if (-not $canAsk) {
        Write-VaultLog 'Not a console - proceeding without confirmation.' 'WARN'
        return $rows
    }

    # Ask about what was actually shown. This said "the right two vaults" however many it
    # had listed, so a roles command - which reads one vault and lists one - asked about
    # two. A confirmation that disagrees with the screen above it is one people learn to
    # answer without reading, which is the opposite of what it is for.
    $question = switch ($rows.Count) {
        1       { "Is this the right vault? [y/N]" }
        2       { "Are these the right two vaults? [y/N]" }
        default { "Are these the right $($rows.Count) vaults? [y/N]" }
    }
    $answer = Read-Host $question
    if ($answer -notmatch '^[Yy]') { throw 'Stopped: the vaults were not confirmed.' }
    return $rows
}

# ===== VaultKit/Http.ps1 =====

# One HTTP layer for every command.
#
# Written once here because it had been written three times before, and the copies had
# drifted: one still caught only System.Net.WebException, which is a .NET Framework type,
# so on PowerShell 7 it had no retry and no 429 handling at all.

# What Vault last said was left of the burst allowance, per host. Kept because the
# decision "should this run use more workers" is answerable from it and guesswork
# otherwise: the documented limit is 2,000 calls per five minutes per user, and a run
# that never drops below a few hundred remaining has headroom while one that keeps
# bottoming out is already being throttled and would only thrash with more workers.
$script:VaultBurstRemaining = @{}
$script:VaultBurstLowest    = @{}

function Get-VaultBurstReport {
    # A line per vault, or nothing if no response ever carried the header.
    $out = New-Object System.Collections.ArrayList
    foreach ($h in ($script:VaultBurstRemaining.Keys | Sort-Object)) {
        [void]$out.Add(('{0}  burst remaining {1}, lowest seen {2} of 2000 per 5 min' -f `
                        $h, $script:VaultBurstRemaining[$h], $script:VaultBurstLowest[$h]))
    }
    return @($out)
}

function Register-VaultBurstLimit {
    # Record what a response said was left of the allowance, and ease off if it is low.
    #
    # A function rather than a few lines inside Invoke-VaultApi, because not every call
    # goes through Invoke-VaultApi: the attachment upload builds its own HttpWebRequest
    # so a 2GB body can stream from disk, and while it recorded nothing the end-of-run
    # "lowest seen" was blind to the calls the workers spend their time in - so the one
    # number that answers "should this run use more workers" was reading only the cheap
    # listing calls beside them.
    #
    # The value arrives as whatever the response type hands back: a string from
    # WebHeaderCollection on 5.1, a single-element string[] from Invoke-WebRequest on 7.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [AllowNull()][AllowEmptyString()]$HeaderValue
    )
    if ($null -eq $HeaderValue) { return }
    $val = "$(@($HeaderValue)[0])".Trim()
    if ($val -notmatch '^\d+$') { return }
    $n = [int]$val

    $script:VaultBurstRemaining[$VaultHost] = $n
    if (-not $script:VaultBurstLowest.ContainsKey($VaultHost) -or
        $n -lt $script:VaultBurstLowest[$VaultHost]) {
        $script:VaultBurstLowest[$VaultHost] = $n
    }

    # Eased off from 400 rather than stopped dead at 200: the allowance is 2,000 every
    # five minutes, and a run that keeps reaching the floor is one already being delayed
    # 500ms a call by Vault - which looks like slowness, not like throttling, and is the
    # failure this is meant to stay ahead of.
    if ($n -lt 400) {
        $wait = Get-VaultThrottleDelay -Kind 'burst' -Remaining $n
        Write-VaultLog "$VaultHost burst allowance low ($n of 2000) - easing off ${wait}s" 'WARN'
        Start-Sleep -Seconds $wait
    }
}

# --------------------------------------------------------------------------------------
# Backing off without thrashing
#
# Eight workers that all pause for exactly sixty seconds resume in the same instant and
# hit the vault together, which is the behaviour that turns "throttled" into "thrashing".
# Every wait here is therefore jittered: the point is not the length of the pause, it is
# that the workers stop agreeing on when it ends.
# --------------------------------------------------------------------------------------

$script:VaultJitter = New-Object System.Random

function Get-VaultThrottleDelay {
    # Seconds to wait, jittered. Returns a whole number so it can be logged plainly.
    param(
        [Parameter(Mandatory)][ValidateSet('burst', 'throttled', 'transient')][string]$Kind,
        [int]$Attempt = 1,
        [int]$Remaining = -1,
        [int]$RetryAfter = 0,
        [int]$Cap = 120
    )
    # Vault said how long: that is an instruction, not an opinion. Jitter still applies,
    # because the workers must not resume together - but upward only. Waiting LESS than
    # you were told is the one direction that cannot help.
    if ($RetryAfter -gt 0) {
        $up = [int][math]::Ceiling($RetryAfter * (1.0 + $script:VaultJitter.NextDouble() * 0.5))
        return [math]::Min([math]::Max($up, $RetryAfter), [math]::Max($Cap, $RetryAfter))
    }

    $base =
        if ($false) { 0 }
        else {
            switch ($Kind) {
                'burst' {
                    # Proportional to how little is left, not a cliff at one value. The
                    # allowance is 2,000 per five minutes; easing off from 400 remaining
                    # keeps a run away from the floor instead of pausing hard once it is
                    # already there.
                    $r = if ($Remaining -lt 0) { 0 } else { [math]::Min(400, $Remaining) }
                    [math]::Max(3, [int](3 + (400 - $r) / 400.0 * 45))
                }
                'throttled' { 60 }
                default     { [math]::Min($Cap, [int]([math]::Pow(2, $Attempt) * 5)) }
            }
        }
    if ($base -gt $Cap) { $base = $Cap }

    # Half to one and a half times the base. Not full jitter down to zero: a wait of
    # nothing is not a wait, and the reason for pausing has not gone away.
    $factor = 0.5 + $script:VaultJitter.NextDouble()
    $delay  = [int][math]::Round($base * $factor)
    if ($delay -lt 1) { $delay = 1 }
    return $delay
}

function Get-VaultRetryAfter {
    # Vault's own answer, when it gives one.
    param($Response)
    try {
        $v = $Response.Headers['Retry-After']
        if ($v -and ($v -match '^\d+$')) { return [int]$v }
    } catch { }
    return 0
}

function Invoke-VaultApi {
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body,
        [string]$ContentType,
        [hashtable]$ExtraHeaders = @{},
        [int]$TimeoutSec = 900,
        [int]$MaxRetries = 4
    )

    # Three shapes of Path arrive here and they are not interchangeable:
    #   https://...       a full URL, which File Staging pagination returns
    #   /api/v26.2/query  host-relative and ALREADY carrying the api prefix, which VQL
    #                     next_page returns - prefixing again gives /api/v26.2/api/v26.2
    #   /objects/...      our own calls, relative to the versioned base
    $uri =
        if     ($Path -match '^https?://') { $Path }
        elseif ($Path -match '^/api/')     { "https://$VaultHost$Path" }
        else                               { "https://$VaultHost/api/$ApiVersion$Path" }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sid = Get-VaultSessionId -VaultHost $VaultHost -ApiVersion $ApiVersion
        $headers = @{ Authorization = $sid; Accept = 'application/json' }
        foreach ($k in $ExtraHeaders.Keys) { $headers[$k] = $ExtraHeaders[$k] }

        try {
            $req = @{ Method = $Method; Uri = $uri; Headers = $headers
                      TimeoutSec = $TimeoutSec; UseBasicParsing = $true }
            if ($null -ne $Body) { $req['Body'] = $Body }
            if ($ContentType)    { $req['ContentType'] = $ContentType }

            $resp = Invoke-WebRequest @req

            Register-VaultBurstLimit -VaultHost $VaultHost `
                -HeaderValue $resp.Headers['X-VaultAPI-BurstLimitRemaining']

            $json = $null
            if ($resp.Content) { try { $json = $resp.Content | ConvertFrom-Json } catch { } }
            if ($null -eq $json) { return [pscustomobject]@{ responseStatus = 'SUCCESS'; raw = $resp.Content } }

            if ((Get-VaultField $json 'responseStatus') -eq 'FAILURE') {
                $errs  = @(Get-VaultField $json 'errors' @())
                $types = @($errs | ForEach-Object { Get-VaultField $_ 'type' })
                if ($types -contains 'INVALID_SESSION_ID') {
                    [void](Reset-VaultSession -VaultHost $VaultHost -ApiVersion $ApiVersion)
                    continue
                }
                throw "$VaultHost $Method $Path -- " +
                      (($errs | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join '; ')
            }
            return $json
        }
        catch {
            # 5.1 raises WebException; 7 raises HttpResponseException for a status and
            # HttpRequestException for a transport failure. Matching on the type NAME
            # covers all three without needing System.Net.Http loadable on 5.1. Anything
            # else is a bug in this code and is rethrown rather than retried four times.
            $ex   = $_.Exception
            $name = $ex.GetType().Name
            if ($name -notin @('WebException', 'HttpResponseException', 'HttpRequestException')) { throw }

            $status = $null
            try { if ($ex.Response) { $status = [int]$ex.Response.StatusCode } } catch { }

            if ($status -eq 401 -and $attempt -lt $MaxRetries) {
                # A raw 401 carries no JSON body, so the INVALID_SESSION_ID handling
                # above never sees it - that only fires when Vault answers 200 with a
                # FAILURE payload. Without this a session expiring mid-run fails every
                # remaining call instead of renewing once.
                Write-VaultLog "$VaultHost HTTP 401 - renewing the session" 'WARN'
                [void](Reset-VaultSession -VaultHost $VaultHost -ApiVersion $ApiVersion)
                continue
            }
            if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                $wait = Get-VaultThrottleDelay -Kind 'throttled' -Attempt $attempt -RetryAfter (Get-VaultRetryAfter $ex.Response)
                Write-VaultLog "$VaultHost HTTP 429 - waiting ${wait}s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = Get-VaultThrottleDelay -Kind 'transient' -Attempt $attempt -RetryAfter (Get-VaultRetryAfter $ex.Response)
                Write-VaultLog "$VaultHost transient error on $Method $Path (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            $detail = ''
            try { $detail = "$($_.ErrorDetails.Message)" } catch { }
            if (-not $detail) {
                try { $detail = (New-Object IO.StreamReader($ex.Response.GetResponseStream())).ReadToEnd() } catch { }
            }
            throw "$VaultHost $Method $Path failed (HTTP $status): $($ex.Message) $detail"
        }
    }
    throw "$VaultHost $Method $Path failed after $MaxRetries attempts"
}

function Invoke-VaultQuery {
    # One VQL query, all its pages, as rows.
    #
    # Page 1 is a POST carrying the query; every page after it is a GET on the URL Vault
    # hands back, which already has the query baked in. That asymmetry has been written
    # out by hand in four places in this kit; this is the one that new code should use.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][string]$Vql,
        # A cap, not a limit: pages, not rows. Stops a mistyped query from paging a
        # 500,000-record object to the end, and says that it stopped.
        [int]$MaxPages = 50
    )
    $rows  = New-Object System.Collections.ArrayList
    $path  = '/query'
    $body  = "q=$([Uri]::EscapeDataString($Vql))"
    $pages = 0
    $truncated = $false
    while ($path) {
        $pages++
        if ($pages -gt $MaxPages) { $truncated = $true; break }
        $r = if ($pages -eq 1) {
                Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method POST `
                    -Path $path -ContentType 'application/x-www-form-urlencoded' -Body $body
             } else {
                Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path $path
             }
        foreach ($row in @(Get-VaultField $r 'data' @())) { [void]$rows.Add($row) }
        $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }
    if ($truncated) { Write-VaultLog "Stopped at the $MaxPages-page cap - this is NOT the whole result." 'WARN' }
    return @($rows)
}

function Get-VaultAttachmentName {
    # The filename out of a Content-Disposition header, decoded properly.
    #
    # Two traps, both of which produce a wrong name rather than an error:
    #
    # RFC 5987 puts the reliable value in filename*, percent-encoded and tagged with its
    # charset, and servers send a plain ASCII-mangled filename beside it for old clients.
    # A regex that takes whichever comes first takes the mangled one.
    #
    # .NET decodes header bytes as latin-1. A UTF-8 name therefore arrives as mojibake -
    # an e-acute comes back as two characters - and it is a valid string, so nothing
    # complains. Re-reading those bytes as UTF-8 recovers it; if that fails, the name was
    # genuinely latin-1 and is kept as it was.
    #
    # This file stays ASCII. Windows PowerShell 5.1 reads a .ps1 with no BOM as ANSI, so
    # a non-ASCII character here - even in a comment - is not the character that was
    # written.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Header)
    if (-not $Header) { return '' }

    if ($Header -match "filename\*\s*=\s*(?:UTF-8|utf-8)''([^;]+)") {
        try { return [Uri]::UnescapeDataString($Matches[1].Trim()) } catch { }
    }
    if ($Header -match 'filename\s*=\s*"?([^";]+)"?') {
        $raw = $Matches[1].Trim().Trim('"')
        try {
            $bytes = [Text.Encoding]::GetEncoding(28591).GetBytes($raw)   # latin-1, as .NET read it
            $utf8  = [Text.Encoding]::UTF8.GetString($bytes)
            if ($utf8 -and ($utf8 -notmatch [char]0xFFFD)) { return $utf8 }
        }
        catch { }
        return $raw
    }
    return ''
}

function Save-VaultFile {
    # Streamed to disk via HttpWebRequest. Invoke-WebRequest -OutFile buffers the whole
    # response on Windows PowerShell 5.1, which a 2GB attachment would not survive.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Destination,
        [string]$FileName
    )
    $sid = Get-VaultSessionId -VaultHost $VaultHost -ApiVersion $ApiVersion
    $uri = if ($Path -match '^https?://') { $Path } else { "https://$VaultHost/api/$ApiVersion$Path" }

    $req = [Net.HttpWebRequest]::Create($uri)
    $req.Method           = 'GET'
    $req.Timeout          = 900000
    $req.ReadWriteTimeout = 900000
    $req.Headers.Add('Authorization', $sid)

    $resp = $req.GetResponse()
    try {
        $name = $FileName
        if (-not $name) { $name = Get-VaultAttachmentName -Header "$($resp.Headers['Content-Disposition'])" }
        if (-not $name) { $name = 'download' }

        # Scrub for the local filesystem only. Whatever goes back OUT to Vault must use
        # the original name: uploading under a scrubbed name means the names stop
        # matching, so the next run judges the file missing and sends another copy.
        $safe = $name
        foreach ($bad in [IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace($bad, '_') }

        $out = Join-Path $Destination $safe
        $in  = $resp.GetResponseStream()
        $fs  = [IO.File]::Create($out)
        try {
            $buf = New-Object byte[] 1048576
            while (($read = $in.Read($buf, 0, $buf.Length)) -gt 0) { $fs.Write($buf, 0, $read) }
        }
        finally { $fs.Dispose(); $in.Dispose() }

        return [pscustomobject]@{
            Path         = $out
            Name         = $safe          # on disk
            OriginalName = $name          # on the wire
            Size         = (Get-Item -LiteralPath $out).Length
        }
    }
    finally { $resp.Dispose() }
}

# ===== VaultKit/Ids.ps1 =====

# Id lists and id maps.
#
# Every rule here was met in a real export, not imagined. A spreadsheet arrives as
# whatever produced it left it: a byte order mark, tabs instead of commas, two columns
# called "Created By", headers written for people rather than parsers, a row per file so
# one document appears eight times, and #N/A where a lookup found nothing.

function Resolve-VaultOutputPath {
    # An absolute path for something about to be written.
    #
    # [IO.File]::WriteAllLines and [IO.Path]::GetFullPath resolve a relative path against
    # the PROCESS working directory, and PowerShell's Set-Location does not move that.
    # So `cd C:\vault-work` followed by `-OutFile attachments-map.csv` wrote to
    # U:\attachments-map.csv - the drive the shell happened to start on - and where that
    # was not writable it failed with an access error naming a path nobody had typed.
    #
    # Reads already went through the provider location, in Resolve-VaultInput and
    # Import-VaultDelimitedFile. Writes did not. An absolute path passes through
    # unchanged, so this is safe to apply to anything.
    param([Parameter(Mandatory)][string]$Path)
    return [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path))
}

function Export-VaultIdMap {
    # Write the canonical map. One shape out, whatever went in.
    param(
        [Parameter(Mandatory)]$Map,
        [Parameter(Mandatory)][string]$Path
    )
    # Written by hand rather than with Export-Csv, which on Windows PowerShell 5.1 quotes
    # every field and emits a byte order mark - so the canonical file would have come out
    # as "source_id","target_id" with a BOM, which is not the shape the format document
    # says it is. Ids are digits and the headers are fixed, so nothing here needs quoting
    # or escaping, and a file anyone can read in Notepad and diff cleanly is worth more
    # than one that went through a cmdlet.
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('source_id,target_id')
    foreach ($k in ($Map.Keys | Sort-Object { [long]$_ })) {
        [void]$lines.Add(('{0},{1}' -f $k, $Map[$k]))
    }
    [IO.File]::WriteAllLines((Resolve-VaultOutputPath -Path $Path), $lines, (New-Object Text.UTF8Encoding $false))
    return ($lines.Count - 1)
}

function Import-VaultIdList {
    # One id per line. Tolerant because this file is usually pasted out of Excel or a
    # Library grid: a header, quotes, blank lines, #-comments, a trailing comma.
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$LegacyNames = @()
    )
    $resolved = Resolve-VaultInput -Path $Path -LegacyNames $LegacyNames
    if (-not $resolved) { throw "Id list not found: $Path" }

    $ids  = New-Object System.Collections.ArrayList
    $seen = @{}
    $skipped = New-Object System.Collections.ArrayList
    $dupes = 0
    $n = 0

    foreach ($raw in (Get-Content -LiteralPath $resolved)) {
        $n++
        $t = "$raw".Trim().Trim([char]0xFEFF).Trim('"', "'").TrimEnd(',').Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        if ($n -eq 1 -and $t -match '^(id|document.?id)$') { continue }
        if ($t -notmatch '^\d+$') { [void]$skipped.Add("line ${n}: '$t'"); continue }
        if ($seen.ContainsKey($t)) { $dupes++; continue }
        $seen[$t] = $true
        [void]$ids.Add($t)
    }

    if ($skipped.Count) {
        Write-VaultLog "$($skipped.Count) line(s) in $resolved are not ids and were skipped" 'WARN'
        foreach ($s in ($skipped | Select-Object -First 5)) { Write-VaultLog "  $s" 'WARN' }
        if ($skipped.Count -gt 5) { Write-VaultLog "  ... and $($skipped.Count - 5) more" 'WARN' }
    }
    if ($dupes) { Write-VaultLog "$dupes duplicate id(s) dropped" }
    if ($ids.Count -eq 0) { throw "No ids found in $resolved" }

    Write-VaultLog "$($ids.Count) id(s) from $resolved" 'OK'
    return @($ids)
}

function Resolve-VaultInput {
    # Working directory first - that is where an operator drops a file - then beside the
    # script, then any previous name for the same input. Returns $null if nothing is
    # found, and the absolute path otherwise, which is what gets logged: there is then
    # never a question of which file was read.
    param([Parameter(Mandatory)][string]$Path, [string[]]$LegacyNames = @())

    $tries = @($Path, [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)))
    if ($PSScriptRoot) { $tries += (Join-Path (Split-Path -Parent $PSScriptRoot) $Path) }
    foreach ($legacy in $LegacyNames) {
        $tries += [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $legacy))
    }
    foreach ($t in $tries) {
        if ($t -and (Test-Path -LiteralPath $t)) {
            $full = (Resolve-Path -LiteralPath $t).ProviderPath
            $leaf = Split-Path -Leaf $full
            if ($leaf -ne (Split-Path -Leaf $Path)) {
                Write-VaultLog "Using $leaf - rename it to $(Split-Path -Leaf $Path) when convenient" 'WARN'
            }
            return $full
        }
    }
    return $null
}

function Import-VaultDelimitedFile {
    # Read a spreadsheet export into rows, whatever shape it arrived in. Returns the rows
    # and the column names actually used, since a duplicate header gets suffixed.
    param([Parameter(Mandatory)][string]$Path)

    $resolved = $null
    foreach ($t in @($Path, [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)))) {
        if ($t -and (Test-Path -LiteralPath $t)) { $resolved = (Resolve-Path -LiteralPath $t).ProviderPath; break }
    }
    if (-not $resolved) {
        throw ("Not found. Looked for:`n    {0}" -f
               [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)))
    }

    # Excel's "CSV UTF-8" writes a byte order mark, which Windows PowerShell 5.1 reads as
    # literal characters glued to the first column name - so source_id arrives as
    # something no name match would ever find.
    $bom = $false
    try {
        $head3 = New-Object byte[] 3
        $fsb = [IO.File]::OpenRead($resolved)
        try { [void]$fsb.Read($head3, 0, 3) } finally { $fsb.Dispose() }
        if ($head3[0] -eq 0xEF -and $head3[1] -eq 0xBB -and $head3[2] -eq 0xBF) { $bom = $true }
    } catch { }

    $header = @(Get-Content -LiteralPath $resolved -TotalCount 1)
    if (-not $header.Count) { throw "$resolved is empty" }
    $header[0] = $header[0].TrimStart([char]0xFEFF)

    # The delimiter is not implied by the extension. A tab-separated export read as
    # comma-separated yields one column and a confusing "cannot work out which columns"
    # error rather than an obvious one.
    $delims = @{ ',' = ([regex]::Matches($header[0], ',')).Count
                 "`t" = ([regex]::Matches($header[0], "`t")).Count
                 ';' = ([regex]::Matches($header[0], ';')).Count
                 '|' = ([regex]::Matches($header[0], '\|')).Count }
    $delim = ','; $best = 0
    foreach ($d in $delims.Keys) { if ($delims[$d] -gt $best) { $best = $delims[$d]; $delim = $d } }
    if ($best -eq 0) { throw "$resolved has no delimiter in its header: '$($header[0])'. It needs at least two columns." }

    # Import-Csv refuses a sheet with a repeated header - "The member 'Created By' is
    # already present" - and a real export usually has one. Only a couple of columns
    # matter, so a duplicate elsewhere must not stop the job.
    $all = if ($bom) { @(Get-Content -LiteralPath $resolved -Encoding UTF8) }
           else      { @(Get-Content -LiteralPath $resolved) }
    if ($all.Count -lt 2) { throw "$resolved has a header but no rows" }

    $names = New-Object System.Collections.ArrayList
    $used  = @{}
    $renamed = 0
    foreach ($raw in ($header[0] -split [regex]::Escape($delim))) {
        $nm = $raw.Trim().Trim('"')
        if (-not $nm) { $nm = 'Column' }
        $base = $nm; $k = 2
        while ($used.ContainsKey($nm.ToLowerInvariant())) { $nm = "${base}_$k"; $k++; $renamed++ }
        $used[$nm.ToLowerInvariant()] = $true
        [void]$names.Add($nm)
    }
    if ($renamed) { Write-VaultLog "$renamed duplicate column name(s) in $(Split-Path -Leaf $resolved) suffixed to keep them apart" }

    $rows = @($all | Select-Object -Skip 1 | ConvertFrom-Csv -Header $names -Delimiter $delim)
    if ($rows.Count -eq 0) { throw "$resolved has a header but no rows" }

    $shown = if ($delim -eq "`t") { 'tab' } else { $delim }
    return [pscustomobject]@{ Path = $resolved; Rows = $rows; Names = @($names); Delimiter = $shown }
}

# What the last Import-VaultIdMap decided. A side channel rather than a changed return
# type, because several callers want the map and only `map check` wants the reasoning.
$script:VaultIdMapStats = @{}

# The canonical map. This is what the kit WRITES, and what it looks for before it starts
# guessing - two columns, named, comma separated, one pair per row:
#
#     source_id,target_id
#     55056,207311
#
# Anything else is still read, because a real map arrives as whatever Excel produced and
# refusing it would just move the work to a person. But a file in this shape needs no
# detection at all, and `map write` turns one into the other.
$script:VaultCanonicalSource = @('source_id', 'sourceid', 'source')
$script:VaultCanonicalTarget = @('target_id', 'targetid', 'target')

function Import-VaultIdMap {
    # source id -> target id, from a spreadsheet export.
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$SourceColumn = '',
        [string]$TargetColumn = '',
        [string[]]$LegacyNames = @()
    )
    $resolved = Resolve-VaultInput -Path $Path -LegacyNames $LegacyNames
    if (-not $resolved) {
        $where = @([IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)))
        throw ("Id map not found. Looked in:`n" + (($where | ForEach-Object { "    $_" }) -join "`n"))
    }

    # Excel's "CSV UTF-8" writes a byte order mark, which Windows PowerShell 5.1 reads as
    # literal characters glued to the first column name - so source_id arrives as
    # something no name match would ever find.
    $bom = $false
    try {
        $head3 = New-Object byte[] 3
        $fsb = [IO.File]::OpenRead($resolved)
        try { [void]$fsb.Read($head3, 0, 3) } finally { $fsb.Dispose() }
        if ($head3[0] -eq 0xEF -and $head3[1] -eq 0xBB -and $head3[2] -eq 0xBF) { $bom = $true }
    } catch { }

    $header = @(Get-Content -LiteralPath $resolved -TotalCount 1)
    if (-not $header.Count) { throw "Id map $resolved is empty" }
    $header[0] = $header[0].TrimStart([char]0xFEFF)

    # The delimiter is not implied by the extension. A tab-separated export read as
    # comma-separated yields one column and a confusing "cannot work out which columns"
    # error rather than an obvious one.
    $delims = @{ ',' = ([regex]::Matches($header[0], ',')).Count
                 "`t" = ([regex]::Matches($header[0], "`t")).Count
                 ';' = ([regex]::Matches($header[0], ';')).Count
                 '|' = ([regex]::Matches($header[0], '\|')).Count }
    $delim = ','; $best = 0
    foreach ($d in $delims.Keys) { if ($delims[$d] -gt $best) { $best = $delims[$d]; $delim = $d } }
    if ($best -eq 0) { throw "Id map $resolved has no delimiter in its header: '$($header[0])'. It needs at least two columns." }
    $shown = if ($delim -eq "`t") { 'tab' } else { $delim }

    # Import-Csv refuses a sheet with a repeated header - "The member 'Created By' is
    # already present" - and a real export usually has one. Only two columns matter, so a
    # duplicate elsewhere must not stop the job.
    $all = if ($bom) { @(Get-Content -LiteralPath $resolved -Encoding UTF8) }
           else      { @(Get-Content -LiteralPath $resolved) }
    if ($all.Count -lt 2) { throw "Id map $resolved has a header but no rows" }

    $names = New-Object System.Collections.ArrayList
    $used  = @{}
    $renamed = 0
    foreach ($raw in ($header[0] -split [regex]::Escape($delim))) {
        $nm = $raw.Trim().Trim('"')
        if (-not $nm) { $nm = 'Column' }
        $base = $nm; $k = 2
        while ($used.ContainsKey($nm.ToLowerInvariant())) { $nm = "${base}_$k"; $k++; $renamed++ }
        $used[$nm.ToLowerInvariant()] = $true
        [void]$names.Add($nm)
    }
    if ($renamed) { Write-VaultLog "$renamed duplicate column name(s) suffixed to keep them apart" }

    $rows = @($all | Select-Object -Skip 1 | ConvertFrom-Csv -Header $names -Delimiter $delim)
    if ($rows.Count -eq 0) { throw "Id map $resolved has a header but no rows" }
    Write-VaultLog "Id map columns: $($names -join ', ')"

    # Match on what a header MEANS, not a list of exact spellings. Real headers are
    # written for people - "Source (old) Document ID" is perfectly clear and matches no
    # fixed name at all.
    function Test-IsIdColumn {
        param([string]$Header, [string[]]$Words)
        $n = ($Header -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
        if ($n -notmatch 'id$|id[^a-z]|^id') { return $false }
        foreach ($w in $Words) { if ($n -like "*$w*") { return $true } }
        return $false
    }

    $srcCol = $SourceColumn
    $tgtCol = $TargetColumn
    $how    = 'named on the command line'

    # The canonical names first, exactly. Detection is for files written for people;
    # a file written by this kit should not be guessed at - and the heuristic below
    # requires the header to contain "id", so a column called plainly "source" would
    # otherwise fail to be found at all.
    if (-not $srcCol -and -not $tgtCol) {
        $lower = @{}
        foreach ($n in $names) { $lower[($n -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()] = $n }
        foreach ($cand in $script:VaultCanonicalSource) { if ($lower.ContainsKey($cand)) { $srcCol = $lower[$cand]; break } }
        foreach ($cand in $script:VaultCanonicalTarget) { if ($lower.ContainsKey($cand)) { $tgtCol = $lower[$cand]; break } }
        if ($srcCol -and $tgtCol) { $how = 'canonical header' }
        else { $srcCol = ''; $tgtCol = '' }
    }
    if (-not $srcCol -and -not $tgtCol) { $how = 'detected from the header wording' }

    if (-not $srcCol) {
        $c = @($names | Where-Object { Test-IsIdColumn -Header $_ -Words @('source', 'old', 'from', 'legacy') })
        if ($c.Count -eq 1) { $srcCol = $c[0] }
        elseif ($c.Count -gt 1) { throw "More than one column could be the source id: $($c -join ', '). Name it explicitly." }
    }
    if (-not $tgtCol) {
        $c = @($names | Where-Object { Test-IsIdColumn -Header $_ -Words @('destination', 'target', 'new', 'to') })
        if ($c.Count -eq 1) { $tgtCol = $c[0] }
        elseif ($c.Count -gt 1) { throw "More than one column could be the target id: $($c -join ', '). Name it explicitly." }
    }
    if (-not $srcCol -or -not $tgtCol) {
        throw "Could not work out which columns hold the ids in $resolved. Headers: $($names -join ', ')."
    }

    Write-VaultLog "Id columns: '$srcCol' -> '$tgtCol' ($how)"

    $map = @{}
    $bad = 0; $sci = 0; $dupes = 0
    $badRows  = New-Object System.Collections.ArrayList
    $conflict = New-Object System.Collections.ArrayList
    $rowNo = 1

    foreach ($row in $rows) {
        $rowNo++
        $a = "$(Get-VaultField $row $srcCol '')".Trim()
        $b = "$(Get-VaultField $row $tgtCol '')".Trim()

        if ($a -match '^\d+(\.\d+)?[eE][+-]?\d+$' -or $b -match '^\d+(\.\d+)?[eE][+-]?\d+$') { $sci++; $bad++; continue }
        if ($a -notmatch '^\d+$' -or $b -notmatch '^\d+$') {
            $bad++
            [void]$badRows.Add(("line {0}: source='{1}' target='{2}'" -f $rowNo, $a, $b))
            continue
        }
        if ($map.ContainsKey($a)) {
            # A row per file means one document appears many times. Repeats are expected;
            # a repeat pointing somewhere ELSE is not.
            if ($map[$a] -ne $b) { [void]$conflict.Add("$a -> $($map[$a]) and $b") } else { $dupes++ }
            continue
        }
        $map[$a] = $b
    }

    $script:VaultIdMapStats = @{
        Path = $resolved; Delimiter = $shown; Bom = $bom; Headers = @($names)
        SourceColumn = $srcCol; TargetColumn = $tgtCol; How = $how
        Rows = $rows.Count; Pairs = $map.Count; Skipped = $bad
        RepeatedPairs = $dupes; Conflicts = $conflict.Count; Scientific = $sci
        BadRows = @($badRows)
        Canonical = ($how -eq 'canonical header' -and $shown -eq ',')
    }

    if ($sci) {
        # Refuse rather than continue on the rows that survived: a mangled id is a
        # document that silently never gets processed while the run still reports success.
        throw @"
$sci row(s) in $resolved hold ids in scientific notation, e.g. 5.5283E+04.

Excel does that to long numbers on export and the digits are gone - they cannot be
recovered from the file. Re-export with both id columns formatted as Text.
"@
    }
    if ($conflict.Count) {
        $show = ($conflict | Select-Object -First 5) -join '; '
        throw "The map sends the same source to two different targets: $show. Fix the map - choosing between them is not something this can do."
    }
    if ($bad) {
        Write-VaultLog "$bad row(s) in $resolved had no usable id pair and were skipped - those are NOT processed" 'WARN'
        foreach ($br in ($badRows | Select-Object -First 10)) { Write-VaultLog "  $br" 'WARN' }
        if ($badRows.Count -gt 10) { Write-VaultLog "  ... and $($badRows.Count - 10) more" 'WARN' }

        $excel = @($badRows | Where-Object { $_ -match '#(N/A|REF!|VALUE!|NAME\?|DIV/0!|NUM!|NULL!)' })
        if ($excel.Count) {
            Write-VaultLog "  $($excel.Count) hold an Excel error such as #N/A - the lookup in the sheet found no match," 'WARN'
            Write-VaultLog '  so those have no target id. Either they were never migrated, or the formula missed them.' 'WARN'
        }
        $distinct = @($badRows | ForEach-Object { ($_ -split "source='")[1] -split "'" | Select-Object -First 1 } |
                      Where-Object { $_ } | Select-Object -Unique)
        if ($distinct.Count -and $distinct.Count -ne $badRows.Count) {
            Write-VaultLog "  $($distinct.Count) distinct source(s) affected: $($distinct -join ', ')" 'WARN'
        }
    }
    if ($dupes) { Write-VaultLog "$dupes repeated row(s) for pairs already mapped - expected when the sheet has a row per file" }
    if ($map.Count -eq 0) { throw "No usable id pairs in $resolved" }

    Write-VaultLog "$($map.Count) id pair(s) from $resolved ($shown-separated, '$srcCol' -> '$tgtCol')" 'OK'
    return $map
}

# ===== VaultKit/Run.ps1 =====

# Disk budget, scratch space, resumable results, and the run lock.
#
# Everything a long job needs to be interruptible and honest about what it did.

# --------------------------------------------------------------------------------------
# Disk
# --------------------------------------------------------------------------------------

function Get-VaultFreeSpace {
    param([Parameter(Mandatory)][string]$Path)
    $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    try { return (New-Object IO.DriveInfo $root).AvailableFreeSpace }
    catch { return -1 }
}

function Assert-VaultDiskBudget {
    # Stop before the volume fills, not after. Checked ahead of every download, because
    # the whole streaming design rests on the scratch folder staying nearly empty.
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][long]$Needed,
        [int]$ReserveMB = 2048
    )
    $free = Get-VaultFreeSpace -Path $Path
    if ($free -lt 0 -or $Needed -le 0) { return }
    if (($free - $Needed) -lt ($ReserveMB * 1MB)) {
        throw "not enough disk: $(Format-VaultBytes $Needed) needed, $(Format-VaultBytes $free) free, ${ReserveMB}MB reserve"
    }
}

function New-VaultScratch {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Name)
    $dir = Join-Path $Root $Name
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false | Out-Null
    }
    return $dir
}

function Remove-VaultScratchFile {
    # Success or failure, the local copy goes - that is what keeps disk bounded. Logged
    # every time with the free space left, because a delete that quietly stopped working
    # would otherwise surface as a full volume hours later instead of a line in the log.
    #
    # Retried, because the delete competes with whatever scans files as they are written.
    # Windows Defender opening a freshly downloaded PDF is enough to make Remove-Item
    # fail with "being used by another process", and it lets go a moment later.
    param(
        [Parameter(Mandatory)][AllowNull()]$File,
        [Parameter(Mandatory)][string]$Scratch,
        [string]$Prefix = '',
        [int]$Attempts = 5
    )
    if (-not $File) { return }
    if (-not (Test-Path -LiteralPath $File.Path)) { return }

    for ($n = 1; $n -le $Attempts; $n++) {
        try {
            Remove-Item -LiteralPath $File.Path -Force -WhatIf:$false
            $free = Get-VaultFreeSpace -Path $Scratch
            $note = if ($free -ge 0) { ", $(Format-VaultBytes $free) free" } else { '' }
            Write-VaultLog "$Prefix scratch file deleted ($(Format-VaultBytes $File.Size)$note)"
            return
        }
        catch {
            if ($n -eq $Attempts) {
                Write-VaultLog "Could not delete $($File.Path) after $Attempts attempts: $_" 'WARN'
                return
            }
            Start-Sleep -Milliseconds (200 * $n)
        }
    }
}

function Remove-VaultScratchDir {
    # The whole per-item folder, once its files are gone. Deleting a directory that a
    # scanner still holds a file in fails the same way, so it gets the same patience.
    param([Parameter(Mandatory)][string]$Path, [int]$Attempts = 5)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    for ($n = 1; $n -le $Attempts; $n++) {
        try { Remove-Item -LiteralPath $Path -Recurse -Force -WhatIf:$false; return }
        catch {
            if ($n -eq $Attempts) { return }   # Report-VaultLeftovers will name it
            Start-Sleep -Milliseconds (200 * $n)
        }
    }
}

function Report-VaultLeftovers {
    param([Parameter(Mandatory)][string]$Scratch)
    # Recurse: files live in a folder per item now, so a non-recursive look sees an
    # empty scratch root while gigabytes sit one level down.
    $left = @(Get-ChildItem -LiteralPath $Scratch -File -Recurse -ErrorAction SilentlyContinue)
    if (-not $left.Count) { return }
    $bytes = ($left | Measure-Object -Property Length -Sum).Sum
    Write-VaultLog "$($left.Count) file(s) left in $Scratch taking $(Format-VaultBytes $bytes) - safe to delete" 'WARN'
}

# --------------------------------------------------------------------------------------
# Results
#
# Rewritten after every item, so an interrupted run still leaves a usable file. Rows an
# earlier run recorded for items this run did not touch are carried through rather than
# dropped - otherwise a capped or resumed run would truncate the file to just what it
# processed, losing the record of everything already done.
# --------------------------------------------------------------------------------------

function New-VaultResults {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$KeyColumn,
        [string[]]$DoneStatuses = @(),
        [ValidateSet('Prompt', 'Resume', 'Fresh')][string]$Existing = 'Resume'
    )
    $prior = [ordered]@{}
    $done  = @{}

    if (Test-Path -LiteralPath $Path) {
        $choice = $Existing
        if ($choice -eq 'Prompt') {
            $rows = @(Import-Csv -LiteralPath $Path)
            Write-Host ''
            Write-Host "Results from an earlier run are here: $($rows.Count) row(s) in $Path" -ForegroundColor Yellow
            if ($Host.UI.RawUI -and -not [Console]::IsInputRedirected) {
                $a = Read-Host 'Resume (keep them) or start Fresh (rotate aside)? [R]esume/[F]resh'
                $choice = if ($a -match '^[Ff]') { 'Fresh' } else { 'Resume' }
            }
            else { $choice = 'Resume' }
        }
        if ($choice -eq 'Fresh') {
            $when = (Get-Item -LiteralPath $Path).LastWriteTime.ToString('yyyyMMdd-HHmmss')
            $moved = [IO.Path]::Combine([IO.Path]::GetDirectoryName($Path),
                     ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($Path), $when, [IO.Path]::GetExtension($Path)))
            Move-Item -LiteralPath $Path -Destination $moved -Force -WhatIf:$false
            Write-VaultLog "Rotated previous results to $(Split-Path -Leaf $moved)"
        }
        else {
            foreach ($row in (Import-Csv -LiteralPath $Path)) {
                $k = "$(Get-VaultField $row $KeyColumn '')"
                if (-not $k) { continue }
                $prior[$k] = $row
                if ($DoneStatuses -contains "$(Get-VaultField $row 'Status' '')") { $done[$k] = $true }
            }
            if ($done.Count) { Write-VaultLog "$($done.Count) item(s) already completed by an earlier run - not repeated" }
        }
    }

    # The journal. Every row is appended to it as it happens, which costs the same
    # whether it is the first row or the ten-thousandth - where writing the CSV costs
    # more with every row already in it.
    #
    # JSON lines rather than CSV lines: rows gain columns between versions, and a file
    # with a header written at the start cannot absorb that. Each line stands alone, and
    # ConvertTo-VaultUniformRows squares them up when the CSV is written.
    $journal = "$Path.jsonl"
    if ($Existing -eq 'Fresh') { Remove-Item -LiteralPath $journal -Force -WhatIf:$false -ErrorAction SilentlyContinue }
    elseif (Test-Path -LiteralPath $journal) {
        # Rows an interrupted run appended after its last CSV write. They are NEWER than
        # anything in the CSV, so they win - that is the point of having them.
        $recovered = 0
        foreach ($line in (Get-Content -LiteralPath $journal -ErrorAction SilentlyContinue)) {
            if (-not "$line".Trim()) { continue }
            try { $row = $line | ConvertFrom-Json } catch { continue }   # a torn last line
            $k = "$(Get-VaultField $row $KeyColumn '')"
            if (-not $k) { continue }
            $prior[$k] = $row
            $recovered++
            if ($DoneStatuses -contains "$(Get-VaultField $row 'Status' '')") { $done[$k] = $true }
        }
        if ($recovered) {
            Write-VaultLog "$recovered row(s) recovered from the journal of an interrupted run" 'WARN'
        }
    }

    return [pscustomobject]@{
        Path      = $Path
        Journal   = $journal
        KeyColumn = $KeyColumn
        Prior     = $prior
        Done      = $done
        Rows      = (New-Object System.Collections.ArrayList)
    }
}

function ConvertTo-VaultUniformRows {
    # Every row given every column, before anything is exported.
    #
    # Export-Csv takes its header from the FIRST object it is handed and then writes only
    # those properties for every row after it. Results files outlive the version that
    # wrote them: a resumed run merges rows from before a column existed with rows from
    # after, and if an older row happens to come first, the newer column is dropped from
    # the whole file. Silently, with an exit code of zero.
    #
    # Columns keep first-seen order, so a file's shape stays recognisable and anything
    # added later appears at the end.
    param([Parameter(Mandatory)][AllowEmptyCollection()]$Rows)
    $all = @($Rows)
    if (-not $all.Count) { return $all }

    $cols = New-Object System.Collections.ArrayList
    foreach ($r in $all) {
        foreach ($p in $r.PSObject.Properties) {
            if (-not $cols.Contains($p.Name)) { [void]$cols.Add($p.Name) }
        }
    }

    $out = New-Object System.Collections.ArrayList
    foreach ($r in $all) {
        $flat = [ordered]@{}
        foreach ($c in $cols) {
            $prop = $r.PSObject.Properties[$c]
            $flat[$c] = if ($prop) { $prop.Value } else { '' }
        }
        [void]$out.Add([pscustomobject]$flat)
    }
    return $out
}

function Save-VaultResults {
    param([Parameter(Mandatory)]$Results)
    $current = @{}
    foreach ($r in $Results.Rows) { $current["$(Get-VaultField $r $Results.KeyColumn '')"] = $r }

    $out = New-Object System.Collections.ArrayList
    $written = @{}
    foreach ($k in $Results.Prior.Keys) {
        $key = "$k"
        if ($current.ContainsKey($key)) { [void]$out.Add($current[$key]) } else { [void]$out.Add($Results.Prior[$key]) }
        $written[$key] = $true
    }
    foreach ($r in $Results.Rows) {
        $key = "$(Get-VaultField $r $Results.KeyColumn '')"
        if (-not $written.ContainsKey($key)) { [void]$out.Add($r) }
    }
    (ConvertTo-VaultUniformRows -Rows $out) |
        Export-Csv -LiteralPath $Results.Path -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    # The journal has served its purpose the moment its rows are in the CSV. Removed only
    # after the write above succeeded, so a failure there leaves the journal to recover
    # from rather than leaving nothing at all.
    if ($Results.PSObject.Properties['Journal'] -and $Results.Journal) {
        Remove-Item -LiteralPath $Results.Journal -Force -WhatIf:$false -ErrorAction SilentlyContinue
    }
}

function Format-VaultDuration {
    param([double]$Seconds)
    if ($Seconds -ge 3600) { return ('{0:N1} hour(s)'   -f ($Seconds / 3600)) }
    if ($Seconds -ge 60)   { return ('{0:N1} minute(s)' -f ($Seconds / 60)) }
    return ('{0:N0} second(s)' -f $Seconds)
}

function Copy-VaultResultsSnapshot {
    # This run's own copy of its results, stamped, and never written again.
    #
    # The working file keeps a fixed name because resume depends on it: a run has to
    # find what an earlier one finished, and it cannot do that if every run writes to a
    # new name. But that fixed name is then merged into, rotated aside, or overwritten
    # by whatever runs next - so the record of what THIS run did does not survive it.
    #
    # The snapshot is that record. It carries the same timestamp as the run's log, so a
    # report and the log that explains it can be paired without guessing.
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }

    $stamp = ''
    if ($script:VaultLogFile -and ($script:VaultLogFile -match '(\d{8}-\d{6})')) { $stamp = $Matches[1] }
    if (-not $stamp) { $stamp = Get-Date -Format 'yyyyMMdd-HHmmss' }

    $snap = [IO.Path]::Combine(
        [IO.Path]::GetDirectoryName($Path),
        ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($Path), $stamp, [IO.Path]::GetExtension($Path)))
    try {
        Copy-Item -LiteralPath $Path -Destination $snap -Force -WhatIf:$false
        return $snap
    }
    catch {
        Write-VaultLog "Could not write the results snapshot: $_" 'WARN'
        return ''
    }
}

function Add-VaultResult {
    # Append, never rewrite. One line on the end of the journal costs the same at row ten
    # thousand as at row one, where writing the CSV costs more with every row already in
    # it - so recording n documents is linear rather than quadratic.
    #
    # Every caller MUST call Save-VaultResults when it finishes: that is what turns the
    # journal into the CSV people read.
    param([Parameter(Mandatory)]$Results, [Parameter(Mandatory)]$Row)
    [void]$Results.Rows.Add($Row)
    try {
        [IO.File]::AppendAllText($Results.Journal, (($Row | ConvertTo-Json -Compress -Depth 5) + [Environment]::NewLine))
    }
    catch {
        # A journal that cannot be written is not worth stopping a migration for - the
        # rows are still in memory and still reach the CSV. Said once, not per row.
        if (-not $script:VaultJournalWarned) {
            Write-VaultLog "Could not append to the results journal: $_" 'WARN'
            $script:VaultJournalWarned = $true
        }
    }
}

# --------------------------------------------------------------------------------------
# Run lock
#
# An update replaces the scripts in the operator's folder. Doing that mid-run is not
# harmless, so a running job leaves a lock that the updater refuses to walk over.
# --------------------------------------------------------------------------------------

$script:VaultJournalWarned = $false

$script:VaultLock = ''

# Workers take no lock. The supervisor holds one for the whole run, and a worker taking
# the same one means nine processes writing one file - then the first worker to FINISH
# deletes it, disarming the guard while the run is still going. That is worse than no
# lock at all, because it looks like one is held.
$script:VaultLockEnabled = $true

function Set-VaultLockEnabled {
    param([bool]$Value)
    $script:VaultLockEnabled = $Value
}

function Start-VaultLock {
    param([Parameter(Mandatory)][string]$Name)
    if (-not $script:VaultLockEnabled) { return }
    $here = $PSScriptRoot
    if ($here) { $here = Split-Path -Parent $here } else { $here = (Get-Location).ProviderPath }
    $script:VaultLock = Join-Path $here ".run-$Name.lock"
    try {
        Set-Content -LiteralPath $script:VaultLock -Encoding ASCII -WhatIf:$false -Value @(
            "pid=$PID", "command=$Name", "started=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    }
    catch { Write-VaultLog "Could not write the run lock: $_" 'WARN' }
}

function Stop-VaultLock {
    # Explicitly, not only on an exit event: a run that ends badly may never reach the
    # event, and a lock left behind blocks the next update.
    if ($script:VaultLock -and (Test-Path -LiteralPath $script:VaultLock)) {
        try { Remove-Item -LiteralPath $script:VaultLock -Force -WhatIf:$false } catch { }
    }
}

# ===== VaultKit/Workers.ps1 =====

# Running one workflow across several processes.
#
# Above one worker the command stops moving anything itself and becomes a supervisor: it
# shards the outstanding work, launches that many copies of vault.ps1 - each in its own
# output folder, with its own input file, its own results and its own log - waits, and
# merges their results back into the one file the operator reads.
#
# Separate PROCESSES rather than runspaces or jobs, because that is what makes the work
# genuinely independent: no shared state to contend on, a worker that dies takes nothing
# with it, and the results file each one writes is a complete record on its own. The cost
# is that a worker cannot ask for a password, which is what the credential file is for.
#
# Per-document time is dominated by round trips, not bytes, so this scales close to
# linearly until Vault's burst limit starts throttling.

function Read-VaultWorkerLog {
    # Forward a worker's new WARN/ERROR lines into the parent log.
    #
    # Workers run hidden and write their own logs, so without this a worker failing every
    # document looks - from the parent - like progress that simply stopped, with the
    # error text sitting in a file nobody is watching.
    #
    # Opened with FileShare.ReadWrite because the worker still has it open for writing.
    # The read offset is kept per worker so each line is forwarded exactly once.
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][hashtable]$Offsets,
        [int]$MaxLines = 20
    )
    $log = @(Get-ChildItem -LiteralPath $Dir -Filter $Pattern -ErrorAction SilentlyContinue |
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
        Write-VaultLog ("{0} | {1}" -f $Label, ($line -replace '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[(WARN|ERROR)\] ', '')) $level
    }
    if ($bad.Count -gt $MaxLines) {
        Write-VaultLog ("{0} | ... {1} more line(s) this interval, full detail in {2}" -f $Label, ($bad.Count - $MaxLines), $path) 'WARN'
    }
}

function Merge-VaultWorkerLog {
    # One log out of many, in the order things actually happened.
    #
    # Each worker keeps its own log - that is what makes a single worker's story readable
    # when it is the one that went wrong. But nobody wants to open nine files to find out
    # what a run did, and "which worker was that" is not a question worth answering by
    # hand. So the per-worker files stay as the raw evidence and this writes the narrative.
    #
    # Sorted on the timestamp each line already carries. A line without one is a
    # continuation of the line above it - a wrapped error, say - so it inherits that
    # timestamp and stays attached rather than being sorted to the top.
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][string]$OutPath,
        [string]$SupervisorLog = ''
    )
    $entries = New-Object System.Collections.ArrayList

    $sources = New-Object System.Collections.ArrayList
    if ($SupervisorLog -and (Test-Path -LiteralPath $SupervisorLog)) {
        [void]$sources.Add([pscustomobject]@{ Label = 'sup'; Path = $SupervisorLog })
    }
    for ($w = 1; $w -le $Count; $w++) {
        $dir = Join-Path $Root "w$w"
        $log = @(Get-ChildItem -LiteralPath $dir -Filter $Pattern -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime | Select-Object -Last 1)
        if ($log.Count) { [void]$sources.Add([pscustomobject]@{ Label = "w$w"; Path = $log[0].FullName }) }
    }
    if (-not $sources.Count) { return '' }

    foreach ($src in $sources) {
        $seq = 0; $ts = '0000-00-00 00:00:00'
        foreach ($line in (Get-Content -LiteralPath $src.Path -ErrorAction SilentlyContinue)) {
            $seq++
            if ("$line" -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') { $ts = $Matches[1] }
            [void]$entries.Add([pscustomobject]@{ Ts = $ts; Label = $src.Label; Seq = $seq; Line = "$line" })
        }
    }

    # Ts first, then the worker, then its own line order - so a worker's lines never
    # shuffle among themselves when several share a second.
    $sorted = @($entries | Sort-Object Ts, Label, Seq)
    $out = New-Object System.Collections.ArrayList
    foreach ($e in $sorted) { [void]$out.Add(('{0,-3} | {1}' -f $e.Label, $e.Line)) }
    [IO.File]::WriteAllLines($OutPath, $out, (New-Object Text.UTF8Encoding $false))
    return $OutPath
}

function Invoke-VaultShardedRun {
    # Returns the number of items that failed, so the caller's exit code is unchanged
    # whether the run was sequential or parallel.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Pending,
        [Parameter(Mandatory)][int]$Workers,
        [Parameter(Mandatory)][string[]]$Command,     # e.g. @('documents', 'stage')
        [Parameter(Mandatory)][string]$LogPattern,    # e.g. 'documents-stage-*.log'
        [Parameter(Mandatory)][string]$ResultsName,   # e.g. 'document-results.csv'
        [string]$KeyColumn = 'Id',
        # What a shard file is. The transfer works from a list of ids; the attachment
        # sync works from a map of source id to target id, and handing a worker half a
        # map as a list of ids loses the half that says where things go.
        [ValidateSet('ids', 'map')][string]$ShardKind = 'ids',
        # Whether one item produces one result row. It does for documents. It does not
        # for attachments, where a shard is documents and the rows are attachments - so
        # progress against a document count would read 500/200 and an ETA computed from
        # it would be wrong rather than merely coarse.
        [bool]$RowsAreItems = $true,
        # What a good row looks like for this workflow. The transfer records SUCCESS and
        # the validator records MATCH, and a supervisor that only knows one of them
        # counts every row of the other as a failure.
        [string]$SuccessStatus = 'SUCCESS',
        [string]$Verb = 'Moved',
        # Only the transfer renames anything. The validator's Name column holds what the
        # SOURCE calls the file, which is a different thing from the name that was
        # written - comparing them there reported 195 renames out of 200 when 2 had
        # happened.
        [switch]$ReportRenames,
        [string[]]$ExtraArgs = @()
    )
    $c     = $Context
    $count = [math]::Min($Workers, $Pending.Count)
    $root  = Join-Path $c.Out 'workers'
    if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force -WhatIf:$false | Out-Null }

    $resultsPath = Join-Path $c.Out $ResultsName

    # -Existing Fresh, honoured here too. The single-process path rotates the results
    # aside and starts clean; the supervisor read them regardless and merged, so asking
    # for a fresh start on a worker run silently did not get one.
    if ($c.Existing -eq 'Fresh' -and (Test-Path -LiteralPath $resultsPath)) {
        $when  = (Get-Item -LiteralPath $resultsPath).LastWriteTime.ToString('yyyyMMdd-HHmmss')
        $moved = [IO.Path]::Combine([IO.Path]::GetDirectoryName($resultsPath),
                 ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($resultsPath), $when, [IO.Path]::GetExtension($resultsPath)))
        Move-Item -LiteralPath $resultsPath -Destination $moved -Force -WhatIf:$false
        Write-VaultLog "Rotated previous results to $(Split-Path -Leaf $moved)"
    }

    $prior = [ordered]@{}
    if (Test-Path -LiteralPath $resultsPath) {
        foreach ($row in (Import-Csv -LiteralPath $resultsPath)) {
            $k = "$(Get-VaultField $row $KeyColumn '')"
            if ($k) { $prior[$k] = $row }
        }
    }

    # Credentials are a bonus here, not a requirement. Workers share .vault-session.json
    # with this process and read their session straight out of it, so they can work
    # without ever holding a password. What a password buys them is the ability to
    # re-authenticate if a session expires mid-run - so its absence is a warning about
    # long runs, not a reason to refuse to start.
    #
    # On the normal path there is nothing to export: `login` cached the sessions in an
    # earlier process, so this one was never prompted and holds nothing.
    $credPath = ''
    $nCred    = 0
    try {
        $try = Join-Path $c.Out ('.worker-cred-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.xml')
        $nCred = Export-VaultCredentials -Path $try
        if ($nCred -gt 0) { $credPath = $try }
        else { Remove-Item -LiteralPath $try -Force -WhatIf:$false -ErrorAction SilentlyContinue }
    }
    catch { Write-VaultLog "Could not stage credentials for the workers: $_" 'WARN' }

    if ($nCred -gt 0) {
        Write-VaultLog "$nCred credential(s) staged for the workers - they can re-authenticate if a session expires"
    }
    else {
        Write-VaultLog 'No passwords are held in this process, so the workers run on the cached sessions alone.' 'WARN'
        Write-VaultLog 'If a session expires mid-run a worker cannot renew it and its remaining items will fail.' 'WARN'
        Write-VaultLog 'For a long run, log out and let the run prompt: vault logout, then start it again.' 'WARN'
    }

    $procs   = @()
    $offsets = @{}
    $started = Get-Date
    try {
        # Round robin rather than contiguous blocks. Document sizes are not evenly
        # distributed through an id list - they arrive grouped by whatever produced the
        # export - so contiguous shards routinely give one worker every large file.
        $shards = @{}
        for ($w = 1; $w -le $count; $w++) { $shards[$w] = New-Object System.Collections.ArrayList }
        for ($n = 0; $n -lt $Pending.Count; $n++) { [void]$shards[($n % $count) + 1].Add($Pending[$n]) }

        for ($w = 1; $w -le $count; $w++) {
            $wDir = Join-Path $root "w$w"
            if (-not (Test-Path -LiteralPath $wDir)) { New-Item -ItemType Directory -Path $wDir -Force -WhatIf:$false | Out-Null }
            if ($ShardKind -eq 'map') {
                $shardFile = Join-Path $wDir 'map.csv'
                $lines = New-Object System.Collections.ArrayList
                [void]$lines.Add('source,target')
                foreach ($pair in $shards[$w]) { [void]$lines.Add(('{0},{1}' -f $pair.Source, $pair.Target)) }
                Set-Content -LiteralPath $shardFile -Value $lines -Encoding ASCII -WhatIf:$false
                $inputArg = '-MapFile'
            }
            else {
                $shardFile = Join-Path $wDir 'ids.txt'
                Set-Content -LiteralPath $shardFile -Value ($shards[$w] -join "`r`n") -Encoding ASCII -WhatIf:$false
                $inputArg = '-IdFile'
            }

            # -Existing Fresh, because the worker folder is this run's alone and a
            # previous run's rows in it would be counted twice at merge time.
            # -Worker, not the credential file, is what marks worker mode: a worker must
            # never write the session file it shares with this process and its siblings,
            # whether or not it was given a password.
            $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($c.ScriptPath)`"") +
                       $Command +
                       @('-ConfigFile', "`"$($c.ConfigPath)`"",
                         $inputArg,     "`"$shardFile`"",
                         '-OutputRoot', "`"$wDir`"",
                         '-Worker',
                         '-Workers', '1', '-Existing', 'Fresh', '-NoPrompt', '-Yes')
            if ($credPath) { $argList += @('-CredentialFile', "`"$credPath`"") }
            $argList += $ExtraArgs

            $procs += Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -PassThru -WindowStyle Hidden
            Write-VaultLog "worker $w started (pid $($procs[-1].Id)) with $($shards[$w].Count) item(s)"
        }

        # No verb here on purpose. The summary at the end takes one because it reads
        # better with it; this line does not need one, and a hardcoded "moving" told an
        # operator running the validator that 200 documents were being transferred.
        Write-VaultLog "$count worker(s), $($Pending.Count) item(s). Per-worker output is under $root"

        # Progress is read from the workers' own results files - no shared state to
        # contend on, and a stalled worker shows up as a flat count rather than silence.
        while ($procs | Where-Object { -not $_.HasExited }) {
            Start-Sleep -Seconds 30
            $moved = 0
            $rows  = 0
            for ($w = 1; $w -le $count; $w++) {
                $wDir = Join-Path $root "w$w"
                Read-VaultWorkerLog -Dir $wDir -Label "w$w" -Pattern $LogPattern -Offsets $offsets
                # The JOURNAL while the worker is running, the CSV once it has finished.
                #
                # A worker writes its CSV exactly once, from Save-VaultResults, at the
                # end of its run - so polling the CSV of a live worker reads nothing, and
                # progress sat at zero for the whole run however long it was. The journal
                # is the file that grows: one JSON line appended per row as it happens.
                # Save-VaultResults deletes it once the CSV is safely written, which is
                # what makes the fallback below the right way round.
                #
                # Both numbers, because they answer different questions. Successes say
                # how much of the job is done; rows say whether anything is happening at
                # all - and on a verify of a population that has not been migrated yet,
                # almost nothing is a success.
                $f = Join-Path $wDir $ResultsName
                $j = "$f.jsonl"
                if (Test-Path -LiteralPath $j) {
                    # Matched as text rather than parsed: this runs every 30 seconds over
                    # a file that only grows, and ConvertFrom-Json on every line of a
                    # 15,000-row journal to count them is not what the poll is for.
                    try {
                        $lines  = @(Get-Content -LiteralPath $j -ErrorAction SilentlyContinue)
                        $rows  += $lines.Count
                        $moved += @($lines | Where-Object { $_ -like "*`"Status`":`"$SuccessStatus`"*" }).Count
                    } catch { }
                }
                elseif (Test-Path -LiteralPath $f) {
                    try {
                        $csv    = @(Import-Csv -LiteralPath $f)
                        $rows  += $csv.Count
                        $moved += @($csv | Where-Object { $_.Status -eq $SuccessStatus }).Count
                    } catch { }
                }
            }
            $elapsed = ((Get-Date) - $started).TotalSeconds
            $alive   = @($procs | Where-Object { -not $_.HasExited }).Count
            if (-not $RowsAreItems) {
                # Rate from rows, not successes: it is a measure of how fast the run is
                # moving, and a run finding nothing to do is still moving.
                $rate = if ($elapsed -gt 0) { $rows / $elapsed } else { 0 }
                Write-VaultLog ("progress {0:N0} row(s), {1:N0} {2}, at {3:N2}/s overall, {4} of {5} worker(s) alive" -f `
                                $rows, $moved, $SuccessStatus, $rate, $alive, $count)
            }
            elseif ($moved -gt 0 -and $elapsed -gt 0) {
                $rate = $moved / $elapsed
                $left = $Pending.Count - $moved
                $eta  = (Get-Date).AddSeconds($left / [math]::Max($rate, 0.0001))
                # "overall", said every time: this is the sum across all workers over
                # wall clock, not one worker's rate. Reading it as per-worker overstates
                # throughput by the worker count, which turns an eight hour wave into a
                # one hour one on paper.
                Write-VaultLog ("progress {0:N0}/{1:N0} at {2:N2}/s overall, {3} of {4} worker(s) alive, ETA {5:yyyy-MM-dd HH:mm}" -f `
                                $moved, $Pending.Count, $rate, $alive, $count, $eta)
            }
            else { Write-VaultLog "progress 0/$($Pending.Count), $alive of $count worker(s) alive" }
        }

        # Drain whatever each worker wrote between the last poll and exiting.
        for ($w = 1; $w -le $count; $w++) {
            Read-VaultWorkerLog -Dir (Join-Path $root "w$w") -Label "w$w" -Pattern $LogPattern -Offsets $offsets -MaxLines 50
        }
        foreach ($proc in $procs) {
            if ($proc.ExitCode -ne 0) { Write-VaultLog "worker pid $($proc.Id) exited $($proc.ExitCode) - some items failed" 'WARN' }
        }

        # Merge every worker's rows back into the one results file the operator reads.
        #
        # A worker's row REPLACES the earlier one for the same document. It has to: a
        # document that failed once and is retried already has a row, and keeping the
        # older one meant the retry succeeded, was counted as moved, and was still
        # recorded ERROR - so the next resume retried it again, and so would every
        # resume after that, for ever.
        $fresh = @{}
        $ok = 0; $bad = 0
        for ($w = 1; $w -le $count; $w++) {
            $f = Join-Path (Join-Path $root "w$w") $ResultsName
            if (-not (Test-Path -LiteralPath $f)) { Write-VaultLog "worker $w produced no results file" 'WARN'; continue }
            foreach ($row in (Import-Csv -LiteralPath $f)) {
                if ("$(Get-VaultField $row 'Status' '')" -eq $SuccessStatus) { $ok++ } else { $bad++ }
                $key = "$(Get-VaultField $row $KeyColumn '')"
                if ($key) { $fresh[$key] = $row }
            }
        }

        $merged  = New-Object System.Collections.ArrayList
        $written = @{}
        foreach ($k in $prior.Keys) {
            $key = "$k"
            if ($fresh.ContainsKey($key)) { [void]$merged.Add($fresh[$key]) } else { [void]$merged.Add($prior[$key]) }
            $written[$key] = $true
        }
        foreach ($key in $fresh.Keys) {
            if (-not $written.ContainsKey("$key")) { [void]$merged.Add($fresh[$key]) }
        }
        (ConvertTo-VaultUniformRows -Rows $merged) |
            Export-Csv -LiteralPath $resultsPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false

        # Counted from the merged rows rather than from each worker, because a rename is
        # a property of the result and the supervisor only ever sees the workers' output.
        # Read with Get-VaultField: rows written by an older version have no StagedName,
        # and under StrictMode reaching for a missing property is a terminating error.
        $renamed = 0
        if ($ReportRenames) { $renamed = @($merged | Where-Object {
            # The row's own answer where it has one. Rows written before the column
            # existed fall back to the comparison it was derived from.
            $flag = "$(Get-VaultField $_ 'Renamed' '')"
            if ($flag) { $flag -eq 'True' }
            else {
                $sn = "$(Get-VaultField $_ 'StagedName' '')"
                $sn -and ($sn -cne "$(Get-VaultField $_ 'Name' '')")
            }
        }).Count }
        if ($renamed) {
            Write-VaultLog "$renamed document(s) were written under a changed name - the rows where Name and StagedName differ" 'WARN'
        }

        # Merged before the summary is written, so the summary can name it. The few
        # supervisor lines after this point are in the supervisor's own log rather than
        # the merged one - which is the right way round, since they say where to look.
        $merged = ''
        try {
            $stamp = if ($script:VaultLogFile -and ($script:VaultLogFile -match '(\d{8}-\d{6})')) { $Matches[1] } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
            $name  = ($LogPattern -replace '\*.*$', '') + $stamp + '-all.log'
            $merged = Merge-VaultWorkerLog -Root $root -Pattern $LogPattern -Count $count `
                          -OutPath (Join-Path $c.Out $name) -SupervisorLog $script:VaultLogFile
        }
        catch { Write-VaultLog "Could not merge the worker logs: $_" 'WARN' }

        $secs = ((Get-Date) - $started).TotalSeconds
        Write-VaultLog '----------------------------------------------------------------'
        $of = if ($RowsAreItems) { " of $($Pending.Count)" } else { '' }
        Write-VaultLog ("$Verb $ok$of item(s), $bad not $SuccessStatus, in $(Format-VaultDuration $secs) across $count worker(s)") $(if ($bad) { 'WARN' } else { 'OK' })
        Write-VaultLog "Results     : $resultsPath"
        if ($merged) { Write-VaultLog "Merged log  : $merged" }
        # Said at the end of every parallel run, because "should we use more workers" is
        # a question about this number and nothing else.
        foreach ($line in (Get-VaultBurstReport)) { Write-VaultLog "  $line" }
        $snap = Copy-VaultResultsSnapshot -Path $resultsPath
        if ($snap) { Write-VaultLog "This run    : $snap" }
        Write-VaultLog "Worker output: $root"
        return $bad
    }
    finally {
        # Ctrl-C stops THIS process. The workers are separate processes and carry on:
        # still uploading, still writing results, still holding scratch files open - so
        # an operator who stopped the run watches it continue, and the next run trips
        # over files an orphan is still using.
        #
        # Anything still alive when the supervisor leaves is stopped, whether it left by
        # finishing, by an error, or by Ctrl-C.
        $orphans = @($procs | Where-Object { $_ -and -not $_.HasExited })
        if ($orphans.Count) {
            Write-VaultLog "stopping $($orphans.Count) worker(s) still running: $(($orphans | ForEach-Object { $_.Id }) -join ', ')" 'WARN'
            foreach ($proc in $orphans) {
                try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop }
                catch { Write-VaultLog "could not stop worker pid $($proc.Id): $_" 'WARN' }
            }
            Write-VaultLog 'Their part-finished work is recorded, so resuming picks up where they stopped.' 'WARN'
        }

        # The credential file must not outlive the run, even on Ctrl-C.
        if ($credPath -and (Test-Path -LiteralPath $credPath)) {
            Remove-Item -LiteralPath $credPath -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }
}

# ===== VaultKit/Attachments.ps1 =====

# Document attachments: reconcile one vault against another, and prove the result.
#
# Both commands compare before acting, which is what makes them safe to run repeatedly.
# A document already in step costs two listing calls and nothing else.

function Get-VaultDocumentAttachment {
    # Every attachment on the latest version of a document, from either vault. The
    # listing carries name, size and MD5, so both the comparison and the size projection
    # come free - no file has to be fetched to find out what is there.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][string]$DocId
    )
    $r = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET `
            -Path "/objects/documents/$DocId/attachments"
    $out = New-Object System.Collections.ArrayList
    foreach ($a in @(Get-VaultField $r 'data' @())) {
        $aid = "$(Get-VaultField $a 'id' '')"
        if (-not $aid) { continue }
        [void]$out.Add([pscustomobject]@{
            Id       = $aid
            Name     = "$(Get-VaultField $a 'filename__v' "attachment-$aid")"
            Size     = [long]"$(Get-VaultField $a 'size__v' 0)"
            Version  = "$(Get-VaultField $a 'version__v' '')"
            Checksum = "$(Get-VaultField $a 'md5checksum__v' '')"
        })
    }
    return $out
}

function Get-VaultDocumentsWithAttachment {
    # Which documents in a vault carry attachments at all, asked once instead of
    # discovered one listing at a time.
    #
    # The sync spends one source listing per mapped document - 15,757 of them to find the
    # ~800 that carry anything. Vault's allowance is 2,000 calls per five minutes per
    # USER, so workers cannot buy their way past it: four processes and two processes
    # finish together, the four just spend more of it asleep. The only lever is making
    # fewer calls, and 95% of those calls exist to learn that a document has nothing.
    #
    # attachments__sysr is queryable as a subquery in a WHERE clause from v24.1.
    #
    # Returns $null - not an empty hashtable - when the query cannot be answered. "No
    # document has attachments" and "I could not ask" must not look the same to the
    # caller: the first means skip the scan, the second means do it.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion
    )
    $vql = 'SELECT id FROM documents WHERE id IN (SELECT document_id__sys FROM attachments__sysr)'
    Write-VaultLog "Asking $VaultHost which documents carry attachments: $vql"

    $ids   = @{}
    $path  = '/query'
    $body  = "q=$([Uri]::EscapeDataString($vql))"
    $pages = 0
    try {
        while ($path -and $pages -lt 1000) {
            $pages++
            # Page 1 is a POST carrying the query; every page after is a GET on the URL
            # Vault hands back, which already has the query baked in.
            $r = if ($pages -eq 1) {
                    Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method POST `
                        -Path $path -Body $body -ContentType 'application/x-www-form-urlencoded'
                 } else {
                    Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path $path
                 }
            foreach ($row in @(Get-VaultField $r 'data' @())) {
                $id = "$(Get-VaultField $row 'id' '')"
                if ($id) { $ids[$id] = $true }
            }
            $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
        }
    }
    catch {
        Write-VaultLog "The attachment query failed, so every document will be listed instead: $_" 'WARN'
        return $null
    }
    Write-VaultLog "$($ids.Count) document(s) in $VaultHost carry attachments, from $pages page(s)" 'OK'
    return $ids
}

function Send-VaultDocumentAttachment {
    # Upload straight onto the target document - no File Staging anywhere.
    #
    # POST /objects/documents/{id}/attachments takes the file as multipart/form-data, up
    # to 2GB, and attaches it in the same call. That replaces open a resumable session,
    # create each folder level, upload parts, commit, then a separate bulk attach - five
    # steps, of which the folder step failed every upload the first time it ran.
    #
    # HttpWebRequest with buffering off so the body streams from disk: a 2GB attachment
    # must never be assembled in memory. PowerShell 5.1 has no -Form, so the multipart
    # envelope is built by hand.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][string]$DocId,
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$FileName,
        [int]$MaxRetries = 4
    )
    $fileLen = (Get-Item -LiteralPath $LocalPath).Length

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sid      = Get-VaultSessionId -VaultHost $VaultHost -ApiVersion $ApiVersion
        $boundary = '----VaultKit' + [guid]::NewGuid().ToString('N')
        $pre  = "--$boundary`r`n" +
                "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`"`r`n" +
                "Content-Type: application/octet-stream`r`n`r`n"
        $post = "`r`n--$boundary--`r`n"
        $preB  = [Text.Encoding]::UTF8.GetBytes($pre)
        $postB = [Text.Encoding]::UTF8.GetBytes($post)

        $req = [Net.HttpWebRequest]::Create("https://$VaultHost/api/$ApiVersion/objects/documents/$DocId/attachments")
        $req.Method                    = 'POST'
        $req.ContentType               = "multipart/form-data; boundary=$boundary"
        $req.ContentLength             = $preB.Length + $fileLen + $postB.Length
        $req.AllowWriteStreamBuffering = $false
        $req.Timeout                   = 900000
        $req.ReadWriteTimeout          = 900000
        # Accept is a RESTRICTED header: Headers.Add throws on .NET Framework with "The
        # 'Accept' header must be modified using the appropriate property or method".
        $req.Accept = 'application/json'
        $req.Headers.Add('Authorization', $sid)

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

            $resp  = $req.GetResponse()
            $body  = ''
            $burst = $null
            try {
                $sr = New-Object IO.StreamReader($resp.GetResponseStream())
                $body = $sr.ReadToEnd(); $sr.Dispose()
                # Read the allowance while the response is still open, act on it after.
                # Easing off means sleeping, and a response held open for a minute is a
                # socket held open for a minute.
                try { $burst = $resp.Headers['X-VaultAPI-BurstLimitRemaining'] } catch { }
            }
            finally { $resp.Dispose() }

            # This call never went through Invoke-VaultApi, so without this nothing
            # records what it consumed. Uploads are what a worker spends its time on, so
            # a burst report blind to them measured the listing calls and not the run.
            Register-VaultBurstLimit -VaultHost $VaultHost -HeaderValue $burst

            $json = $null
            try { $json = $body | ConvertFrom-Json } catch { }
            if ($null -eq $json) { throw "attachment upload returned no JSON: $body" }
            if ((Get-VaultField $json 'responseStatus') -ne 'SUCCESS') {
                $errs = @(Get-VaultField $json 'errors' @())
                throw (($errs | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join '; ')
            }
            $d = Get-VaultField $json 'data' $null
            return [pscustomobject]@{
                AttachmentId = "$(Get-VaultField $d 'id' '')"
                Version      = "$(Get-VaultField $d 'version__v' (Get-VaultField $d 'version' ''))"
            }
        }
        catch [Net.WebException] {
            $status = $null
            try { if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode } } catch { }
            $detail = ''
            try {
                $er = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $er.ReadToEnd(); $er.Dispose()
            } catch { }

            # Waits come from the same helper every other call uses, for the reason it
            # exists: eight workers that all pause for exactly sixty seconds resume in
            # the same instant and hit the vault together, which is what turns being
            # throttled into thrashing. This is the path where waiting in lockstep costs
            # the most, since the upload is the call the workers are all inside. Vault's
            # own Retry-After is honoured as a floor - jitter only ever moves it later.
            $after = Get-VaultRetryAfter $_.Exception.Response

            if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                $wait = Get-VaultThrottleDelay -Kind 'throttled' -Attempt $attempt -RetryAfter $after
                Write-VaultLog "HTTP 429 attaching $FileName - waiting ${wait}s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds $wait; continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = Get-VaultThrottleDelay -Kind 'transient' -Attempt $attempt -RetryAfter $after
                Write-VaultLog "Transient error attaching $FileName (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait; continue
            }
            throw "attach failed (HTTP $status): $($_.Exception.Message) $detail"
        }
    }
    throw "attach of $FileName failed after $MaxRetries attempts"
}

function Compare-VaultAttachmentSet {
    # Match by filename, because that is Vault's own rule: posting a name that already
    # exists on a document creates a new VERSION of that attachment, not a second one.
    # Matching on anything looser would silently produce version churn.
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$Target)
    $byName = @{}
    foreach ($t in $Target) { $byName[$t.Name.ToLowerInvariant()] = $t }
    return $byName
}

function Invoke-VaultAttachmentsSync {
    param(
        [Parameter(Mandatory)]$Context,
        [switch]$Plan,
        [switch]$ReplaceDiffering,
        [switch]$Prefilter,
        [int]$TestCount = 0,
        [int]$Limit = 0
    )
    $c   = $Context
    $map = $c.Map
    $ids = @($map.Keys)
    if ($Limit -gt 0 -and $ids.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - examining the first $Limit of $($ids.Count) mapped document(s)" 'WARN'
        $ids = @($ids | Select-Object -First $Limit)
    }
    Write-VaultLog "$($ids.Count) mapped document(s) to examine"

    # Ask the vault which documents carry anything, rather than finding out one listing
    # at a time. Applied here, before the shard, so the workers inherit the reduced set
    # and none of them repeats the query.
    #
    # Opt-in, and it says so loudly: a document the query does not name is a document
    # this run never looks at. A slow run is a nuisance; an attachment that silently
    # never migrates is the thing this whole kit exists to prevent.
    if ($Prefilter) {
        $have = Get-VaultDocumentsWithAttachment -VaultHost $c.SourceHost -ApiVersion $c.Api
        if ($null -ne $have) {
            $before = $ids.Count
            $ids    = @($ids | Where-Object { $have.ContainsKey($_) })
            Write-VaultLog ("Prefilter: {0} of {1} mapped document(s) carry attachments - {2} source listing(s) skipped" -f `
                            $ids.Count, $before, ($before - $ids.Count)) 'OK'
            Write-VaultLog 'Documents the query did not name are NOT examined by this run.' 'WARN'
            if ($ids.Count -eq 0) {
                Write-VaultLog 'Nothing to do: no mapped document carries an attachment on the source.' 'OK'
                return 0
            }
        }
    }

    # Sharded by DOCUMENT, because that is what the map keys are and what a worker can be
    # handed. The rows it produces are per attachment, which is why the supervisor is
    # told not to treat one as the other.
    if ($c.Workers -gt 1 -and $ids.Count -gt 1 -and $TestCount -le 0 -and -not ($Plan -or $c.WhatIf)) {
        $pairs = @($ids | ForEach-Object { [pscustomobject]@{ Source = $_; Target = $map[$_] } })
        $extra = @()
        if ($ReplaceDiffering) { $extra += '-ReplaceDiffering' }
        return Invoke-VaultShardedRun -Context $c -Pending $pairs -Workers $c.Workers `
                   -Command @('attachments', 'sync') -LogPattern 'attachments-sync-*.log' `
                   -ResultsName 'attachment-results.csv' -KeyColumn 'Key' `
                   -SuccessStatus 'ATTACHED' -Verb 'Attached' -ShardKind 'map' `
                   -RowsAreItems $false -ExtraArgs $extra
    }

    $res = New-VaultResults -Path (Join-Path $c.Out 'attachment-results.csv') -KeyColumn 'Key' `
              -DoneStatuses @('ATTACHED') -Existing $c.Existing

    $stat = @{ Src = 0; Present = 0; Missing = 0; Differs = 0; Attached = 0; NoAtt = 0; Errors = 0 }
    $moved = [long]0
    $i = 0
    $stopped = $false

    :documents foreach ($srcId in $ids) {
        $i++
        $tgtId  = $map[$srcId]
        $prefix = "[$i/$($ids.Count)] $srcId -> $tgtId"

        try { $srcAtt = @(Get-VaultDocumentAttachment -VaultHost $c.SourceHost -ApiVersion $c.Api -DocId $srcId) }
        catch { Write-VaultLog "$prefix - ERROR listing source: $_" 'ERROR'; $stat.Errors++; continue }
        if ($srcAtt.Count -eq 0) { $stat.NoAtt++; continue }
        $stat.Src += $srcAtt.Count

        try { $tgtAtt = @(Get-VaultDocumentAttachment -VaultHost $c.TargetHost -ApiVersion $c.Api -DocId $tgtId) }
        catch { Write-VaultLog "$prefix - ERROR listing target: $_" 'ERROR'; $stat.Errors++; continue }
        $byName = Compare-VaultAttachmentSet -Target $tgtAtt

        foreach ($att in $srcAtt) {
            $key   = "$srcId`:$($att.Id)"
            $lname = $att.Name.ToLowerInvariant()
            $have  = if ($byName.ContainsKey($lname)) { $byName[$lname] } else { $null }

            $state = 'MISSING'
            if ($have) {
                $state = 'PRESENT'
                if ($att.Checksum -and $have.Checksum -and $att.Checksum -ne $have.Checksum) { $state = 'DIFFERS' }
            }
            switch ($state) {
                'PRESENT' { $stat.Present++ }
                'DIFFERS' { $stat.Differs++ }
                default   { $stat.Missing++ }
            }
            if ($res.Done.ContainsKey($key)) { continue }

            $row = [pscustomobject][ordered]@{
                Key = $key; SourceDocId = $srcId; TargetDocId = $tgtId
                AttachmentId = $att.Id; Name = $att.Name; SizeBytes = $att.Size
                Version = $att.Version; Checksum = $att.Checksum
                Status = $state; Message = ''
                StartedUtc = (Get-Date).ToUniversalTime().ToString('s'); FinishedUtc = ''
            }

            $wanted = ($state -eq 'MISSING') -or ($state -eq 'DIFFERS' -and $ReplaceDiffering)
            if ($Plan -or -not $wanted) {
                if ($state -eq 'DIFFERS' -and -not $ReplaceDiffering) {
                    $row.Message = 'same name, different MD5 - left alone. -ReplaceDiffering sends it as a new version.'
                    Write-VaultLog "$prefix - DIFFERS $($att.Name)" 'WARN'
                }
                $row.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
                Add-VaultResult -Results $res -Row $row
                continue
            }

            $local = $null
            $work  = ''
            try {
                # $c.WhatIf rather than $PSCmdlet.ShouldProcess: $PSCmdlet only exists
                # inside an advanced function, and these are plain functions dot-sourced
                # from the dispatcher - referencing it would be a StrictMode error.
                if (-not $c.WhatIf) {
                    Assert-VaultDiskBudget -Path $c.Scratch -Needed $att.Size -ReserveMB $c.ReserveMB
                    Write-VaultLog "$prefix - $state $($att.Name) ($(Format-VaultBytes $att.Size)) - downloading"
                    # A folder per document. Attachment names repeat across documents far
                    # more than document filenames do - "Cover Letter.pdf" on a hundred
                    # documents is ordinary - so one flat scratch folder means one
                    # document's leftover file is the path the next one tries to create.
                    $work  = New-VaultScratch -Root $c.Scratch -Name $srcId
                    $local = Save-VaultFile -VaultHost $c.SourceHost -ApiVersion $c.Api `
                                -Path "/objects/documents/$srcId/attachments/$($att.Id)/file" `
                                -Destination $work -FileName $att.Name
                    $row.SizeBytes = $local.Size

                    # Vault's ORIGINAL name, not the scrubbed local one. Uploading under a
                    # scrubbed name means the target holds "RE_ [EXTERNAL]..." where the
                    # source has "RE: [EXTERNAL]...", the names never match again, and
                    # every later run sends another copy.
                    $up = Send-VaultDocumentAttachment -VaultHost $c.TargetHost -ApiVersion $c.Api `
                             -DocId $tgtId -LocalPath $local.Path -FileName $local.OriginalName
                    $row.Status  = 'ATTACHED'
                    $row.Message = "attachment $($up.AttachmentId) v$($up.Version)"
                    $moved += $local.Size
                    $stat.Attached++
                    Write-VaultLog "$prefix - OK $($att.Name) attached as $($up.AttachmentId) v$($up.Version) ($(Format-VaultBytes $local.Size))" 'OK'
                }
                else {
                    $row.Status  = 'WHATIF'
                    $row.Message = "would deliver $(Format-VaultBytes $att.Size)"
                    Write-VaultLog "$prefix - WhatIf: would deliver $($att.Name)"
                }
            }
            catch {
                $row.Status = 'ERROR'; $row.Message = "$_"; $stat.Errors++
                Write-VaultLog "$prefix - ERROR on $($att.Name): $_" 'ERROR'
            }
            finally {
                Remove-VaultScratchFile -File $local -Scratch $c.Scratch -Prefix "$prefix -"
                if ($work) { Remove-VaultScratchDir -Path $work }
            }

            $row.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
            Add-VaultResult -Results $res -Row $row

            if ($TestCount -gt 0) {
                $done = if ($Plan) { $stat.Missing } else { $stat.Attached }
                if ($done -ge $TestCount) {
                    Write-VaultLog "TEST: $done after $i document(s) - stopping" 'OK'
                    $stopped = $true
                    break documents
                }
            }
        }
    }

    Save-VaultResults -Results $res
    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog ("source {0}   present {1}   missing {2}   different MD5 {3}   no attachments {4}" -f `
                    $stat.Src, $stat.Present, $stat.Missing, $stat.Differs, $stat.NoAtt)
    if ($Plan) {
        Write-VaultLog "PLAN only - nothing was delivered. $($stat.Missing) attachment(s) would be." 'OK'
        # Errors must be reported in every mode. A plan that failed to reach half the
        # documents is not a plan, and saying only "0 would be delivered" reads as good
        # news rather than as a run that never got off the ground.
        if ($stat.Errors) { Write-VaultLog "$($stat.Errors) document(s) could not be read - the figures above are incomplete" 'ERROR' }
    }
    else {
        Write-VaultLog "Attached $($stat.Attached), $($stat.Errors) failed, $(Format-VaultBytes $moved) transferred" $(if ($stat.Errors) { 'WARN' } else { 'OK' })
    }
    if ($stopped) { Write-VaultLog "TEST run - stopped after $i of $($ids.Count) document(s). NOT the whole set." 'WARN' }
    Write-VaultLog "Results: $($res.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($res.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return $stat.Errors
}

function Invoke-VaultAttachmentsVerify {
    param(
        [Parameter(Mandatory)]$Context,
        [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
        [int]$TestCount = 0,
        [int]$Limit = 0
    )
    $c   = $Context
    $map = $c.Map
    $ids = @($map.Keys)
    if ($Limit -gt 0 -and $ids.Count -gt $Limit) { $ids = @($ids | Select-Object -First $Limit) }
    Write-VaultLog "$($ids.Count) mapped document(s) to check by $Depth"

    # Nothing is skipped on a re-run: the point of a check is the CURRENT state, and a
    # MATCH recorded yesterday says nothing about today.
    if ($c.Workers -gt 1 -and $ids.Count -gt 1 -and $TestCount -le 0) {
        $pairs = @($ids | ForEach-Object { [pscustomobject]@{ Source = $_; Target = $map[$_] } })
        return Invoke-VaultShardedRun -Context $c -Pending $pairs -Workers $c.Workers `
                   -Command @('attachments', 'verify') -LogPattern 'attachments-verify-*.log' `
                   -ResultsName 'attachment-validate-results.csv' -KeyColumn 'Key' `
                   -SuccessStatus 'MATCH' -Verb 'Checked' -ShardKind 'map' `
                   -RowsAreItems $false -ExtraArgs @('-Depth', $Depth)
    }

    $res = New-VaultResults -Path (Join-Path $c.Out 'attachment-validate-results.csv') -KeyColumn 'Key' -Existing $c.Existing

    $stat = @{ Match = 0; Mismatch = 0; MissingOnTarget = 0; MissingOnSource = 0; NoChecksum = 0; Errors = 0 }
    $hashed = [long]0
    $i = 0
    $stopped = $false

    function Get-Md5 {
        param([string]$VaultHostName, [string]$DocId, [string]$AttId, [string]$Name, [long]$Size)
        Assert-VaultDiskBudget -Path $c.Scratch -Needed $Size -ReserveMB $c.ReserveMB
        $work = New-VaultScratch -Root $c.Scratch -Name "$VaultHostName-$DocId"
        $f = $null
        try {
            $f = Save-VaultFile -VaultHost $VaultHostName -ApiVersion $c.Api `
                    -Path "/objects/documents/$DocId/attachments/$AttId/file" `
                    -Destination $work -FileName "$VaultHostName-$AttId-$Name"
            return [pscustomobject]@{ Md5 = (Get-FileHash -LiteralPath $f.Path -Algorithm MD5).Hash; Size = $f.Size }
        }
        finally {
            Remove-VaultScratchFile -File $f -Scratch $c.Scratch
            if ($work) { Remove-VaultScratchDir -Path $work }
        }
    }

    :documents foreach ($srcId in $ids) {
        $i++
        $tgtId  = $map[$srcId]
        $prefix = "[$i/$($ids.Count)] $srcId -> $tgtId"

        try { $srcAtt = @(Get-VaultDocumentAttachment -VaultHost $c.SourceHost -ApiVersion $c.Api -DocId $srcId) }
        catch { Write-VaultLog "$prefix - ERROR listing source: $_" 'ERROR'; $stat.Errors++; continue }
        try { $tgtAtt = @(Get-VaultDocumentAttachment -VaultHost $c.TargetHost -ApiVersion $c.Api -DocId $tgtId) }
        catch { Write-VaultLog "$prefix - ERROR listing target: $_" 'ERROR'; $stat.Errors++; continue }
        if ($srcAtt.Count -eq 0 -and $tgtAtt.Count -eq 0) { continue }

        $byName  = Compare-VaultAttachmentSet -Target $tgtAtt
        $matched = @{}

        foreach ($att in $srcAtt) {
            $lname = $att.Name.ToLowerInvariant()
            $row = [pscustomobject][ordered]@{
                Key = "$srcId`:$($att.Id)"; SourceDocId = $srcId; TargetDocId = $tgtId
                Name = $att.Name
                SourceAttachmentId = $att.Id; TargetAttachmentId = ''
                SourceSize = $att.Size; TargetSize = ''
                SourceMd5 = ''; TargetMd5 = ''; Method = $Depth
                Status = ''; Message = ''
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            }

            if (-not $byName.ContainsKey($lname)) {
                $row.Status = 'MISSING_ON_TARGET'; $stat.MissingOnTarget++
                Write-VaultLog "$prefix $($att.Name) - MISSING_ON_TARGET" 'WARN'
                Add-VaultResult -Results $res -Row $row
                continue
            }
            $have = $byName[$lname]
            $matched[$lname] = $true
            $row.TargetAttachmentId = $have.Id
            $row.TargetSize         = $have.Size

            try {
                if ($Depth -eq 'DEEP') {
                    # Hash what each vault actually hands back rather than trusting either
                    # one's record. Sequential so only one file is ever on disk.
                    $a = Get-Md5 -VaultHostName $c.SourceHost -DocId $srcId -AttId $att.Id  -Name $att.Name -Size $att.Size
                    $b = Get-Md5 -VaultHostName $c.TargetHost -DocId $tgtId -AttId $have.Id -Name $att.Name -Size $have.Size
                    $row.SourceMd5 = $a.Md5; $row.TargetMd5 = $b.Md5
                    $row.SourceSize = $a.Size; $row.TargetSize = $b.Size
                    $hashed += $a.Size + $b.Size
                }
                else {
                    $row.SourceMd5 = $att.Checksum; $row.TargetMd5 = $have.Checksum
                }

                if (-not $row.SourceMd5 -or -not $row.TargetMd5) {
                    $row.Status = 'NO_CHECKSUM'
                    $row.Message = 'a side recorded no MD5 - use DEEP to hash the bytes'
                    $stat.NoChecksum++
                    Write-VaultLog "$prefix $($att.Name) - NO_CHECKSUM" 'WARN'
                }
                elseif ($row.SourceMd5 -ieq $row.TargetMd5) {
                    $row.Status = 'MATCH'; $stat.Match++
                    Write-VaultLog "$prefix $($att.Name) - MATCH $($row.SourceMd5)" 'OK'
                }
                else {
                    # Equal sizes with different digests points at repackaging - Office
                    # files are ZIP containers and re-save with new timestamps and entry
                    # order - whereas different sizes mean the content itself differs.
                    $note = if ($row.SourceSize -eq $row.TargetSize) { "same size $(Format-VaultBytes $row.SourceSize)" }
                            else { "source $(Format-VaultBytes $row.SourceSize) vs target $(Format-VaultBytes $row.TargetSize)" }
                    $row.Status = 'MISMATCH'
                    $row.Message = "$note | source $($row.SourceMd5) target $($row.TargetMd5)"
                    $stat.Mismatch++
                    Write-VaultLog "$prefix $($att.Name) - MISMATCH $note | source $($row.SourceMd5) target $($row.TargetMd5)" 'ERROR'
                }
            }
            catch {
                $row.Status = 'ERROR'; $row.Message = "$_"; $stat.Errors++
                Write-VaultLog "$prefix $($att.Name) - ERROR: $_" 'ERROR'
            }
            Add-VaultResult -Results $res -Row $row

            if ($TestCount -gt 0) {
                $done = $stat.Match + $stat.Mismatch + $stat.NoChecksum
                if ($done -ge $TestCount) {
                    Write-VaultLog "TEST: $done compared after $i document(s) - stopping" 'OK'
                    $stopped = $true
                    break documents
                }
            }
        }

        # The other direction. Missing is reported whichever side it is missing from: a
        # file only on the target may predate the migration, but a check that looked one
        # way would never show it.
        foreach ($t in $tgtAtt) {
            if ($matched.ContainsKey($t.Name.ToLowerInvariant())) { continue }
            $stat.MissingOnSource++
            Add-VaultResult -Results $res -Row ([pscustomobject][ordered]@{
                Key = "$srcId`:extra:$($t.Id)"; SourceDocId = $srcId; TargetDocId = $tgtId
                Name = $t.Name
                SourceAttachmentId = ''; TargetAttachmentId = $t.Id
                SourceSize = ''; TargetSize = $t.Size
                SourceMd5 = ''; TargetMd5 = $t.Checksum; Method = $Depth
                Status = 'MISSING_ON_SOURCE'; Message = 'on the target, no attachment of this name on the source'
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            })
        }
    }

    Save-VaultResults -Results $res
    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog ("{0} compared by {1}" -f ($stat.Match + $stat.Mismatch + $stat.NoChecksum), $Depth)
    Write-VaultLog ("  MATCH              {0}" -f $stat.Match) 'OK'
    if ($stat.Mismatch)        { Write-VaultLog ("  MISMATCH           {0}  - same name, DIFFERENT bytes" -f $stat.Mismatch) 'ERROR' }
    if ($stat.MissingOnTarget) { Write-VaultLog ("  MISSING_ON_TARGET  {0}  - on the source, not the target" -f $stat.MissingOnTarget) 'WARN' }
    if ($stat.MissingOnSource) { Write-VaultLog ("  MISSING_ON_SOURCE  {0}  - on the target, not the source" -f $stat.MissingOnSource) 'WARN' }
    if ($stat.NoChecksum)      { Write-VaultLog ("  NO_CHECKSUM        {0}  - re-run with DEEP" -f $stat.NoChecksum) 'WARN' }
    if ($stat.Errors)          { Write-VaultLog ("  ERROR              {0}" -f $stat.Errors) 'ERROR' }
    if ($Depth -eq 'DEEP')     { Write-VaultLog ("  {0} downloaded and hashed from both vaults" -f (Format-VaultBytes $hashed)) }
    if ($stopped)              { Write-VaultLog "TEST run - stopped after $i of $($ids.Count) document(s). NOT the whole set." 'WARN' }
    if ($stat.Mismatch -eq 0 -and $stat.Errors -eq 0 -and $stat.MissingOnTarget -eq 0 -and $stat.MissingOnSource -eq 0) {
        Write-VaultLog 'Every attachment compared is byte-identical on both vaults.' 'OK'
    }
    Write-VaultLog "Results: $($res.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($res.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return ($stat.Mismatch + $stat.Errors)
}

# ===== VaultKit/Documents.ps1 =====

# Document source files, from one vault into another vault's File Staging.
#
# Ported from Transfer-VaultDocuments.ps1. The shape is deliberately unchanged, because
# every rule below was paid for against a real vault:
#
#   1. GET /objects/documents/{id}/file on the SOURCE, straight to disk. Nothing is
#      written to the source vault's File Staging, so nothing has to be cleaned up there.
#   2. Upload to the TARGET vault's File Staging through a resumable session.
#   3. Delete the local copy.
#
# One file is on local disk at a time, so the disk needed is the size of the largest
# single document, not the size of the set.
#
# This is the opposite choice from the attachment sync, which bypasses File Staging
# entirely - and that is not an inconsistency. An attachment has somewhere to land the
# moment it arrives, so staging it first would only leave litter behind. A document
# source file has no such destination until someone runs the load that consumes it, and
# File Staging is where that load reads from.

# --------------------------------------------------------------------------------------
# Upload: always a resumable session
#
# One code path for every size. A single-part upload is legal because the 5MB minimum
# does not apply to the last part, and a single part is the last part. Parts are read
# from disk a chunk at a time, so a 2GB file never lands in memory.
# --------------------------------------------------------------------------------------

function ConvertTo-VaultStagingPath {
    # A staging path going into a URL PATH has to be escaped per segment - a document
    # called "Q1 Report (final).pdf" is ordinary, and both the space and the parentheses
    # matter. Escaping the whole string would take the separators with it.
    #
    # Only for URL paths. A staging path sent as a form field is escaped by the request
    # itself, and doing it here as well would double-encode it.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)
    $clean = $Path.Replace('\\', '/').Trim('/')
    if (-not $clean) { return '' }
    return (($clean -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}

$script:VaultMadeFolders = @{}

function ConvertTo-VaultStagingName {
    # A Vault document filename is not a path segment. Make it into one.
    #
    # Deliberately NOT an encoding. Base64 would be safe and unreadable, and the
    # readability is the point: someone loading this extract on the other side has to
    # recognise what they are looking at. The exact original is recorded in the results
    # file next to the path it was written to, so nothing is lost by not encoding it -
    # the mapping lives in the manifest, where it can be read.
    #
    # Only what actually breaks is changed, and nothing else, because every character
    # replaced here is one that stops matching what the source calls the file:
    #
    #   / and \   invent path levels that were never created, and the upload fails with
    #             "The parent folder [...] cannot be found". This is the one that got us.
    #   control   characters cannot survive a URL or a filesystem.
    #   trailing  dots and spaces are silently stripped by Windows, so a name ending in
    #             one never matches itself again on the way back.
    #   length    a long name plus /u11013315/wave3/<id>/ can exceed both the local
    #             260-character path limit and Vault's own.
    #
    # : * ? " < > | are left alone. Vault accepts them in a staging path - "re: data
    # protection eligibility" is already there - and replacing them would rename files
    # that work today, so a re-run would upload a second copy under the new name and
    # leave both.
    #
    # Idempotent on purpose: running it over an already converted name returns the same
    # name, so a resumed run looks for what the first run wrote.
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [int]$MaxLength = 150,
        [string]$Fallback = 'unnamed'
    )

    $out = $Name -replace '[\\/]', '_'
    $out = ($out.ToCharArray() | ForEach-Object { if ([int]$_ -lt 32 -or [int]$_ -eq 127) { '_' } else { $_ } }) -join ''
    $out = $out.Trim()
    $out = $out -replace '[\s.]+$', ''

    if ($out.Length -gt $MaxLength) {
        # Truncate the stem, keep the extension: a name that loses its .pdf stops being
        # openable, and the extension is the part a loader keys on.
        $ext = [IO.Path]::GetExtension($out)
        if ($ext.Length -gt 20) { $ext = '' }   # not an extension, just a dot late in a long name
        $keep = $MaxLength - $ext.Length
        if ($keep -lt 1) { $keep = $MaxLength; $ext = '' }
        $out = $out.Substring(0, $keep).TrimEnd() + $ext
    }

    # CON, PRN, AUX, NUL, COM1-9, LPT1-9 are device names on Windows, with or without an
    # extension. A file called NUL.pdf cannot be written to disk at all.
    if ($out -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') { $out = "_$out" }

    if (-not $out) { $out = $Fallback }
    return $out
}

function New-VaultStagingFolder {
    # Create every level, not just the leaf.
    #
    # Vault's Create Folder does NOT create intermediate folders: posting
    # /u123/wave1/87890 in one call fails with "The parent folder [/u123/wave1/] cannot
    # be found" unless each level above already exists. That took out every upload on
    # the first attachment sync run, and this port had reintroduced it - the transfer
    # script it came from never received the fix.
    #
    # Levels are remembered for the run, so sixteen documents under one wave folder
    # create that shared level once rather than sixteen times.
    #
    # A create that fails is still only a warning: on any re-run the folder is already
    # there, and the upload immediately after is the real test - if a level genuinely
    # could not be made, that fails loudly and with Vault's own message.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Path)

    $parts = @($Path.Trim('/') -split '/' | Where-Object { $_ })
    $cur = ''
    foreach ($part in $parts) {
        $cur = $cur + '/' + $part
        if ($script:VaultMadeFolders.ContainsKey($cur)) { continue }
        $script:VaultMadeFolders[$cur] = $true
        try {
            Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api `
                -Method POST -Path '/services/file_staging/items' `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body @{ kind = 'folder'; path = $cur; overwrite = 'false' } | Out-Null
        }
        catch {
            # Expected for levels that already exist, including the target path itself.
            Write-Verbose "Folder $cur not created (likely already there): $_"
        }
    }
}

function Send-VaultStagingPart {
    # One file part, over HttpWebRequest rather than Invoke-WebRequest.
    #
    # Invoke-WebRequest was sent $buf[0..($read-1)], which on a byte[] produces an
    # Object[], not a byte[]. It then stringifies that - so 877KB of binary went up as a
    # much larger text body and Vault rejected it with OPERATION_NOT_ALLOWED: "Unable to
    # upload additional file parts/bytes". Writing an exact byte count straight to the
    # request stream removes the conversion entirely, and matches how the download side
    # already works.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$SessionId,
        [Parameter(Mandatory)][byte[]]$Buffer,
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][int]$PartNumber,
        [int]$MaxRetries = 4
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sid = Get-VaultSessionId -VaultHost $Context.TargetHost -ApiVersion $Context.Api

        $uri = "https://$($Context.TargetHost)/api/$($Context.Api)/services/file_staging/upload/$SessionId"
        $req = [Net.HttpWebRequest]::Create($uri)
        $req.Method           = 'PUT'
        $req.ContentType      = 'application/octet-stream'
        $req.ContentLength    = $Count
        $req.Timeout          = 900000
        $req.ReadWriteTimeout = 900000
        # Accept is a RESTRICTED header on HttpWebRequest - Headers.Add throws
        # "The 'Accept' header must be modified using the appropriate property or
        # method". It has to go through the property. Same family as Content-Type and
        # Content-Length, both already set as properties above. Authorization and the
        # X-VaultAPI-* headers are not restricted, so those are fine via Headers.Add.
        $req.Accept = 'application/json'
        $req.Headers.Add('Authorization', $sid)
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
                if ($json -and (Get-VaultField $json 'responseStatus') -eq 'FAILURE') {
                    $errs = @(Get-VaultField $json 'errors' @())
                    throw 'part ' + $PartNumber + ' rejected -- ' +
                          (($errs | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join '; ')
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

            if ($status -eq 401 -and $attempt -lt $MaxRetries) {
                Write-VaultLog "$($Context.TargetHost) HTTP 401 on part $PartNumber - renewing the session" 'WARN'
                [void](Reset-VaultSession -VaultHost $Context.TargetHost -ApiVersion $Context.Api)
                continue
            }
            if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                $wait = Get-VaultThrottleDelay -Kind 'throttled' -Attempt $attempt -RetryAfter (Get-VaultRetryAfter $_.Exception.Response)
                Write-VaultLog "$($Context.TargetHost) HTTP 429 on part $PartNumber - waiting ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = Get-VaultThrottleDelay -Kind 'transient' -Attempt $attempt -RetryAfter (Get-VaultRetryAfter $_.Exception.Response)
                Write-VaultLog "$($Context.TargetHost) transient error on part $PartNumber (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            throw "part $PartNumber failed (HTTP $status): $($_.Exception.Message) $detail"
        }
    }
    throw "part $PartNumber failed after $MaxRetries attempts"
}

function Send-VaultStagingFile {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$RemotePath,
        [Parameter(Mandatory)][long]$Size,
        [int]$PartSizeMB = 25
    )
    $open = Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api `
                -Method POST -Path '/services/file_staging/upload' `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body @{ path = $RemotePath; size = $Size; overwrite = 'true' }
    $sid = "$(Get-VaultField (Get-VaultField $open 'data' $null) 'id' '')"
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
                Send-VaultStagingPart -Context $Context -SessionId $sid -Buffer $buf -Count $read -PartNumber $part
                $sent += $read
            }
        }
        finally { $fs.Dispose() }
        if ($sent -ne $Size) { throw "uploaded $sent bytes but the session declared $Size" }

        $commit = Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api `
                     -Method POST -Path "/services/file_staging/upload/$sid"
        return [pscustomobject]@{ Parts = $part; Session = $sid; Response = $commit }
    }
    catch {
        # Leave no half-finished session behind - they hold quota and expire slowly.
        try {
            Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api `
                -Method DELETE -Path "/services/file_staging/upload/$sid" | Out-Null
        }
        catch { Write-VaultLog "Could not abort upload session ${sid}: $_" 'WARN' }
        throw
    }
}

# --------------------------------------------------------------------------------------
# The workflow
# --------------------------------------------------------------------------------------

function Invoke-VaultDocumentsStage {
    param(
        [Parameter(Mandatory)]$Context,
        [switch]$Plan,
        [int]$TestCount = 0,
        [int]$Limit = 0
    )
    $c = $Context
    if (-not $c.TargetPath) {
        throw @'
No target staging path is set.

Uploading to the staging ROOT is almost never what is wanted, so this will not guess.
Run `vault probe` against the target vault to get its user folder id and whether your
account is Admin there, then set it in vault.ini:

  [documents]
  path = /u<target user id>/wave1     an Admin gives an absolute path
  path = /wave1                       a non-Admin gives one relative to their folder

Uploading into Inbox is not neutral - it creates Staged documents.
'@
    }

    $ids = @($c.Ids)
    if ($Limit -gt 0 -and $ids.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - examining the first $Limit of $($ids.Count) document(s)" 'WARN'
        $ids = @($ids | Select-Object -First $Limit)
    }
    Write-VaultLog "$($c.SourceHost)  ->  $($c.TargetHost)$($c.TargetPath)"
    Write-VaultLog "$($ids.Count) document(s) to examine"

    $results = New-VaultResults -Path (Join-Path $c.Out 'document-results.csv') `
                   -KeyColumn 'Id' -DoneStatuses @('SUCCESS') -Existing $c.Existing

    # Above one worker this process moves nothing itself: it shards what is still
    # outstanding and supervises. Deliberately not done for -Plan or -WhatIf, where there
    # is nothing to parallelise, nor for -Test, whose whole job is to make five documents
    # easy to follow.
    $pending = @($ids | Where-Object { -not $results.Done.ContainsKey("$_") })
    if ($c.Workers -gt 1 -and $pending.Count -gt 1 -and $TestCount -le 0 -and -not ($Plan -or $c.WhatIf)) {
        return Invoke-VaultShardedRun -Context $c -Pending $pending -Workers $c.Workers `
                   -Command @('documents', 'stage') -LogPattern 'documents-stage-*.log' `
                   -ResultsName 'document-results.csv' -KeyColumn 'Id' `
                   -SuccessStatus 'SUCCESS' -Verb 'Moved' -ReportRenames `
                   -ExtraArgs @('-TargetPath', "`"$($c.TargetPath)`"")
    }

    $i = 0; $done = 0; $bad = 0; $renamed = 0; $moved = [long]0
    foreach ($id in $ids) {
        if ($results.Done.ContainsKey("$id")) { continue }
        if ($TestCount -gt 0 -and $done -ge $TestCount) {
            Write-VaultLog "-Test $TestCount reached - stopping with $done document(s) delivered" 'WARN'
            break
        }
        $i++
        $prefix = "[$i/$($ids.Count)] doc $id"
        $record = [ordered]@{
            Id = $id; Name = ''; StagedName = ''; Renamed = $false; SizeBytes = 0; DeclaredBytes = 0; TargetPath = ''; Parts = 0
            Status = ''; Message = ''
            StartedUtc = (Get-Date).ToUniversalTime().ToString('s'); FinishedUtc = ''
        }
        $local = $null
        $work  = ''
        try {
            # Size first, so the disk check happens before anything is downloaded.
            $meta = Invoke-VaultApi -VaultHost $c.SourceHost -ApiVersion $c.Api -Method GET -Path "/objects/documents/$id"
            $doc  = Get-VaultField $meta 'document' $null
            $size = [long]"$(Get-VaultField $doc 'size__v' 0)"
            $record.Name = "$(Get-VaultField $doc 'name__v' '')"

            Assert-VaultDiskBudget -Path $c.Scratch -Needed $size -ReserveMB $c.ReserveMB

            # Every document gets its own folder named for its SOURCE id. Two documents
            # called "Cover Letter.pdf" are common; one overwriting the other after a
            # 12-hour transfer is not something you want to discover afterwards.
            $folder = $c.TargetPath.TrimEnd('/') + '/' + $id

            if ($Plan -or $c.WhatIf) {
                $record.TargetPath = $folder + '/'
                $record.SizeBytes  = $size
                $record.Status     = 'PLAN'
                $record.Message    = "would move $(Format-VaultBytes $size)"
                Write-VaultLog "$prefix - would move $(Format-VaultBytes $size) to $folder/"
            }
            else {
                Write-VaultLog "$prefix - downloading $(Format-VaultBytes $size)"
                # A folder per document. Filenames repeat constantly in a real vault -
                # a dozen documents called "Description of Manufacturing Process and
                # Process Controls" is normal - so a single flat scratch folder means
                # one document's leftover file is the path the next one tries to create,
                # and a delete that lost a race to a virus scanner takes the next
                # document down with it.
                $work  = New-VaultScratch -Root $c.Scratch -Name $id
                $local = Save-VaultFile -VaultHost $c.SourceHost -ApiVersion $c.Api `
                             -Path "/objects/documents/$id/file" -Destination $work
                $record.SizeBytes     = $local.Size
                $record.DeclaredBytes = $size
                $record.Name          = $local.OriginalName

                # A short read is the failure mode with no symptom: the file uploads,
                # Vault accepts it, and nobody finds out until someone opens it. Warned
                # rather than failed, because size__v is not yet proven to equal the
                # source file length for every document type - both numbers are recorded
                # so the answer is in the results rather than in someone's memory.
                if ($size -gt 0 -and $local.Size -ne $size) {
                    $record.Message = "Vault declared $size bytes, $($local.Size) arrived"
                    Write-VaultLog "$prefix - SIZE $($record.Message)" 'WARN'
                }
                if ($local.Size -eq 0) {
                    throw "the source file came back empty (Vault declared $size bytes)"
                }

                # Vault's own name, with path separators alone made safe. The local
                # scrub is far broader - it strips every character Windows forbids - and
                # using that here would rename files for reasons the target does not
                # share.
                $stagedName = ConvertTo-VaultStagingName $local.OriginalName
                $record.StagedName = $stagedName
                # Case-sensitive. PowerShell compares strings case-insensitively by
                # default, and a name differing only in case is still a different file.
                $record.Renamed = ($stagedName -cne $local.OriginalName)
                if ($record.Renamed) {
                    $renamed++
                    # Said out loud, in the results and the log. A file quietly landing
                    # under a name nobody chose is how "it is not there" gets reported
                    # about something that is.
                    Write-VaultLog "$prefix - written as '$stagedName' (source name is not a legal path segment)" 'WARN'
                }
                $remote = $folder + '/' + $stagedName
                $record.TargetPath = $remote
                New-VaultStagingFolder -Context $c -Path $folder

                Write-VaultLog "$prefix - uploading to $remote"
                $up = Send-VaultStagingFile -Context $c -LocalPath $local.Path -RemotePath $remote `
                          -Size $local.Size -PartSizeMB $c.PartSizeMB
                $record.Parts  = $up.Parts
                $record.Status = 'SUCCESS'
                $moved += $local.Size
                $done++
                Write-VaultLog "$prefix - OK ($($local.Name), $(Format-VaultBytes $local.Size), $($up.Parts) part(s))" 'OK'
            }
        }
        catch {
            $record.Status  = 'ERROR'
            $record.Message = "$_"
            $bad++
            Write-VaultLog "$prefix - ERROR: $_" 'ERROR'
        }
        finally {
            Remove-VaultScratchFile -File $local -Scratch $c.Scratch -Prefix "$prefix -"
            if ($work) { Remove-VaultScratchDir -Path $work }
        }
        $record.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
        Add-VaultResult -Results $results -Row ([pscustomobject]$record)
    }

    # The tail: Add-VaultResult writes on a cadence, so the last rows are in memory.
    Save-VaultResults -Results $results
    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "Moved $done document(s), $bad failed, $(Format-VaultBytes $moved) transferred" $(if ($bad) { 'WARN' } else { 'OK' })
    if ($renamed) {
        Write-VaultLog "$renamed document(s) were written under a changed name - the rows where Name and StagedName differ" 'WARN'
    }
    Write-VaultLog "Results: $($results.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($results.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return $bad
}

# --------------------------------------------------------------------------------------
# The validator
#
# A separate command, run when the operator chooses to run it - never chained onto the
# end of a transfer. A check that only ever runs as the last step of the thing it is
# checking cannot be re-run against a finished migration, cannot be run by someone other
# than whoever did the transfer, and stops running at exactly the moment the transfer
# fails - which is when it matters most.
# --------------------------------------------------------------------------------------

function Get-VaultStagingItems {
    # The files directly inside one staging folder. A folder that does not exist is not
    # an error here - it is the answer, and the caller reports it as missing.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Path)
    $items = @()
    $next  = "/services/file_staging/items/$(ConvertTo-VaultStagingPath $Path)?recursive=false&limit=1000"
    while ($next) {
        $r = Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api -Method GET -Path $next
        foreach ($d in @(Get-VaultField $r 'data' @())) {
            if ("$(Get-VaultField $d 'kind' '')" -ne 'file') { continue }
            $items += [pscustomobject]@{
                Name = "$(Get-VaultField $d 'name' '')"
                Size = [long]"$(Get-VaultField $d 'size' 0)"
                Path = "$(Get-VaultField $d 'path' '')"
            }
        }
        $next = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }
    return $items
}

function Get-VaultStagedDocumentIds {
    # What is on the target, according to the target - not according to our own results
    # file. Each per-document folder under the wave path is named for its SOURCE document
    # id, which is what makes this answerable in one listing.
    #
    # recursive=false on purpose: this wants the folder names, and enumerating every file
    # inside 15,000 of them to count the folders would be thousands of pages of response
    # to answer a question the folder names already answer.
    param([Parameter(Mandatory)]$Context)
    $ids = New-Object System.Collections.ArrayList
    $odd = New-Object System.Collections.ArrayList
    $next = "/services/file_staging/items/$(ConvertTo-VaultStagingPath $Context.TargetPath)?recursive=false&limit=1000"
    while ($next) {
        $r = Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api -Method GET -Path $next
        foreach ($d in @(Get-VaultField $r 'data' @())) {
            $name = "$(Get-VaultField $d 'name' '')"
            if ("$(Get-VaultField $d 'kind' '')" -ne 'folder') {
                if ($name) { [void]$odd.Add($name) }
                continue
            }
            if ($name -match '^\d+$') { [void]$ids.Add($name) }
            elseif ($name) { [void]$odd.Add($name) }
        }
        $next = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }
    if ($odd.Count) {
        Write-VaultLog "$($odd.Count) item(s) under $($Context.TargetPath) are not document folders: $(($odd | Select-Object -First 5) -join ', ')" 'WARN'
    }
    return @($ids)
}

function Invoke-VaultDocumentsList {
    # How much is already on the target, and whether it looks right.
    param([Parameter(Mandatory)]$Context)
    $c = $Context
    if (-not $c.TargetPath) { throw 'No target staging path is set. See [documents] path in the config.' }
    Write-VaultLog "$($c.TargetHost)$($c.TargetPath)"

    $ids = Get-VaultStagedDocumentIds -Context $c
    Write-VaultLog "$($ids.Count) document folder(s) on the target" 'OK'
    if (-not $ids.Count) { return 0 }

    # Now the files, which needs the recursive listing. Reported per document so a folder
    # holding none - a transfer that made the folder and then failed - is visible rather
    # than averaged away.
    # Only files inside the document folders are counted. The wave path may hold plenty
    # that is not ours - Inbox, other waves, anything a person put there - and folding
    # that into the totals reports someone else's 8,000 files as this migration's work.
    $known = @{}
    foreach ($i in $ids) { $known["$i"] = $true }

    $files = 0; $bytes = [long]0; $skipped = 0
    $perDoc = @{}
    $next = "/services/file_staging/items/$(ConvertTo-VaultStagingPath $c.TargetPath)?recursive=true&limit=1000"
    while ($next) {
        $r = Invoke-VaultApi -VaultHost $c.TargetHost -ApiVersion $c.Api -Method GET -Path $next
        foreach ($d in @(Get-VaultField $r 'data' @())) {
            if ("$(Get-VaultField $d 'kind' '')" -ne 'file') { continue }
            $path = "$(Get-VaultField $d 'path' '')"
            $rel  = $path.Substring([math]::Min($path.Length, $c.TargetPath.TrimEnd('/').Length)).Trim('/')
            $docId = ($rel -split '/')[0]
            if (-not $docId -or -not $known.ContainsKey($docId)) { $skipped++; continue }
            $files++
            $bytes += [long]"$(Get-VaultField $d 'size' 0)"
            $perDoc[$docId] = 1 + [int]$perDoc[$docId]
        }
        $next = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    $empty = @($ids | Where-Object { -not $perDoc.ContainsKey($_) })
    $multi = @($perDoc.Keys | Where-Object { $perDoc[$_] -gt 1 })

    Write-VaultLog "$files file(s) in those folders, $(Format-VaultBytes $bytes)" 'OK'
    if ($skipped) {
        Write-VaultLog "$skipped file(s) under $($c.TargetPath) are outside the document folders and were not counted"
    }
    if ($empty.Count) {
        Write-VaultLog "$($empty.Count) folder(s) hold no file - a transfer made the folder and did not finish: $(($empty | Select-Object -First 5) -join ', ')" 'WARN'
    }
    if ($multi.Count) {
        Write-VaultLog "$($multi.Count) folder(s) hold more than one file - an earlier run landed a different filename: $(($multi | Select-Object -First 5) -join ', ')" 'WARN'
    }
    Write-VaultLog 'Check these with: documents verify -Staged'
    return 0
}

function Invoke-VaultDocumentsVerify {
    param(
        [Parameter(Mandatory)]$Context,
        [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
        [int]$TestCount = 0,
        [int]$Limit = 0,
        [switch]$Staged
    )
    $c = $Context
    if (-not $c.TargetPath) { throw 'No target staging path is set. See [documents] path in the config.' }

    if ($Staged) {
        # Check what is actually there, rather than what was asked for. Verifying the
        # whole input list after moving part of it reports every document not yet sent
        # as MISSING_ON_TARGET, which buries the real failures in thousands of rows
        # saying nothing more than "not done yet".
        $ids = Get-VaultStagedDocumentIds -Context $c
        Write-VaultLog "-Staged: checking the $($ids.Count) document(s) on the target, not the $(@($c.Ids).Count) in the id list"
        if (-not $ids.Count) { Write-VaultLog "Nothing is staged under $($c.TargetPath)" 'WARN'; return 0 }
    }
    else { $ids = @($c.Ids) }
    if ($Limit -gt 0 -and $ids.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - checking the first $Limit of $($ids.Count) document(s)" 'WARN'
        $ids = @($ids | Select-Object -First $Limit)
    }
    Write-VaultLog "$($c.SourceHost)  vs  $($c.TargetHost)$($c.TargetPath)"
    if ($Depth -eq 'FAST') {
        # Said plainly rather than left to be discovered: File Staging's listing returns
        # kind, name, size and modified date, and no checksum of any kind. FAST therefore
        # compares sizes, which catches a truncated or absent file and nothing subtler.
        Write-VaultLog 'FAST: File Staging reports no checksum, so this compares NAME and SIZE only.' 'WARN'
        Write-VaultLog 'Use DEEP to download both copies and compare the bytes.' 'WARN'
    }
    Write-VaultLog "$($ids.Count) document(s) to check ($Depth)"

    # Sharded the same way the transfer is, and for a stronger reason: DEEP downloads
    # BOTH copies of every document, so a full pass moves twice the bytes the migration
    # did. Run sequentially that takes longer than the transfer it is checking, and a
    # check that costs more than the work is a check people skip.
    #
    # Safer to parallelise than the transfer, too - every call here is a read, on both
    # sides. The ids are resolved once, here, and handed to the workers as a shard file,
    # so -Staged lists the target once rather than once per worker.
    if ($c.Workers -gt 1 -and $ids.Count -gt 1 -and $TestCount -le 0) {
        if ($Depth -eq 'DEEP') {
            # Each worker holds a source copy and a target copy at once, and the disk
            # check each one makes knows nothing about its siblings. Eight workers is
            # therefore up to sixteen files on disk, not two.
            Write-VaultLog "DEEP across $($c.Workers) worker(s) holds up to $($c.Workers * 2) files on disk at once" 'WARN'
        }
        return Invoke-VaultShardedRun -Context $c -Pending $ids -Workers $c.Workers `
                   -Command @('documents', 'verify') -LogPattern 'documents-verify-*.log' `
                   -ResultsName 'document-validate-results.csv' -KeyColumn 'Id' `
                   -SuccessStatus 'MATCH' -Verb 'Checked' `
                   -ExtraArgs @('-Depth', $Depth, '-TargetPath', "`"$($c.TargetPath)`"")
    }

    $results = New-VaultResults -Path (Join-Path $c.Out 'document-validate-results.csv') `
                   -KeyColumn 'Id' -DoneStatuses @() -Existing $c.Existing

    $i = 0; $checked = 0; $bad = 0
    foreach ($id in $ids) {
        if ($TestCount -gt 0 -and $checked -ge $TestCount) {
            Write-VaultLog "-Test $TestCount reached - stopping after $checked document(s)" 'WARN'
            break
        }
        $i++
        $prefix = "[$i/$($ids.Count)] doc $id"
        $folder = $c.TargetPath.TrimEnd('/') + '/' + $id
        $row = [ordered]@{
            # Seeded with the folder so a document that never arrived still records
            # where it was looked for. Replaced with the file's full path the moment one
            # is found, which is what `stage` writes and what can be pasted into a
            # staging listing or a load.
            # Renamed starts blank, not False. Vault leaves filename__v empty for some
            # documents, and with nothing to compare against, "no" is a claim this cannot
            # make - blank says so, where False would assert it.
            Id = $id; Name = ''; Title = ''; StagedName = ''; Renamed = ''; SourceBytes = 0; TargetBytes = 0; TargetPath = $folder
            SourceMd5 = ''; TargetMd5 = ''; Method = $Depth; Status = ''; Message = ''
        }
        $srcFile = $null; $tgtFile = $null; $work = ''
        try {
            $srcName = ''; $srcTitle = ''; $srcSize = [long]0; $haveSource = $true
            try {
                $meta = Invoke-VaultApi -VaultHost $c.SourceHost -ApiVersion $c.Api -Method GET -Path "/objects/documents/$id"
                $doc  = Get-VaultField $meta 'document' $null
                # filename__v only. name__v is the document TITLE - "Description of
                # Manufacturing Process and Process Controls" against a file called
                # bpr-common-ia-04867.pdf - and falling back to it put a title in a
                # column that is compared against a filename, so almost every document
                # looked renamed. Blank is the honest answer when Vault reports no
                # filename, and the checks below skip the comparison rather than invent
                # one.
                $srcName  = "$(Get-VaultField $doc 'filename__v' '')"
                $srcTitle = "$(Get-VaultField $doc 'name__v' '')"
                $srcSize = [long]"$(Get-VaultField $doc 'size__v' 0)"
            }
            catch { $haveSource = $false; $row.Message = "source: $_" }
            $row.Name        = $srcName
            $row.Title       = $srcTitle
            $row.SourceBytes = $srcSize

            # NOT $staged: PowerShell variable names are case-insensitive, so a local
            # $staged and the -Staged parameter are one variable. Assigning the folder
            # listing to it threw "Cannot convert System.Object[] to SwitchParameter" on
            # every single document, the moment -Staged was added.
            $onTarget = @()
            try { $onTarget = @(Get-VaultStagingItems -Context $c -Path $folder) }
            catch { $onTarget = @() }

            if (-not $haveSource) {
                $row.Status = 'MISSING_ON_SOURCE'
                if ($onTarget.Count) {
                    $row.TargetBytes = $onTarget[0].Size
                    $row.TargetPath  = $onTarget[0].Path
                    if (-not $row.Name) { $row.Name = $onTarget[0].Name }
                }
                Write-VaultLog "$prefix - MISSING_ON_SOURCE" 'ERROR'
            }
            elseif (-not $onTarget.Count) {
                $row.Status  = 'MISSING_ON_TARGET'
                $row.Message = "nothing in $folder"
                Write-VaultLog "$prefix - MISSING_ON_TARGET ($folder is empty or absent)" 'ERROR'
            }
            else {
                # One file per folder is what the transfer writes. More than one means a
                # re-run under a changed filename, and reporting the first silently would
                # hide it.
                if ($onTarget.Count -gt 1) {
                    $row.Message = "$($onTarget.Count) files in ${folder}: " + (($onTarget | ForEach-Object { $_.Name }) -join ', ')
                }
                # The FOLDER identifies the document - it is named for the source id,
                # and the transfer writes one file into it. So the file is chosen by
                # being the one that is there, not by its name.
                #
                # Matching on name instead made correctness depend on reproducing the
                # sanitiser exactly: change how an illegal character is replaced and
                # every file written by an earlier run stops matching, then falls
                # through to "the first one" and is silently checked anyway. The name is
                # still reported, and a difference is still flagged - it just no longer
                # decides anything.
                $wanted = ConvertTo-VaultStagingName $srcName
                if ($onTarget.Count -eq 1) { $match = $onTarget[0] }
                else {
                    $match = @($onTarget | Where-Object { $_.Name -eq $wanted }) | Select-Object -First 1
                    if (-not $match) {
                        $row.Status  = 'AMBIGUOUS'
                        $row.Message = "$($onTarget.Count) files in ${folder} and none named '$wanted': " +
                                       (($onTarget | ForEach-Object { $_.Name }) -join ', ')
                        Write-VaultLog "$prefix - AMBIGUOUS $($row.Message)" 'ERROR'
                        $bad++
                        $checked++
                        Add-VaultResult -Results $results -Row ([pscustomobject]$row)
                        continue
                    }
                }
                $row.TargetBytes = $match.Size
                $row.TargetPath  = $match.Path
                $row.StagedName  = $match.Name
                if ($srcName) {
                    $row.Renamed = ($match.Name -cne $srcName)
                    if ($row.Renamed) {
                        $row.Message = (@($row.Message, "source calls it '$srcName'") | Where-Object { $_ }) -join ' | '
                    }
                }

                if ($Depth -eq 'DEEP') {
                    Assert-VaultDiskBudget -Path $c.Scratch -Needed ($srcSize * 2) -ReserveMB $c.ReserveMB
                    $work = New-VaultScratch -Root $c.Scratch -Name $id
                    $srcFile = Save-VaultFile -VaultHost $c.SourceHost -ApiVersion $c.Api `
                                   -Path "/objects/documents/$id/file" -Destination $work `
                                   -FileName ('source-' + (ConvertTo-VaultStagingName $srcName))
                    $tgtFile = Save-VaultFile -VaultHost $c.TargetHost -ApiVersion $c.Api `
                                   -Path "/services/file_staging/items/content/$(ConvertTo-VaultStagingPath $match.Path)" `
                                   -Destination $work -FileName ('staged-' + (ConvertTo-VaultStagingName $match.Name))
                    $row.SourceMd5   = (Get-FileHash -LiteralPath $srcFile.Path -Algorithm MD5).Hash
                    $row.TargetMd5   = (Get-FileHash -LiteralPath $tgtFile.Path -Algorithm MD5).Hash
                    $row.SourceBytes = $srcFile.Size
                    $row.TargetBytes = $tgtFile.Size

                    if ($row.SourceMd5 -ieq $row.TargetMd5) {
                        $row.Status = 'MATCH'
                        Write-VaultLog "$prefix - MATCH $($row.SourceMd5)" 'OK'
                    }
                    else {
                        $row.Status  = 'MISMATCH'
                        $row.Message = "source $($row.SourceBytes) B / $($row.SourceMd5), target $($row.TargetBytes) B / $($row.TargetMd5)"
                        Write-VaultLog "$prefix - MISMATCH $($row.Message)" 'ERROR'
                    }
                }
                else {
                    if ($srcSize -gt 0 -and $match.Size -eq $srcSize) {
                        $row.Status = 'MATCH'
                        Write-VaultLog "$prefix - MATCH $($match.Name) ($(Format-VaultBytes $match.Size), size only)" 'OK'
                    }
                    elseif ($srcSize -le 0) {
                        $row.Status  = 'UNKNOWN'
                        $row.Message = 'source recorded no size - use DEEP'
                        Write-VaultLog "$prefix - UNKNOWN (source recorded no size, use DEEP)" 'WARN'
                    }
                    else {
                        $row.Status  = 'MISMATCH'
                        $row.Message = "source $srcSize B, target $($match.Size) B"
                        Write-VaultLog "$prefix - MISMATCH $($row.Message)" 'ERROR'
                    }
                }
            }
        }
        catch {
            $row.Status  = 'ERROR'
            $row.Message = "$_"
            Write-VaultLog "$prefix - ERROR: $_" 'ERROR'
        }
        finally {
            Remove-VaultScratchFile -File $srcFile -Scratch $c.Scratch -Prefix "$prefix -"
            Remove-VaultScratchFile -File $tgtFile -Scratch $c.Scratch -Prefix "$prefix -"
            if ($work) { Remove-VaultScratchDir -Path $work }
        }
        if ($row.Status -notin @('MATCH')) { $bad++ }
        $checked++
        Add-VaultResult -Results $results -Row ([pscustomobject]$row)
    }

    # The tail: Add-VaultResult writes on a cadence, so the last rows are in memory.
    Save-VaultResults -Results $results
    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "Checked $checked document(s), $bad not matching" $(if ($bad) { 'WARN' } else { 'OK' })
    Write-VaultLog "Results: $($results.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($results.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return $bad
}

# ===== VaultKit/Submissions.ps1 =====

# RIM Submissions Archive: import dossiers that are already on File Staging.
#
# Nothing is moved, downloaded or uploaded. Each dossier is imported from where it
# already sits, so the whole workflow touches one vault - the target - and never puts a
# byte on the workstation beyond its own log and results file.
#
# Lifted from legacy/submissions-import/Import-VaultSubmissions.ps1, which carried its
# own config file, its own auth, its own session handling and its own logging. All four
# are now the kit's: [vault] target for the host, `vault login` and .vault-session.json
# for the session, Invoke-VaultApi for retry and throttling, Write-VaultLog for output.
# The standalone script kept a SessionId you pasted into config.ini by hand; there is no
# equivalent here on purpose, because a session that can only be refreshed by editing a
# file is a run that dies at the first expiry.

function Get-VaultSubmissionDossier {
    # The dossiers under one application folder: one child per submission.
    #
    # Not Get-VaultStagingItems, which is right next door and does almost this - it keeps
    # only kind 'file', because the document transfer stages files. A submission dossier
    # is usually a FOLDER (0000, 0001, ...) and sometimes an archive, so filtering to
    # files would return nothing at all on a normal Submissions Archive layout.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Path,
        [string[]]$ArchiveSuffix = @('.zip', '.tar.gz', '.tgz')
    )
    $out     = New-Object System.Collections.ArrayList
    $skipped = New-Object System.Collections.ArrayList
    $next = "/services/file_staging/items/$(ConvertTo-VaultStagingPath $Path)?recursive=false&limit=500"
    while ($next) {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path $next
        foreach ($d in @(Get-VaultField $r 'data' @())) {
            $name = "$(Get-VaultField $d 'name' '')"
            if (-not $name) { continue }
            # VFMTemp is Vault's OWN scratch folder and it sits right beside the
            # dossiers. It is a folder, so every rule below would take it for a
            # submission, fail to resolve a submission__v called VFMTemp, and write an
            # ERROR row on every run in every vault that has one. Dotted names go the
            # same way for the same reason.
            if ($name -ieq 'VFMTemp' -or $name.StartsWith('.')) { continue }
            $kind = "$(Get-VaultField $d 'kind' 'file')"
            if ($kind -ne 'folder') {
                $isArchive = $false
                foreach ($s in $ArchiveSuffix) { if ($name.ToLowerInvariant().EndsWith($s)) { $isArchive = $true; break } }
                # export_results.csv and any other loose file beside the dossiers is
                # not a submission. Named rather than skipped in silence: a folder full
                # of loose files is a path pointed one level too deep, and
                # export_results.csv specifically is the mapping sheet Bulk Submission
                # Export leaves behind - worth knowing is there.
                if (-not $isArchive) { [void]$skipped.Add($name); continue }
            }
            # The base name is the submission number: the folder name as-is, or the
            # archive name with its suffix removed. It is what the VQL lookup keys on.
            $base = $name
            if ($kind -ne 'folder') { $base = $name -replace '\.tar\.gz$|\.tgz$|\.zip$', '' }
            [void]$out.Add([pscustomobject]@{
                Name = $name
                Base = $base
                Kind = $kind
                Path = "$(Get-VaultField $d 'path' '')"
                Size = [long]"$(Get-VaultField $d 'size' 0)"
            })
        }
        $next = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    if ($skipped.Count) {
        Write-VaultLog "$($skipped.Count) loose file(s) beside the dossiers, not treated as submissions: $((@($skipped | Select-Object -First 5)) -join ', ')$(if ($skipped.Count -gt 5) { ', ...' })"
        if (@($skipped | Where-Object { $_ -ieq 'export_results.csv' }).Count) {
            # The legacy importer read this off staging and preferred it to the VQL
            # lookup. This port resolves by folder name and application only, so a
            # mapping sheet sitting here is NOT being consulted - say so rather than
            # let it look like it was.
            Write-VaultLog 'export_results.csv is present. This command does NOT read it - submissions resolve by folder name + application via VQL.' 'WARN'
        }
    }
    return @($out)
}

$script:VaultAppIdResolved = $false
$script:VaultAppId         = ''
$script:VaultAppErr        = $null

function Find-VaultApplicationMatch {
    # Which field of the application object actually holds the staging folder name.
    #
    # The configured field is a guess about somebody else's object model, and when it is
    # wrong the run fails on every dossier with the same error. Rather than make an
    # operator go and read the model, ask the vault: read the object's metadata, take its
    # String fields - only a String can hold an alphanumeric like e157135 or 068582 - and
    # look for one whose value equals the key.
    #
    # Partial matches are collected separately and reported but never used. A field that
    # merely CONTAINS the key is a lead for a human, not a match to act on.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Key,
        [string]$Object = 'application__v',
        [int]$MaxPages = 20
    )
    $meta   = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path "/metadata/vobjects/$Object"
    $obj    = Get-VaultField $meta 'object' $meta
    $fields = @(Get-VaultField $obj 'fields' @())
    if ($fields.Count -eq 0) { throw "Could not read the fields of $Object via /metadata/vobjects/$Object" }

    $names = @('id') + @($fields | Where-Object { "$(Get-VaultField $_ 'type' '')" -eq 'String' } |
                         ForEach-Object { Get-VaultField $_ 'name' '' } | Where-Object { $_ })
    $names = @($names | Select-Object -Unique)

    $exactField = ''; $exactId = ''
    $partials   = New-Object System.Collections.ArrayList
    $scanned    = 0
    $pages      = 0
    $truncated  = $false

    # Paged, unlike the tool this came from, which read the first page and stopped - so
    # in a vault with more applications than fit one page the scan could miss the very
    # record it was looking for and report that no field matched.
    $vql  = "SELECT $($names -join ', ') FROM $Object"
    $path = '/query'
    $body = "q=$([Uri]::EscapeDataString($vql))"
    while ($path) {
        $pages++
        if ($pages -gt $MaxPages) { $truncated = $true; break }
        $r = if ($pages -eq 1) {
                Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
                    -Path $path -ContentType 'application/x-www-form-urlencoded' -Body $body
             } else {
                Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path $path
             }
        foreach ($row in @(Get-VaultField $r 'data' @())) {
            $scanned++
            foreach ($f in $names) {
                if ($f -eq 'id') { continue }
                $v = "$(Get-VaultField $row $f '')"
                if (-not $v) { continue }
                if ($v -ieq $Key) {
                    if (-not $exactField) { $exactField = $f; $exactId = "$(Get-VaultField $row 'id' '')" }
                }
                elseif ($v -match [regex]::Escape($Key)) {
                    [void]$partials.Add([pscustomobject]@{ Field = $f; Value = $v })
                }
            }
        }
        if ($exactField) { break }
        $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    return [pscustomobject]@{
        ExactField = $exactField; ExactId = $exactId; Partials = @($partials)
        Scanned = $scanned; Fields = ($names.Count - 1); Truncated = $truncated
    }
}

function Get-VaultApplicationId {
    # The application folder name (e157135) as a record id, resolved once per run.
    #
    # Cached including the FAILURE. Without that, the first submission reports the real
    # cause and every one after it reports whatever the second query happened to say,
    # so a run of four hundred ends with one true error buried under 399 misleading ones.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Key,
        [string]$Object = 'application__v',
        [string]$KeyField = 'name__v'
    )
    if ($script:VaultAppIdResolved) {
        if ($script:VaultAppErr) { throw $script:VaultAppErr }
        return $script:VaultAppId
    }
    $script:VaultAppIdResolved = $true
    $script:VaultAppId = ''; $script:VaultAppErr = $null
    if (-not $Key) { return '' }

    try {
        $k   = $Key.Replace("'", "\'")
        $vql = "SELECT id FROM $Object WHERE $KeyField = '$k'"
        $rows = @()
        try {
            $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
                    -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
                    -Body "q=$([Uri]::EscapeDataString($vql))"
            $rows = @(Get-VaultField $r 'data' @())
        }
        catch {
            # A field that does not exist on this vault fails the QUERY, not just the
            # match - so the fast path has to survive its own configuration being wrong,
            # or the scan below never runs and the operator is told the application does
            # not exist when what does not exist is the field.
            Write-VaultLog "Query on '$KeyField' failed ($_) - falling back to a field scan" 'WARN'
            $rows = @()
        }
        if ($rows.Count -eq 1) {
            $script:VaultAppId = "$(Get-VaultField $rows[0] 'id' '')"
            Write-VaultLog "Application '$Key' is $Object $($script:VaultAppId)" 'OK'
            return $script:VaultAppId
        }
        if ($rows.Count -gt 1) {
            # Genuine ambiguity. Scanning would not help - the vault has already given a
            # clear answer and it is "more than one", which only a human can narrow.
            throw "$($rows.Count) $Object records match $KeyField = '$Key'. Set [submissions] applicationkeyfield to something that identifies one."
        }

        # Zero rows on the configured field is a guess that was wrong, not a dead end.
        # Ask the vault which field actually holds it rather than making someone go and
        # read the object model.
        Write-VaultLog "No $Object where $KeyField = '$Key' - scanning $Object string fields for it" 'WARN'
        $m = Find-VaultApplicationMatch -Context $Context -Key $Key -Object $Object
        if ($m.ExactField) {
            $script:VaultAppId = $m.ExactId
            Write-VaultLog "Application '$Key' is $Object $($m.ExactId), found on field '$($m.ExactField)'" 'OK'
            Write-VaultLog "Set [submissions] applicationkeyfield = $($m.ExactField) to skip this scan next time." 'WARN'
            return $script:VaultAppId
        }

        $hint = ''
        if ($m.Partials.Count) {
            $flds = (@($m.Partials | ForEach-Object { $_.Field }) | Select-Object -Unique) -join ', '
            $hint = " Fields that merely contain it: $flds - a partial match is a lead, not an answer."
        }
        if ($m.Truncated) { $hint += ' The scan stopped at the page cap, so it did not read every record.' }
        throw "Could not find $Object '$Key' by field '$KeyField', nor by scanning $($m.Fields) string field(s) across $($m.Scanned) record(s).$hint Check [submissions] path names a real application folder."
    }
    catch { $script:VaultAppErr = "$_"; throw }
}

function Get-VaultSubmissionSerial {
    # The serial number out of a submission name, from either side of the join.
    #
    #   20130724 Serial No. 0156 Safety Report   -> 0156
    #   20040331 SBM SN 0000 Original IND Sub    -> 0000
    #   20140219 PAM SN 0161 Updated Investigato -> 0161
    #
    # This is the only part of the string both sides agree on. The leading date does not
    # survive the round trip - staged folders were seen a day, three days and ten days
    # off the record they belong to - and the descriptive tail carries typos and
    # substituted punctuation. The serial is what a submission actually IS.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Name)
    # Leading \b only. Without it an 'sn' inside a word followed by a number reads as a
    # serial, and a WRONG serial matches a real record - worse than no match, because no
    # match stops the dossier and a wrong one imports it onto somebody else's submission.
    #
    # A trailing \b cannot be used: 'Serial No.' ends in a period and is followed by a
    # space, and two non-word characters have no boundary between them - so it silently
    # matched nothing at all, which the unit check above caught.
    if ($Name -match '(?i)\b(?:serial\s*no\.?|sn)\s*[:#-]?\s*(\d{3,5})') { return $Matches[1] }
    return ''
}

function Get-VaultSubmissionIndex {
    # Every submission in the application, once, indexed for local matching.
    #
    # One query instead of one per dossier: 161 round trips became 1. That is not only
    # faster, it is what makes serial matching possible at all - VQL forbids a leading
    # wildcard, so "find the record whose name contains 0156" cannot be asked of the
    # vault and has to be answered here.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$ApplicationId,
        [string]$ApplicationRefField = 'application__v'
    )
    $vql  = "SELECT id, name__v FROM submission__v WHERE $ApplicationRefField = '$ApplicationId'"
    $rows = @(Invoke-VaultQuery -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Vql $vql)

    $byName   = @{}
    $bySerial = @{}
    foreach ($r in $rows) {
        $id   = "$(Get-VaultField $r 'id' '')"
        $name = "$(Get-VaultField $r 'name__v' '')"
        if (-not $id -or -not $name) { continue }
        $k = $name.Trim().ToLowerInvariant()
        if (-not $byName.ContainsKey($k)) { $byName[$k] = New-Object System.Collections.ArrayList }
        [void]$byName[$k].Add([pscustomobject]@{ Id = $id; Name = $name })

        $ser = Get-VaultSubmissionSerial -Name $name
        if ($ser) {
            if (-not $bySerial.ContainsKey($ser)) { $bySerial[$ser] = New-Object System.Collections.ArrayList }
            [void]$bySerial[$ser].Add([pscustomobject]@{ Id = $id; Name = $name })
        }
    }
    Write-VaultLog "$($rows.Count) submission(s) in the application, $($bySerial.Count) with a serial number" 'OK'
    return [pscustomobject]@{ Rows = $rows.Count; ByName = $byName; BySerial = $bySerial }
}

function Resolve-VaultSubmissionIdLocal {
    # Match one staged folder to one submission record, against the index.
    #
    # Three passes, most specific first, and every one of them reports HOW it matched -
    # because "resolved" by exact name and "resolved" by serial after the name failed are
    # different levels of confidence and the results file should not flatten them.
    param(
        [Parameter(Mandatory)]$Index,
        [Parameter(Mandatory)][string]$Key
    )
    $k = $Key.Trim().ToLowerInvariant()

    if ($Index.ByName.ContainsKey($k)) {
        $hits = @($Index.ByName[$k])
        if ($hits.Count -eq 1) { return [pscustomobject]@{ Id = $hits[0].Id; How = 'exact name'; Name = $hits[0].Name } }
        throw "$($hits.Count) submissions are named '$Key' - the name does not identify one."
    }

    # Prefix, the way the vault-side LIKE used to do it, kept because a folder named
    # plainly 0000 against a record named "0000 - Meeting Minutes" is the layout this
    # workflow was originally written for and still has to work.
    $pre = @()
    foreach ($nk in $Index.ByName.Keys) { if ($nk.StartsWith($k)) { $pre += @($Index.ByName[$nk]) } }
    if ($pre.Count -eq 1) { return [pscustomobject]@{ Id = $pre[0].Id; How = 'name prefix'; Name = $pre[0].Name } }
    if ($pre.Count -gt 1) { throw "$($pre.Count) submissions start with '$Key' - the prefix does not identify one." }

    $ser = Get-VaultSubmissionSerial -Name $Key
    if (-not $ser) {
        throw "No submission matches '$Key' by name or prefix, and no serial number could be read out of the folder name to match on instead."
    }
    if (-not $Index.BySerial.ContainsKey($ser)) {
        throw "No submission matches '$Key' by name or prefix, and none carries serial $ser."
    }
    $hits = @($Index.BySerial[$ser])
    if ($hits.Count -gt 1) {
        $names = (@($hits | ForEach-Object { $_.Name }) -join '; ')
        throw "$($hits.Count) submissions carry serial ${ser} ($names) - the serial does not identify one."
    }
    return [pscustomobject]@{ Id = $hits[0].Id; How = "serial $ser"; Name = $hits[0].Name }
}

function Start-VaultSubmissionImport {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$SubmissionId,
        [Parameter(Mandatory)][string]$StagingPath,
        [string]$DossierFormatId = '',
        [string]$ActualSubmissionDate = ''
    )
    # Form fields, not a URL path: the request encodes them, so escaping the staging path
    # here as well would double-encode every space in it.
    $pairs = @("file=$([Uri]::EscapeDataString($StagingPath))")
    if ($DossierFormatId)      { $pairs += "dossier_format_record_id=$([Uri]::EscapeDataString($DossierFormatId))" }
    if ($ActualSubmissionDate) { $pairs += "actual_submission_date=$([Uri]::EscapeDataString($ActualSubmissionDate))" }

    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
            -Path "/vobjects/submission__v/$SubmissionId/actions/import" `
            -ContentType 'application/x-www-form-urlencoded' -Body ($pairs -join '&')

    $warnings = ''
    $w = Get-VaultField $r 'warnings' $null
    if ($w) {
        # APPLICATION_MISMATCH and SUBMISSION_MISMATCH are non-fatal - the job still
        # runs - so they are recorded beside the result rather than treated as failure.
        $warnings = (@($w) | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join ' | '
    }
    return [pscustomobject]@{ JobId = "$(Get-VaultField $r 'job_id' '')"; Warnings = $warnings }
}

function Wait-VaultJob {
    # Poll until the job leaves a running state, or the deadline passes.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$JobId,
        [int]$TimeoutMinutes = 120,
        [int]$PollSeconds = 20
    )
    # Vault allows the Job Status endpoint once every 10 seconds PER job_id, and answers
    # API_LIMIT_EXCEEDED past that. A configured interval below the floor would not poll
    # faster, it would just fail faster.
    if ($PollSeconds -lt 11) {
        Write-VaultLog "jobpollseconds is $PollSeconds; Vault allows one job status call per 10s per job - using 11" 'WARN'
        $PollSeconds = 11
    }
    $running  = @('SCHEDULED', 'QUEUING', 'QUEUED', 'RUNNING', 'IN_PROGRESS')
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path "/services/jobs/$JobId"
        $status = "$(Get-VaultField (Get-VaultField $r 'data' $null) 'status' '')".ToUpperInvariant()
        if ($status -and ($running -notcontains $status)) { return $status }
        Start-Sleep -Seconds $PollSeconds
    }
    # A distinct status rather than an exception: the import is still running in Vault,
    # and the row has to say that rather than imply the dossier failed.
    return "TIMEOUT_AFTER_${TimeoutMinutes}_MIN"
}

function Get-VaultSubmissionImportResult {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$SubmissionId,
        [Parameter(Mandatory)][string]$JobId
    )
    # Retried, because this call is made the instant the job status poll returned SUCCESS
    # - and Vault meters BOTH by job_id, once per 10 seconds. So the very first attempt
    # lands inside the window the status poll just opened and comes back
    # API_LIMIT_EXCEEDED. Waiting unconditionally would cost 10 seconds on every dossier;
    # trying and retrying costs it only when it is actually hit.
    #
    # The first version of this swallowed the failure into a blank binder id, so five
    # imports reported SUCCESS with nothing to point at and the cause was invisible
    # until someone read the Messages column.
    for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        # Vault 26R3 (Dec 2026) stops returning the data array from this endpoint;
        # importMessages remains. Binder id and version go blank rather than the call
        # failing, which is why every read here is guarded rather than indexed.
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/vobjects/submission__v/$SubmissionId/actions/import/$JobId/results"
        $binderId = ''; $version = ''
        $d = Get-VaultField $r 'data' $null
        if ($d) {
            $first    = @($d)[0]
            $binderId = "$(Get-VaultField $first 'id' '')"
            $version  = "$(Get-VaultField $first 'major_version_number__v' '?').$(Get-VaultField $first 'minor_version_number__v' '?')"
        }
        $messages = ''
        $im = Get-VaultField $r 'importMessages' $null
        if ($im) { $messages = (@($im) | ForEach-Object { "$_" }) -join ' | ' }
        return [pscustomobject]@{ BinderId = $binderId; BinderVersion = $version; Messages = $messages }
    }
    catch {
        $err = "$_"
        if ($err -match 'API_LIMIT_EXCEEDED' -and $attempt -lt 3) {
            $wait = 11
            Write-VaultLog "import results for job $JobId are inside the 10s per-job polling window - waiting ${wait}s (attempt $attempt/3)" 'WARN'
            Start-Sleep -Seconds $wait
            continue
        }
        # Said out loud, not only written to a column. A SUCCESS row with no binder id
        # is a run that cannot point at what it created, and that should be visible while
        # it happens rather than found afterwards.
        Write-VaultLog "could not read import results for job ${JobId}: $err" 'WARN'
        return [pscustomobject]@{ BinderId = ''; BinderVersion = ''; Messages = "results unavailable: $err" }
    }
    }
    return [pscustomobject]@{ BinderId = ''; BinderVersion = ''; Messages = 'results unavailable after 3 attempts' }
}

function Test-VaultSubmissionsPreflight {
    # Everything that can be proven before the first import, proven before the first
    # import. Returns the number of failures; the caller stops on anything above zero.
    #
    # On the disk check, and what it is NOT: submissions import IN PLACE. No dossier is
    # ever downloaded, so there is no transfer budget to compute and none is claimed
    # here - a check that measured dossier sizes would be describing bytes that never
    # touch this machine. What does get written is the log and the results CSV, and both
    # have failed a run before: a full volume, and a results file held open by Excel,
    # which throws on the FIRST save - after the imports have already happened.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$StagingPath)
    $fail = 0
    Write-VaultLog '=== Preflight ==='

    # 1. Somewhere to write, and room to write it.
    $free = Get-VaultFreeSpace -Path $Context.Out
    if ($free -lt 0) {
        Write-VaultLog "  [WARN] cannot read free space on $($Context.Out)" 'WARN'
    }
    elseif ($free -lt ($Context.ReserveMB * 1MB)) {
        Write-VaultLog ("  [FAIL] {0} free on {1}, below the {2}MB reserve" -f (Format-VaultBytes $free), $Context.Out, $Context.ReserveMB) 'ERROR'
        $fail++
    }
    else {
        Write-VaultLog ("  [PASS] {0} free on {1}" -f (Format-VaultBytes $free), $Context.Out) 'OK'
    }

    # 2. Writable, tested by writing. Permissions that look right and a file that cannot
    #    be created are different things, and only one of them matters.
    $probe = Join-Path $Context.Out ('.preflight-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
    try {
        [IO.File]::WriteAllText($probe, 'probe')
        Remove-Item -LiteralPath $probe -Force -WhatIf:$false -ErrorAction SilentlyContinue
        Write-VaultLog "  [PASS] output folder is writable - $($Context.Out)" 'OK'
    }
    catch {
        Write-VaultLog "  [FAIL] cannot write into $($Context.Out): $_" 'ERROR'
        $fail++
    }

    # 3. The results file, specifically. Excel holds an exclusive lock on an open CSV,
    #    and the run would import everything and then fail to record any of it.
    $res = Join-Path $Context.Out 'submission-import-results.csv'
    if (Test-Path -LiteralPath $res) {
        try {
            $fs = [IO.File]::Open($res, 'Open', 'ReadWrite', 'None')
            $fs.Dispose()
            Write-VaultLog '  [PASS] submission-import-results.csv is not locked' 'OK'
        }
        catch {
            Write-VaultLog '  [FAIL] submission-import-results.csv is open in another program - close it (Excel holds an exclusive lock)' 'ERROR'
            $fail++
        }
    }

    # 4. The staging path resolves and holds something. An application folder that lists
    #    nothing is the single most common way this run does nothing and says it
    #    succeeded, so it fails here rather than reporting "0 dossiers" as a result.
    try {
        $items = Get-VaultSubmissionDossier -Context $Context -Path $StagingPath
        if ($items.Count -eq 0) {
            Write-VaultLog "  [FAIL] $StagingPath lists no dossier folders or archives" 'ERROR'
            $fail++
        }
        else {
            $folders = @($items | Where-Object { $_.Kind -eq 'folder' }).Count
            Write-VaultLog ("  [PASS] {0} dossier(s) under {1} ({2} folder(s), {3} archive(s))" -f `
                            $items.Count, $StagingPath, $folders, ($items.Count - $folders)) 'OK'
        }
    }
    catch {
        Write-VaultLog "  [FAIL] cannot list $StagingPath - $_" 'ERROR'
        $fail++
    }

    Write-VaultLog "  preflight: $fail failure(s)"
    return $fail
}

function Confirm-VaultSubmissionsVault {
    # Which vault instance this load writes into, established and agreed before anything
    # is read or imported.
    #
    # Vault File Manager's File Staging is SHARED between the instances on a domain, so
    # the same /SubmissionsArchive listing is visible from production and from a sandbox
    # and looks identical in both. The staging path therefore says nothing about where an
    # import lands, and [vault] target is a setting about the document migration with
    # nothing to say about this workflow. Inheriting it silently is how a whole wave goes
    # into the wrong instance, and nothing downstream catches it - every dossier imports
    # successfully, into production.
    #
    # So it is asked for once, remembered, and confirmed on every load. Answering "no"
    # asks for a different one rather than stopping the run: a confirmation whose only
    # other answer is "abort" gets a reflex "yes", and the whole point of this prompt is
    # that somebody reads it.
    #
    # The identity block comes from the session that will do the writing, not from the
    # config, and vaultId is the field that matters - on a shared domain the host names
    # are near-misses of each other and the vaultId is not.
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Candidate,   # NOT $Host - that is an automatic variable
        [Parameter(Mandatory)][AllowEmptyString()][string]$Suggested,
        [Parameter(Mandatory)][string]$ApiVersion,
        [AllowEmptyString()][string]$Source = '',
        [switch]$Yes
    )
    # A console can answer; a scheduled run cannot, and blocking for ever on an answer
    # nobody is there to give is worse than either proceeding or stopping outright.
    $canAsk = Test-VaultCanPrompt

    $h     = "$Candidate".Trim()
    $typed = $false

    while ($true) {
        if (-not $h) {
            if (-not $canAsk) {
                throw "[submissions] vault is not set in $ConfigPath, and this is not a console so it cannot be asked for. Set it, or pass -VaultHost."
            }
            Write-Host ''
            Write-Host '  Which vault instance this load imports into. File Staging is shared'
            Write-Host '  between the instances on a domain, so the folder you picked looks the'
            Write-Host '  same from a sandbox as it does from production - the path cannot say'
            Write-Host '  which one this is. Name it.'
            Write-Host ''
            Write-Host '      your-vault-sbx.veevavault.com'
            Write-Host ''
            $prompt = if ($Suggested) { "Vault host [$Suggested]" } else { 'Vault host' }
            $answer = (Read-Host $prompt).Trim()
            if (-not $answer -and $Suggested) {
                $answer = $Suggested
                Write-VaultLog "Taking $Suggested, the suggestion - that is [vault] target, which is a guess about this workflow rather than a setting for it." 'WARN'
            }
            if (-not $answer) { throw 'Stopped: no vault given.' }
            $h      = $answer
            $typed  = $true
            $Source = ''
        }

        $h = Get-VaultHostName $h
        if (-not $h) { throw 'No vault for submissions. Set [submissions] vault, or pass -VaultHost.' }
        Write-VaultLog "submissions vault: $h$(if ($Source) { " (from $Source)" })"

        # Log in and read who we are there. -Yes suppresses that function's own question:
        # it establishes the session and prints the identity, and the confirming is done
        # here, where "no" has somewhere to go.
        try {
            [void](Confirm-VaultSessions -Vaults @(@{ Role = 'submissions'; Name = $h }) -ApiVersion $ApiVersion -Yes)
        }
        catch {
            # A mistyped host fails here. Stopping the run over a typo would be its own
            # small cruelty when the next thing we would do anyway is ask for one.
            Write-VaultLog "Could not establish a session on ${h}: $_" 'WARN'
            if (-not $canAsk) { throw }
            $h = ''; $typed = $false
            continue
        }

        if ($Yes) { return $h }
        if (-not $canAsk) {
            Write-VaultLog 'Not a console - proceeding without confirmation.' 'WARN'
            return $h
        }

        # [y/N] and nothing else: "no" already means "ask me for a different one", so a
        # third letter would be a third word for the same behaviour.
        $answer = Read-Host 'Is this the vault to import into? [y/N]'
        if ($answer -match '^[Yy]') {
            # Offered only now, and only for a value that was typed. Saving before the
            # confirmation would write down a vault that was about to be rejected.
            if ($typed) { Save-VaultSubmissionsVault -ConfigPath $ConfigPath -VaultDns $h }
            return $h
        }

        Write-VaultLog 'Not confirmed - asking for a different vault.' 'WARN'
        $h = ''; $typed = $false
    }
}

function Save-VaultSubmissionsVault {
    # Offered, not assumed. Writing to somebody's config without asking is the kind of
    # helpfulness that is indistinguishable from a bug when they next read it.
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$VaultDns
    )
    $save = Read-Host "Save this to [submissions] vault in $(Split-Path -Leaf $ConfigPath)? [Y/n]"
    if ($save -match '^[Nn]') {
        Write-VaultLog 'Not saved - this vault applies to this run only.' 'WARN'
        return
    }
    try {
        Set-VaultSetting -Path $ConfigPath -Section 'submissions' -Key 'vault' -Value $VaultDns
        Write-VaultLog "Saved to $ConfigPath - it will be confirmed rather than asked for next time." 'OK'
    }
    catch { Write-VaultLog "Could not write $ConfigPath, so this vault applies to this run only: $_" 'WARN' }
}

function Confirm-VaultStagingPath {
    # The Submissions Archive root this run works from, established and agreed before
    # anything reads or imports.
    #
    # Prompted when [submissions] path is empty, and offered back to vault.ini so it is
    # asked for once rather than every run. Shown and confirmed when it is already set,
    # the same way the vaults are - because this path decides which application gets
    # imported, and pointing it at last wave's folder is a mistake nothing downstream
    # can catch. The application is echoed beside it: that is the value actually used to
    # resolve every record, and confirming the string without it confirms the wrong half.
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [switch]$Yes
    )
    # A console can answer; a scheduled run cannot, and blocking for ever on an answer
    # nobody is there to give is worse than either proceeding or stopping outright.
    $canAsk = Test-VaultCanPrompt

    $p = "$Path".Trim()

    if (-not $p) {
        if (-not $canAsk) {
            throw "[submissions] path is not set in $ConfigPath, and this is not a console so it cannot be asked for."
        }
        Write-VaultLog '[submissions] path is not set.' 'WARN'
        Write-Host ''
        Write-Host '  The application folder on the TARGET vault''s File Staging, under the'
        Write-Host '  Submissions Archive root. Its children are the submissions:'
        Write-Host ''
        Write-Host '      /SubmissionsArchive/e157135        <- this'
        Write-Host '      /SubmissionsArchive/e157135/0000'
        Write-Host '      /SubmissionsArchive/e157135/0001'
        Write-Host ''
        $p = (Read-Host 'Submissions Archive path').Trim()
        if (-not $p) { throw 'Stopped: no path given.' }
        if (-not $p.StartsWith('/')) { $p = "/$p" }

        # Offered, not assumed. Writing to somebody's config without asking is the kind
        # of helpfulness that is indistinguishable from a bug when they next read it.
        $save = Read-Host "Save this to [submissions] path in $(Split-Path -Leaf $ConfigPath)? [Y/n]"
        if ($save -notmatch '^[Nn]') {
            try {
                Set-VaultSetting -Path $ConfigPath -Section 'submissions' -Key 'path' -Value $p
                Write-VaultLog "Saved to $ConfigPath - it will be confirmed rather than asked for next time." 'OK'
            }
            catch { Write-VaultLog "Could not write $ConfigPath, so this path applies to this run only: $_" 'WARN' }
        }
        else { Write-VaultLog 'Not saved - this path applies to this run only.' 'WARN' }
    }

    $app = @(($p -replace '\\', '/').Trim('/') -split '/')[-1]
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog ("  staging     {0}" -f $p) 'OK'
    Write-VaultLog ("  application {0}" -f $app)
    Write-VaultLog '----------------------------------------------------------------'

    if ($Yes) { return $p }
    if (-not $canAsk) {
        Write-VaultLog 'Not a console - proceeding without confirmation.' 'WARN'
        return $p
    }
    $answer = Read-Host "Is this the right application? [y/N]"
    if ($answer -notmatch '^[Yy]') { throw 'Stopped: the staging path was not confirmed.' }
    return $p
}

function Invoke-VaultSubmissionsList {
    # What is there, written to a manifest. No VQL, no imports, no vault writes - this
    # answers "did I point it at the right folder" before anything costs anything.
    param([Parameter(Mandatory)]$Context, [int]$Limit = 0)
    $c    = $Context
    $path = $c.StagingPath
    Write-VaultLog "Listing $path"

    $dossiers = @(Get-VaultSubmissionDossier -Context $c -Path $path)
    if ($Limit -gt 0 -and $dossiers.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - showing the first $Limit of $($dossiers.Count)" 'WARN'
        $dossiers = @($dossiers | Select-Object -First $Limit)
    }

    $out = Join-Path $c.Out 'submission-manifest.csv'
    $rows = New-Object System.Collections.ArrayList
    foreach ($d in $dossiers) {
        [void]$rows.Add([pscustomobject][ordered]@{
            FileName             = $d.Name
            SubmissionKey        = $d.Base
            SubmissionId         = ''
            Kind                 = $d.Kind
            StagingPath          = $d.Path
            SizeMB               = [math]::Round(([double]$d.Size) / 1MB, 2)
            ActualSubmissionDate = ''
            DossierFormatId      = ''
        })
    }
    $rows | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "  dossiers   $($dossiers.Count)" 'OK'
    Write-VaultLog "  manifest   $out"
    Write-VaultLog 'SubmissionId is blank here on purpose - resolving it needs the vault, which is what `submissions import -Plan` does.'
    return 0
}

function Invoke-VaultSubmissionsImport {
    param(
        [Parameter(Mandatory)]$Context,
        [switch]$Plan,
        [int]$TestCount = 0,
        [int]$Limit = 0
    )
    $c    = $Context
    $path = $c.StagingPath

    # The application is the last segment of the staging path. Taken from there rather
    # than configured separately, because two settings that must agree are two settings
    # that can disagree - and the layout already says it.
    $appKey = @(($path -replace '\\', '/').Trim('/') -split '/')[-1]

    $bad = Test-VaultSubmissionsPreflight -Context $c -StagingPath $path
    if ($bad -gt 0) {
        Write-VaultLog "Stopping: $bad preflight check(s) failed. Nothing was imported." 'ERROR'
        return $bad
    }

    $dossiers = @(Get-VaultSubmissionDossier -Context $c -Path $path)
    $total    = $dossiers.Count
    if ($Limit -gt 0 -and $dossiers.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - examining the first $Limit of $total dossier(s)" 'WARN'
        $dossiers = @($dossiers | Select-Object -First $Limit)
    }
    Write-VaultLog "$($dossiers.Count) dossier(s) in application '$appKey'"

    # Sequential, and not because nobody got round to sharding it. An import is an async
    # JOB in Vault: this process starts it and then waits. Running eight of them in
    # parallel would queue eight jobs on the same vault rather than doing the work eight
    # times faster, and the failure mode - a wave of imports nobody is watching - is
    # exactly what the phased design exists to prevent.
    $res = New-VaultResults -Path (Join-Path $c.Out 'submission-import-results.csv') -KeyColumn 'FileName' `
              -DoneStatuses @('SUCCESS') -Existing $c.Existing

    # Resolved ONCE, before the loop: the application, then every submission in it.
    # Per dossier this was a VQL call each - 161 round trips - and it could not match on
    # a serial number at all, because VQL forbids a leading wildcard. Both problems go
    # away by fetching the set and matching here.
    try {
        $appId = Get-VaultApplicationId -Context $c -Key $appKey -Object $c.ApplicationObject -KeyField $c.ApplicationKeyField
        $index = Get-VaultSubmissionIndex -Context $c -ApplicationId $appId -ApplicationRefField $c.ApplicationRefField
    }
    catch {
        # One clear stop, not 161 copies of the same error against every dossier.
        Write-VaultLog "Cannot resolve the application: $_" 'ERROR'
        return 1
    }

    $stat = @{ Ok = 0; Failed = 0; Planned = 0; Skipped = 0 }
    $i = 0
    $stopped = $false

    foreach ($d in $dossiers) {
        $i++
        $prefix = "[$i/$($dossiers.Count)] $($d.Name)"
        if ($res.Done.ContainsKey($d.Name)) { $stat.Skipped++; continue }

        $row = [pscustomobject][ordered]@{
            FileName      = $d.Name
            StagingPath   = $d.Path
            SizeMB        = [math]::Round(([double]$d.Size) / 1MB, 2)
            SubmissionKey = $d.Base
            SubmissionId  = ''
            MatchedBy     = ''
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
            # Read-only, so it runs in every mode. Resolving the id is the whole point of
            # the dry run: a key that matches nothing, or matches two records, is found
            # here rather than part way through a real wave.
            $m     = Resolve-VaultSubmissionIdLocal -Index $index -Key $d.Base
            $subId = $m.Id
            $row.SubmissionId = $subId
            $row.MatchedBy    = $m.How
            # The matched NAME is logged, not just the id. Where the two strings differ -
            # and they do, by whole days in the leading date - the operator needs to see
            # what it matched to, not be told that something matched.
            if ($m.How -ne 'exact name') {
                Write-VaultLog "$prefix - matched by $($m.How) to '$($m.Name)'" 'WARN'
            }

            if ($Plan -or $c.WhatIf) {
                # StrictMode: assigning a property this row does not have is a
                # terminating error, and the column here is Messages, not Message.
                $row.Status = if ($c.WhatIf) { 'WHATIF' } else { 'PLANNED' }
                $stat.Planned++
                Write-VaultLog "$prefix - resolved to submission $subId ($($m.How)); would import $($d.Path)" 'OK'
            }
            else {
                $job = Start-VaultSubmissionImport -Context $c -SubmissionId $subId -StagingPath $d.Path `
                          -DossierFormatId $c.DossierFormatId
                $row.JobId    = $job.JobId
                $row.Warnings = $job.Warnings
                if ($job.Warnings) { Write-VaultLog "$prefix - import warnings: $($job.Warnings)" 'WARN' }
                Write-VaultLog "$prefix - job $($job.JobId) started, polling every $($c.JobPollSeconds)s"

                $status = Wait-VaultJob -Context $c -JobId $job.JobId -TimeoutMinutes $c.JobTimeoutMinutes -PollSeconds $c.JobPollSeconds
                $row.Status = $status

                $r = Get-VaultSubmissionImportResult -Context $c -SubmissionId $subId -JobId $job.JobId
                $row.BinderId      = $r.BinderId
                $row.BinderVersion = $r.BinderVersion
                $row.Messages      = $r.Messages

                if ($status -eq 'SUCCESS') {
                    $stat.Ok++
                    Write-VaultLog "$prefix - SUCCESS (binder $($r.BinderId) v$($r.BinderVersion))" 'OK'
                }
                else {
                    $stat.Failed++
                    Write-VaultLog "$prefix - job ended $status. $($r.Messages)" 'ERROR'
                }
            }
        }
        catch {
            $row.Status   = 'ERROR'
            $row.Messages = "$_"
            $stat.Failed++
            Write-VaultLog "$prefix - ERROR: $_" 'ERROR'
        }

        $row.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
        Add-VaultResult -Results $res -Row $row

        if ($TestCount -gt 0) {
            $done = if ($Plan -or $c.WhatIf) { $stat.Planned } else { $stat.Ok + $stat.Failed }
            if ($done -ge $TestCount) {
                Write-VaultLog "TEST: $done after $i dossier(s) - stopping" 'OK'
                $stopped = $true
                break
            }
        }
    }

    Save-VaultResults -Results $res
    Write-VaultLog '----------------------------------------------------------------'
    if ($Plan -or $c.WhatIf) {
        Write-VaultLog "$($stat.Planned) dossier(s) resolved, $($stat.Failed) could not be. NOTHING was imported." $(if ($stat.Failed) { 'WARN' } else { 'OK' })
        if ($stat.Failed) { Write-VaultLog 'Fix the ERROR rows before a real run - each is a dossier that would fail there too.' 'WARN' }
    }
    else {
        Write-VaultLog "Imported $($stat.Ok), $($stat.Failed) failed, $($stat.Skipped) already SUCCESS" $(if ($stat.Failed) { 'WARN' } else { 'OK' })
    }
    if ($stopped) { Write-VaultLog "TEST run - stopped after $i of $($dossiers.Count) dossier(s). NOT the whole application." 'WARN' }
    Write-VaultLog "Results: $($res.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($res.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return $stat.Failed
}

# ===== VaultKit/Roles.ps1 =====

# Document Sharing Settings that a migration left empty.
#
# Documents created through the Vault UI get users and groups populated into their
# Sharing Settings automatically, from the lifecycle's role assignment rules and from the
# document type's "Default Settings for New Documents". Documents created through the API
# or Vault Loader do NOT - Veeva confirms this is by design. So a migrated document
# arrives with its roles empty, and something has to put them back.
#
# This is that something. For each document it reads the roles Vault reports, works out
# who the configuration says should be there, and assigns whoever is missing. It never
# removes anyone and never invents an assignment: everything it writes is something the
# configuration already names as a default.
#
# One vault, not two. This repairs the target of a migration rather than comparing two
# vaults, so it reads Context.VaultHost - the target - where the transfer reads both.
#
# Ported from veeva-roles.ps1, which carried its own copy of the logging, sessions,
# credentials, API layer and delimited-file reading. All of that is VaultKit's now, and
# the copies are gone rather than left to drift.

function ConvertTo-VaultNameKey {
    # A key that survives Vault handing back the NAME in one place and the LABEL in
    # another for the same thing.
    #
    # GET /objects/documents/{id} reports lifecycle__v as "General Lifecycle".
    # GET /configuration/role_assignment_rule reports it as "general_lifecycle__c".
    # Keyed literally those are two different lifecycles, so every rule lookup missed,
    # every role came back "no rule", and an assign run would have read every document in
    # the vault and written nothing - reporting success while doing so.
    #
    # Dropping the __c/__v/__sys suffix before folding makes both spellings converge, and
    # a label really is the name in title case in every case seen so far.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $v = $Value -replace '__(c|v|sys)$', ''
    return ($v -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}

function ConvertTo-VaultKey {
    # One spelling for every name comparison. The UI shows labels ("Label Authors"), the
    # API returns names ("label_authors__c"), and a person transcribing a screen will
    # produce either. Compare on a form that survives both.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return ($Value -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}


# ======================================================================================
#  Settings
# ======================================================================================

function Get-VaultDocumentsByQuery {
    # The documents to repair, enumerated from the vault instead of listed in a map.
    #
    # A map says exactly which documents a migration produced, and that is the safer
    # scope. A query is for when the migration WAS the vault, or when the job is "every
    # document of this subtype" - cases where maintaining a spreadsheet of ids would be
    # busywork. Only the WHERE clause is taken, so the query cannot quietly select
    # something other than document ids.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Where,
        # Stop paging once this many are in hand. 0 means every page. A survey needs
        # twenty-five documents, and paging a 500,000-document vault to the end to throw
        # away all but twenty-five is five hundred calls spent on nothing.
        [int]$Stop = 0
    )

    $w = $Where.Trim()
    $vql = if (-not $w)                  { 'SELECT id FROM documents' }
           elseif ($w -match '^\s*SELECT\s') { $w }
           else                          { "SELECT id FROM documents WHERE $w" }
    Write-VaultLog "Enumerating: $vql"

    $out  = New-Object System.Collections.ArrayList
    $seen = @{}
    $path  = '/query'
    $body  = "q=$([Uri]::EscapeDataString($vql))"
    $pages = 0

    while ($path -and $pages -lt 1000) {
        $pages++
        # Page 1 is a POST carrying the query; every page after it is a GET on the URL
        # Vault hands back, which already has the query baked in.
        $r = if ($pages -eq 1) {
                Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
                    -Path $path -Body $body -ContentType 'application/x-www-form-urlencoded'
             } else {
                Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path $path
             }

        foreach ($row in @(Get-VaultField $r 'data' @())) {
            $id = "$(Get-VaultField $row 'id' '')"
            if (-not $id -or $seen.ContainsKey($id)) { continue }
            $seen[$id] = $true
            [void]$out.Add([pscustomobject]@{ TargetId = $id; SourceId = '' })
        }
        if ($Stop -gt 0 -and $out.Count -ge $Stop) { break }
        $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    if ($out.Count -eq 0) { throw "The query matched no documents: $vql" }
    if ($Stop -gt 0 -and $out.Count -gt $Stop) { $out = @($out | Select-Object -First $Stop) }
    Write-VaultLog "$($out.Count) document(s) from the query" 'OK'
    return @($out)
}


# ======================================================================================
#  Users and groups, by name
#
#  The document roles API speaks in numeric ids. The Admin screen a defaults table is
#  transcribed from speaks in labels. Both directions are needed: names in, so the table
#  can be written by a person, and names out, so the plan can be read by one.
# ======================================================================================

$script:Directory = $null

function Get-VaultDirectory {
    # Every user and group in the vault, indexed by id and by every name it answers to.
    # Fetched once. A vault with tens of thousands of users makes this a handful of pages;
    # doing it per document instead would make it thousands of calls.
    param([Parameter(Mandatory)]$Context)
    if ($script:Directory) { return $script:Directory }

    $byId      = @{}
    $byName    = @{}
    $byMembers = @{}   # group id -> the user ids in it

    # Both listings come back wrapped - users: [ { user: {...} } ] - but not every Vault
    # release wraps them, so unwrap defensively rather than assuming either shape.
    function Add-Entry {
        param($Record, [string]$Wrapper, [string[]]$NameFields, [string]$Kind)
        $r = Get-VaultField $Record $Wrapper $null
        if ($null -eq $r) { $r = $Record }
        $id = "$(Get-VaultField $r 'id' '')"
        if (-not $id) { return }
        $names = @()
        foreach ($nf in $NameFields) {
            $v = "$(Get-VaultField $r $nf '')"
            if ($v) { $names += $v }
        }
        $display = if ($names.Count) { $names[0] } else { $id }
        $byId["$Kind`:$id"] = $display
        # Group membership, so a run can say whether the users it is about to assign
        # directly are simply the people already in the groups it is assigning.
        if ($Kind -eq 'group') {
            $byMembers[$id] = @(@(Get-VaultField $r 'members__v' @()) | ForEach-Object { "$_" })
        }
        # Indexed under BOTH foldings. A group arrives here as a label ("Business
        # Administrators") and is looked up by MDL as a name ("business_administrators__c");
        # keying only one way means the lookup misses and the group is silently dropped
        # from a role. That is the same failure the lifecycle join already had.
        foreach ($n in $names) {
            foreach ($k in @("$Kind`:$(ConvertTo-VaultKey $n)", "$Kind`:$(ConvertTo-VaultNameKey $n)")) {
                if (-not $byName.ContainsKey($k)) { $byName[$k] = $id }
            }
        }
    }

    # Groups come back whole - Retrieve All Groups documents no pagination parameters at
    # all - so one call is the whole set.
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path '/objects/groups'
    foreach ($rec in @(Get-VaultField $r 'groups' @())) {
        Add-Entry -Record $rec -Wrapper 'group' -NameFields @('label__v', 'name__v') -Kind 'group'
    }

    # Users page by limit and start, NOT by responseDetails.next_page - that field is a
    # VQL thing and this endpoint does not return it. Reading the page-1 response for a
    # next_page that is never there stops silently at the first 200 users, and a user the
    # directory has never heard of resolves to nothing, which quietly shrinks a role.
    #
    # 200 is the documented default. Anything from 500 up is rejected outright:
    # INVALID_DATA, "The 'limit' parameter must be < 500."
    $pageSize = 200
    $start    = 0
    $pages    = 0
    while ($pages -lt 2000) {
        $pages++
        $before = $byId.Count
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/objects/users?limit=$pageSize&start=$start"
        $batch = @(Get-VaultField $r 'users' @())
        foreach ($rec in $batch) {
            Add-Entry -Record $rec -Wrapper 'user' -NameFields @('user_name__v', 'user_email__v', 'name__v') -Kind 'user'
        }
        # Two independent stop conditions, because either alone can fail. A short page
        # means the end; no NEW entries means the endpoint ignored `start` and is handing
        # back page one for ever, which would otherwise spin until the page cap.
        if ($batch.Count -lt $pageSize) { break }
        if ($byId.Count -eq $before)    { break }
        $start += $pageSize
    }

    $users  = @($byId.Keys | Where-Object { $_ -like 'user:*' }).Count
    $groups = @($byId.Keys | Where-Object { $_ -like 'group:*' }).Count
    Write-VaultLog "Directory: $users user(s), $groups group(s)"
    $script:Directory = [pscustomobject]@{ ById = $byId; ByName = $byName; Members = $byMembers }
    return $script:Directory
}

# ======================================================================================
#  Document type default security
#
#  The "Default Settings for New Documents" box on Admin > Document Types > (subtype) >
#  Security. This is NOT the lifecycle's role assignment rules, and it is NOT in
#  defaultUsers/defaultGroups on the document roles endpoint - a real vault reported
#  nothing at all for editor__v while that screen listed three groups for it.
#
#  It IS in the MDL component for the doctype, as role_defaulting_editors / _viewers /
#  _consumers, each a list of "group:Group.name__c" or "user:username". Read once per
#  subtype rather than once per document, so it costs a handful of calls for a whole run.
# ======================================================================================

$script:DocTypeNames    = $null
$script:DocTypeDefaults = @{}

function Get-VaultDocTypeNameIndex {
    # label -> api name, for document types. A document reports LABELS ("Administrative
    # Information") while MDL is keyed by NAME, so one has to become the other before
    # anything can be looked up at all.
    param([Parameter(Mandatory)]$Context)
    if ($script:DocTypeNames) { return $script:DocTypeNames }

    $types = @{}
    $subs  = @{}
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path '/metadata/objects/documents/types'
    foreach ($ty in @(Get-VaultField $r 'types' @())) {
        $label = "$(Get-VaultField $ty 'label' '')"
        $url   = "$(Get-VaultField $ty 'value' '')"
        if (-not $label -or -not $url) { continue }
        $name = ($url -split '/')[-1]
        if ($name) { $types[(ConvertTo-VaultNameKey $label)] = $name }
    }
    $script:DocTypeNames = [pscustomobject]@{ Types = $types; Subtypes = $subs; Classifications = @{} }
    return $script:DocTypeNames
}

function Get-VaultSubtypeName {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$TypeName,
        [Parameter(Mandatory)][AllowEmptyString()][string]$SubtypeLabel
    )
    $idx = Get-VaultDocTypeNameIndex -Context $Context
    $key = "$TypeName|$(ConvertTo-VaultNameKey $SubtypeLabel)"
    if ($idx.Subtypes.ContainsKey($key)) { return $idx.Subtypes[$key] }
    try {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/metadata/objects/documents/types/$TypeName"
        foreach ($st in @(Get-VaultField $r 'subtypes' @())) {
            $label = "$(Get-VaultField $st 'label' '')"
            $url   = "$(Get-VaultField $st 'value' '')"
            if (-not $label -or -not $url) { continue }
            $nm = ($url -split '/')[-1]
            if ($nm) { $idx.Subtypes["$TypeName|$(ConvertTo-VaultNameKey $label)"] = $nm }
        }
    }
    catch { Write-VaultLog "  could not list the subtypes of ${TypeName}: $_" 'WARN' }
    if ($idx.Subtypes.ContainsKey($key)) { return $idx.Subtypes[$key] }
    return ''
}

function ConvertFrom-VaultMdlPrincipalList {
    # "group:Group.business_administrators__c" / "user:jane@example.com" -> ids.
    param(
        [Parameter(Mandatory)]$Directory,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Values
    )
    $users   = New-Object System.Collections.ArrayList
    $groups  = New-Object System.Collections.ArrayList
    $unknown = New-Object System.Collections.ArrayList
    foreach ($raw in $Values) {
        $v = "$raw".Trim().Trim("'", '"')
        if (-not $v) { continue }
        if ($v -match '^group:\s*(?:Group\.)?(.+)$') {
            $nm = $Matches[1].Trim()
            $id = Resolve-VaultNameToId -Directory $Directory -Kind 'group' -Name $nm
            if ($id) { [void]$groups.Add($id) } else { [void]$unknown.Add("group '$nm'") }
        }
        elseif ($v -match '^user:\s*(.+)$') {
            $nm = $Matches[1].Trim()
            $id = Resolve-VaultNameToId -Directory $Directory -Kind 'user' -Name $nm
            if ($id) { [void]$users.Add($id) } else { [void]$unknown.Add("user '$nm'") }
        }
    }
    return [pscustomobject]@{ Users = @($users); Groups = @($groups); Unknown = @($unknown) }
}

function Get-VaultMdlAttributeValue {
    # One multi-value attribute out of an MDL component response.
    #
    # Three shapes are accepted because this endpoint's is not documented in the mirror: a
    # JSON component carrying the attribute as a property, one carrying it in an
    # attributes list, and raw MDL source written as name('a', 'b'). Betting on one and
    # being wrong would apply no type defaults at all and say nothing - which is precisely
    # the failure this code exists to fix.
    param([Parameter(Mandatory)]$Response, [Parameter(Mandatory)][string]$Attribute)

    foreach ($holder in @($Response, (Get-VaultField $Response 'data' $null), (Get-VaultField $Response 'component' $null))) {
        if ($null -eq $holder) { continue }
        $v = Get-VaultField $holder $Attribute $null
        if ($null -ne $v) { return @($v) }
        foreach ($listName in @('attributes', 'properties')) {
            foreach ($a in @(Get-VaultField $holder $listName @())) {
                if ("$(Get-VaultField $a 'name' '')" -eq $Attribute) {
                    $av = Get-VaultField $a 'value' $null
                    if ($null -ne $av) { return @($av) }
                }
            }
        }
    }

    $raw = "$(Get-VaultField $Response 'raw' '')"
    if ($raw -and $raw -match ($Attribute + '\s*\(([^)]*)\)')) {
        return @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim("'", '"') } | Where-Object { $_ })
    }
    return @()
}

function Get-VaultClassificationName {
    # label -> api name for a classification, the THIRD level of the document type
    # hierarchy. Type, then subtype, then classification: a vault that uses all three
    # configures defaults at whichever level it chooses, and reading only two of them
    # means the most specific configuration - the one deliberately set closest to the
    # document - is the one missed.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$TypeName,
        [Parameter(Mandatory)][string]$SubtypeName,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ClassificationLabel
    )
    if (-not $ClassificationLabel) { return '' }
    $idx = Get-VaultDocTypeNameIndex -Context $Context
    $key = "$TypeName|$SubtypeName|$(ConvertTo-VaultNameKey $ClassificationLabel)"
    if ($idx.Classifications.ContainsKey($key)) { return $idx.Classifications[$key] }
    try {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/metadata/objects/documents/types/$TypeName/subtypes/$SubtypeName"
        foreach ($cl in @(Get-VaultField $r 'classifications' @())) {
            $label = "$(Get-VaultField $cl 'label' '')"
            $url   = "$(Get-VaultField $cl 'value' '')"
            if (-not $label -or -not $url) { continue }
            $nm = ($url -split '/')[-1]
            if ($nm) { $idx.Classifications["$TypeName|$SubtypeName|$(ConvertTo-VaultNameKey $label)"] = $nm }
        }
    }
    catch { Write-VaultLog "  could not list the classifications of $TypeName/${SubtypeName}: $_" 'WARN' }
    if ($idx.Classifications.ContainsKey($key)) { return $idx.Classifications[$key] }
    return ''
}

function Get-VaultDocTypeRoleDefault {
    # editor__v / viewer__v / consumer__v defaults for one subtype, from its MDL component.
    # Cached, so a run over 15,000 documents of six subtypes makes six of these calls.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$TypeLabel,
        [Parameter(Mandatory)][AllowEmptyString()][string]$SubtypeLabel,
        [Parameter(Mandatory)]$Directory,
        # The third level of the hierarchy. Empty on a vault that does not use them.
        [AllowEmptyString()][string]$ClassificationLabel = ''
    )
    $cacheKey = "$TypeLabel|$SubtypeLabel|$ClassificationLabel"
    if ($script:DocTypeDefaults.ContainsKey($cacheKey)) { return $script:DocTypeDefaults[$cacheKey] }

    $empty = @{}
    $script:DocTypeDefaults[$cacheKey] = $empty
    if (-not $TypeLabel) { return $empty }

    $idx     = Get-VaultDocTypeNameIndex -Context $Context
    $typeKey = ConvertTo-VaultNameKey $TypeLabel
    if (-not $idx.Types.ContainsKey($typeKey)) {
        Write-VaultLog "No document type called '$TypeLabel' - its type defaults cannot be read" 'WARN'
        return $empty
    }
    $typeName = $idx.Types[$typeKey]

    # Walk the hierarchy, most specific first. The component reference is explicit that
    # these attributes are inherited: "If none are specified, the default value is
    # inherited from parent or base." A subtype usually does NOT restate them, which is
    # why reading only the subtype found nothing while the Admin screen - which shows the
    # EFFECTIVE value - listed three groups.
    #
    # First level that defines a role wins for that role, which is what inheritance means.
    # Roles are filled independently: a subtype may override Editors while still
    # inheriting Viewers from its type.
    # Most specific first, and there are THREE levels, not two. Classification is where
    # a vault that uses it puts the configuration meant for these documents in
    # particular, so skipping it reads the general answer and calls it the specific one.
    $candidates = New-Object System.Collections.ArrayList
    $subName = ''
    if ($SubtypeLabel -and (ConvertTo-VaultNameKey $SubtypeLabel) -ne $typeKey) {
        $subName = Get-VaultSubtypeName -Context $Context -TypeName $typeName -SubtypeLabel $SubtypeLabel
    }
    if ($subName -and $ClassificationLabel) {
        $clsName = Get-VaultClassificationName -Context $Context -TypeName $typeName `
                       -SubtypeName $subName -ClassificationLabel $ClassificationLabel
        if ($clsName) { [void]$candidates.Add("Doctype.$typeName.$subName.$clsName") }
    }
    if ($subName) { [void]$candidates.Add("Doctype.$typeName.$subName") }
    [void]$candidates.Add("Doctype.$typeName")
    [void]$candidates.Add('Doctype.base_document__v')

    $out      = @{}
    $unknown  = New-Object System.Collections.ArrayList
    $sources  = New-Object System.Collections.ArrayList
    $lastResp = $null
    $lastName = ''
    $why      = ''

    foreach ($component in $candidates) {
        if ($out.Count -eq 3) { break }   # every role already answered by a nearer level

        # Two endpoints return this, and they are shaped differently on purpose:
        #
        #   GET /api/{version}/configuration/{Type}.{name}   JSON, versioned
        #   GET /api/mdl/components/{Type}.{name}            MDL source, NOT versioned
        #
        # The second has no version segment at all. Building it as /api/v26.2/mdl/... earns
        # a 404 MALFORMED_URL, which is how the first attempt at this failed.
        $r = $null
        foreach ($path in @("/configuration/$component", "/api/mdl/components/$component")) {
            try {
                $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                        -Path $path -MaxRetries 1
                break
            }
            catch { if (-not $why) { $why = "$_" } }
        }
        if ($null -eq $r) { continue }
        $lastResp = $r
        $lastName = $component

        foreach ($pair in @(
            @{ Role = 'editor__v';   Attr = 'role_defaulting_editors' },
            @{ Role = 'viewer__v';   Attr = 'role_defaulting_viewers' },
            @{ Role = 'consumer__v'; Attr = 'role_defaulting_consumers' }
        )) {
            if ($out.ContainsKey($pair.Role)) { continue }
            $vals = @(Get-VaultMdlAttributeValue -Response $r -Attribute $pair.Attr)
            if (-not $vals.Count) { continue }
            $res = ConvertFrom-VaultMdlPrincipalList -Directory $Directory -Values $vals
            foreach ($u in $res.Unknown) { [void]$unknown.Add($u) }
            if ($res.Users.Count -or $res.Groups.Count) {
                $out[$pair.Role] = [pscustomobject]@{ Users = $res.Users; Groups = $res.Groups }
                [void]$sources.Add("$($pair.Role) from $component")
            }
        }
    }

    if ($unknown.Count) {
        Write-VaultLog "Type defaults name $($unknown.Count) principal(s) matching nothing in this vault: $(($unknown | Select-Object -Unique | Select-Object -First 5) -join '; ')" 'WARN'
    }

    if ($out.Count) {
        Write-VaultLog "Type defaults for '$SubtypeLabel': $(($sources | Sort-Object) -join ', ')"
    }
    else {
        # Nothing found anywhere up the hierarchy. That is either a vault that really has
        # no type defaults, or a response shaped in a way this does not read - and those
        # two look identical from the outside, so print what actually came back rather
        # than leave someone to guess which it was.
        Write-VaultLog "No type defaults found for '$SubtypeLabel' at any level: $($candidates -join ', ')" 'WARN'
        if ($why) { Write-VaultLog "  last error: $why" 'WARN' }
        if ($lastResp) {
            $props = @()
            try { $props = @($lastResp.PSObject.Properties | ForEach-Object { $_.Name }) } catch { }
            Write-VaultLog "  $lastName returned: $($props -join ', ')" 'WARN'
            $raw = "$(Get-VaultField $lastResp 'raw' '')"
            if (-not $raw) { try { $raw = ($lastResp | ConvertTo-Json -Depth 4 -Compress) } catch { } }
            if ($raw.Length -gt 600) { $raw = $raw.Substring(0, 600) + ' ...' }
            Write-VaultLog "  $raw" 'WARN'
        }
    }

    $script:DocTypeDefaults[$cacheKey] = $out
    return $out
}

function Get-VaultRedundantUserCount {
    # How many of these users are already in at least one of these groups.
    #
    # Counted per USER, not per membership row. Counting per row reported 1,449 redundant
    # out of 1,430 total on a real run - a subset larger than the set it is part of -
    # because anyone in two of the groups was counted twice. A number that cannot be true
    # discredits the finding it exists to support.
    param(
        [Parameter(Mandatory)]$Directory,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Groups,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Users
    )
    if (-not $Users.Count -or -not $Groups.Count) { return 0 }
    $covered = @{}
    foreach ($g in $Groups) {
        if (-not $Directory.Members.ContainsKey("$g")) { continue }
        foreach ($m in $Directory.Members["$g"]) { $covered["$m"] = $true }
    }
    return @($Users | Where-Object { $covered.ContainsKey("$_") }).Count
}

function Get-VaultDisplayName {
    param([Parameter(Mandatory)]$Directory, [Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Id)
    $k = "$Kind`:$Id"
    if ($Directory.ById.ContainsKey($k)) { return $Directory.ById[$k] }
    return $Id
}

function Resolve-VaultNameToId {
    param([Parameter(Mandatory)]$Directory, [Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Name)
    $n = $Name.Trim()
    if (-not $n) { return '' }
    if ($n -match '^\d+$') { return $n }      # already an id
    foreach ($k in @("$Kind`:$(ConvertTo-VaultKey $n)", "$Kind`:$(ConvertTo-VaultNameKey $n)")) {
        if ($Directory.ByName.ContainsKey($k)) { return $Directory.ByName[$k] }
    }
    return ''
}


# ======================================================================================
#  The desired state
#
#  Two sources, one shape. Without -Defaults it is whatever Vault reports as the defaults
#  for that document, which is the better answer when it is right because Vault has
#  already evaluated the override conditions. With -Defaults it is a table transcribed
#  from Admin > Document Types > Security, which is the better answer when it is not.
# ======================================================================================

function Import-VaultDefaultsTable {
    # role,users,groups[,subtype] - names or ids, either spelling.
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Directory)

    $f = Import-VaultDelimitedFile -Path $Path
    $col = @{}
    foreach ($n in $f.Names) {
        switch (ConvertTo-VaultKey $n) {
            'role'    { $col['role'] = $n }
            'users'   { $col['users'] = $n }
            'user'    { $col['users'] = $n }
            'groups'  { $col['groups'] = $n }
            'group'   { $col['groups'] = $n }
            'subtype' { $col['subtype'] = $n }
        }
    }
    if (-not $col.ContainsKey('role')) {
        throw "The defaults table needs a 'role' column. $($f.Path) has: $($f.Names -join ', ')."
    }
    if (-not $col.ContainsKey('users') -and -not $col.ContainsKey('groups')) {
        throw "The defaults table needs a 'users' or a 'groups' column. $($f.Path) has: $($f.Names -join ', ')."
    }

    $table   = New-Object System.Collections.ArrayList
    $unknown = New-Object System.Collections.ArrayList

    foreach ($row in $f.Rows) {
        $roleName = "$(Get-VaultField $row $col['role'] '')".Trim()
        if (-not $roleName) { continue }

        $users  = New-Object System.Collections.ArrayList
        $groups = New-Object System.Collections.ArrayList
        foreach ($pair in @(@{ Kind = 'user'; Col = 'users'; Bag = $users },
                            @{ Kind = 'group'; Col = 'groups'; Bag = $groups })) {
            if (-not $col.ContainsKey($pair.Col)) { continue }
            $raw = "$(Get-VaultField $row $col[$pair.Col] '')"
            foreach ($piece in ($raw -split '[,;|]')) {
                $name = $piece.Trim().Trim('"', "'")
                if (-not $name) { continue }
                $id = Resolve-VaultNameToId -Directory $Directory -Kind $pair.Kind -Name $name
                if ($id) { [void]$pair.Bag.Add($id) }
                else     { [void]$unknown.Add("$($pair.Kind) '$name' (role $roleName)") }
            }
        }

        [void]$table.Add([pscustomobject]@{
            RoleKey = ConvertTo-VaultKey $roleName
            RoleRaw = $roleName
            Subtype = if ($col.ContainsKey('subtype')) { ConvertTo-VaultKey "$(Get-VaultField $row $col['subtype'] '')" } else { '' }
            Users   = @($users)
            Groups  = @($groups)
        })
    }

    if ($unknown.Count) {
        # Refuse. A name that resolved to nothing means a role silently gets fewer people
        # than the screen says it should, and the run still reports success - which is
        # exactly the failure this script exists to fix.
        $show = ($unknown | Select-Object -Unique | Select-Object -First 10) -join "`n    "
        throw @"
$($unknown.Count) name(s) in $($f.Path) match no user or group in this vault:

    $show

Check the spelling against Admin > Users & Groups. Ids are accepted too, if a name is
ambiguous.
"@
    }
    if ($table.Count -eq 0) { throw "No usable rows in $($f.Path)" }

    Write-VaultLog "$($table.Count) default rule(s) from $($f.Path)" 'OK'
    return @($table)
}

function Get-VaultDesiredForRole {
    # What this role should hold on this document, as two lists of ids, from whichever
    # source -DesiredFrom named. Every branch returns the same shape plus a Which/Message
    # pair saying where the answer came from, because that is what goes in the report and
    # it is the only way anyone can audit an assignment after the fact.
    param(
        [Parameter(Mandatory)][ValidateSet('Lifecycle', 'Document', 'Table')][string]$From,
        [Parameter(Mandatory)]$RoleRecord,
        [AllowNull()]$Table,
        [AllowNull()]$Rules,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Subtype,
        [AllowNull()]$DocumentInfo
    )
    $nameKey  = ConvertTo-VaultKey "$(Get-VaultField $RoleRecord 'name' '')"
    $labelKey = ConvertTo-VaultKey "$(Get-VaultField $RoleRecord 'label' '')"
    # The rules index is keyed name-tolerantly, so the lookup has to be too.
    $roleNameKey = ConvertTo-VaultNameKey "$(Get-VaultField $RoleRecord 'name' '')"

    switch ($From) {

        'Document' {
            # Whatever Vault itself calls the default for this document. Cheapest, and it
            # needs no rule interpretation at all - but see -Probe for whether it carries
            # the document type's default security as well as the lifecycle's rules.
            return [pscustomobject]@{
                Users   = @(@(Get-VaultField $RoleRecord 'defaultUsers'  @()) | ForEach-Object { "$_" })
                Groups  = @(@(Get-VaultField $RoleRecord 'defaultGroups' @()) | ForEach-Object { "$_" })
                Which   = 'DOCUMENT_DEFAULT'
                Message = ''
            }
        }

        'Lifecycle' {
            if ($null -eq $Rules -or $null -eq $DocumentInfo) {
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_RULES'
                                          Message = 'the lifecycle rules were not read' }
            }
            if (-not $DocumentInfo.Read) {
                # The document could not be read, so which override applies is unknown.
                # Falling back to the default rule here would be the dangerous kind of
                # guess: an override exists precisely because the default is wrong for
                # some documents, and this may be one of them.
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'DOCUMENT_UNREADABLE'
                                          Message = 'could not read the document, so no rule can be chosen for it' }
            }
            if (-not $DocumentInfo.Lifecycle) {
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_LIFECYCLE'
                                          Message = 'the document reports no lifecycle' }
            }
            $key = "$(ConvertTo-VaultNameKey $DocumentInfo.Lifecycle)|$roleNameKey"
            if (-not $Rules.ContainsKey($key)) {
                # Not an error. Most lifecycles configure rules for a few roles only, and
                # a role with no rule simply has no default - there is nothing to apply.
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_RULE_FOR_ROLE'; Message = '' }
            }
            return (Select-VaultRuleForDocument -Rule $Rules[$key] -Conditions $DocumentInfo.Conditions)
        }

        default {
            $users  = New-Object System.Collections.ArrayList
            $groups = New-Object System.Collections.ArrayList
            foreach ($rule in @($Table)) {
                if ($rule.RoleKey -ne $nameKey -and $rule.RoleKey -ne $labelKey) { continue }
                # A subtype-less rule applies everywhere; a subtype-bearing one only to its own.
                if ($rule.Subtype -and $rule.Subtype -ne $Subtype) { continue }
                foreach ($u in $rule.Users)  { [void]$users.Add($u) }
                foreach ($g in $rule.Groups) { [void]$groups.Add($g) }
            }
            return [pscustomobject]@{ Users = @($users); Groups = @($groups); Which = 'TABLE'; Message = '' }
        }
    }
}


# ======================================================================================
#  Results - rewritten after every batch, so an interrupted run leaves a usable file
# ======================================================================================

function Get-VaultDocumentRole {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$DocId
    )
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path "/objects/documents/$DocId/roles"
    return @(Get-VaultField $r 'documentRoles' @())
}

# The fields an override rule can be conditioned on. Read from every document so an
# override can be matched against it; eTMF adds the two study fields, and a vault without
# them simply reports nothing there.
$script:ConditionFields = @('product__v', 'country__v', 'study__v', 'study_country__v')

function Get-VaultDocumentInfo {
    # Type, subtype, lifecycle, and the fields an override rule can turn on. One extra
    # read per document - unavoidable in Lifecycle mode, since the rule that applies is a
    # property of the document, not of the map.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$DocId)
    try {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/objects/documents/$DocId"
        $d = Get-VaultField $r 'document' $null
        $type    = "$(Get-VaultField $d 'type__v' '')"
        $subtype = "$(Get-VaultField $d 'subtype__v' '')"
        # The third level. A vault that does not use classifications reports nothing
        # here and everything below behaves exactly as it did.
        $classification = "$(Get-VaultField $d 'classification__v' '')"
        # A type with no subtypes configured reports none. Falling back to the type keeps
        # every document in exactly one bucket, which is what the grouping needs.
        if (-not $subtype) { $subtype = $type }

        # Every one of these is multi-value in some vaults and single in others, so read
        # them all as lists. Matching a scalar against a list works either way; the
        # reverse does not.
        $cond = @{}
        foreach ($f in $script:ConditionFields) {
            $cond[$f] = @(@(Get-VaultField $d $f @()) | ForEach-Object { "$_" } | Where-Object { $_ })
        }

        return [pscustomobject]@{
            Type       = $type
            Subtype    = $subtype
            Classification = $classification
            Lifecycle  = "$(Get-VaultField $d 'lifecycle__v' '')"
            Conditions = $cond
            Read       = $true
        }
    }
    catch {
        Write-VaultLog "  could not read document ${DocId}: $_" 'WARN'
        $cond = @{}
        foreach ($f in $script:ConditionFields) { $cond[$f] = @() }
        return [pscustomobject]@{ Type = ''; Subtype = ''; Lifecycle = ''; Conditions = $cond; Read = $false }
    }
}

function Get-VaultRoleAssignmentRule {
    # GET /configuration/role_assignment_rule - every lifecycle role's default and
    # override rules, in one call. Indexed by lifecycle and role.
    #
    # This endpoint speaks in NAMES (ally@veepharm.com, global_products_team__c) while the
    # document roles endpoint speaks in ids, so everything is resolved to ids here and the
    # two become comparable. That comparison is the whole point of the probe.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Directory)

    $byKey = @{}
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path '/configuration/role_assignment_rule'

    $unresolved = New-Object System.Collections.ArrayList

    foreach ($rule in @(Get-VaultField $r 'data' @())) {
        $lc   = "$(Get-VaultField $rule 'lifecycle__v' '')"
        $role = "$(Get-VaultField $rule 'role__v' '')"
        if (-not $lc -or -not $role) { continue }

        # A row carrying product/country/study is an OVERRIDE row; one carrying none is
        # the default. They must never be merged: an override REPLACES the default when
        # its condition is met, so adding them together would invent a rule Vault does not
        # have and hand people access the configuration never granted.
        $conds = @{}
        foreach ($f in $script:ConditionFields) {
            $v = "$(Get-VaultField $rule $f '')"
            if ($v) { $conds[$f] = $v }
        }

        # allowed_default_* is what Vault ASSIGNS automatically. allowed_* is the wider
        # set a person MAY be added to later, by hand. Only the first is a default, and
        # applying the second would put everyone who could ever be on the document onto
        # every document.
        $users  = New-Object System.Collections.ArrayList
        $groups = New-Object System.Collections.ArrayList
        foreach ($pair in @(@{ Field = 'allowed_default_users__v';  Kind = 'user';  Bag = $users },
                            @{ Field = 'allowed_default_groups__v'; Kind = 'group'; Bag = $groups })) {
            foreach ($n in @(Get-VaultField $rule $pair.Field @())) {
                $name = "$n"
                if (-not $name) { continue }
                $id = Resolve-VaultNameToId -Directory $Directory -Kind $pair.Kind -Name $name
                if ($id) { [void]$pair.Bag.Add($id) }
                else     { [void]$unresolved.Add("$($pair.Kind) '$name' ($lc / $role)") }
            }
        }

        $key = "$(ConvertTo-VaultNameKey $lc)|$(ConvertTo-VaultNameKey $role)"
        if (-not $byKey.ContainsKey($key)) {
            $byKey[$key] = [pscustomobject]@{
                Lifecycle = $lc; Role = $role
                Users = @(); Groups = @(); HasDefault = $false
                Overrides = (New-Object System.Collections.ArrayList)
            }
        }
        if ($conds.Count) {
            [void]$byKey[$key].Overrides.Add([pscustomobject]@{
                Conditions = $conds; Users = @($users); Groups = @($groups)
            })
        }
        else {
            $byKey[$key].Users      = @($users)
            $byKey[$key].Groups     = @($groups)
            $byKey[$key].HasDefault = $true
        }
    }

    if ($unresolved.Count) {
        # Not fatal - a rule may name a user who has since been deactivated, and that must
        # not stop the other rules being applied. But it is said out loud, because the
        # alternative is a role quietly getting fewer people than the configuration says.
        $show = ($unresolved | Select-Object -Unique | Select-Object -First 5) -join '; '
        Write-VaultLog "$($unresolved.Count) name(s) in the rules match no active user or group and are skipped: $show" 'WARN'
    }

    $overrides = (@($byKey.Values) | ForEach-Object { $_.Overrides.Count } | Measure-Object -Sum).Sum
    Write-VaultLog "$($byKey.Count) lifecycle/role rule(s) from /configuration/role_assignment_rule, $overrides override row(s)" 'OK'
    return $byKey
}

function Select-VaultRuleForDocument {
    # Which row of a lifecycle role's rules applies to THIS document.
    #
    # An override applies when the document carries every value the override names. More
    # than one can match - a product-only rule and a product-and-country rule - and Vault
    # takes the more specific. A tie between two equally specific overrides is not
    # something this can resolve, so it refuses rather than picking one: guessing here
    # means granting access to the wrong people.
    param([Parameter(Mandatory)]$Rule, [Parameter(Mandatory)][hashtable]$Conditions)

    $best = $null; $bestScore = -1; $tied = $false
    foreach ($ov in $Rule.Overrides) {
        $matched = $true
        foreach ($f in $ov.Conditions.Keys) {
            $have = @()
            if ($Conditions.ContainsKey($f)) { $have = @($Conditions[$f]) }
            if ($have -notcontains $ov.Conditions[$f]) { $matched = $false; break }
        }
        if (-not $matched) { continue }
        $score = $ov.Conditions.Count
        if ($score -gt $bestScore) { $best = $ov; $bestScore = $score; $tied = $false }
        elseif ($score -eq $bestScore) { $tied = $true }
    }

    if ($tied) {
        return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'AMBIGUOUS_OVERRIDE'
                                  Message = 'two override rules match this document equally well - Vault must be asked which wins' }
    }
    if ($best) {
        return [pscustomobject]@{ Users = @($best.Users); Groups = @($best.Groups); Which = 'OVERRIDE'
                                  Message = (($best.Conditions.Keys | Sort-Object | ForEach-Object { "$_=$($best.Conditions[$_])" }) -join ', ') }
    }
    if (-not $Rule.HasDefault) {
        return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_DEFAULT_RULE'
                                  Message = 'the role has override rules but no default, and none of the overrides match' }
    }
    return [pscustomobject]@{ Users = @($Rule.Users); Groups = @($Rule.Groups); Which = 'DEFAULT'; Message = '' }
}

function ConvertTo-VaultCsvField {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return '"' + ($Value -replace '"', '""') + '"'
}

function Send-VaultRoleBatch {
    # POST /objects/documents/roles/batch, as CSV.
    #
    # Batched by which COLUMNS a document needs, not just by count. The endpoint takes one
    # header for the whole batch, so mixing documents that need different roles would mean
    # blank cells - and nothing in Vault's documentation says what a blank cell in a
    # role column does. Grouping by shape removes the question rather than betting on it.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Items,
        [Parameter(Mandatory)][string[]]$Columns
    )
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine((@('id') + $Columns | ForEach-Object { ConvertTo-VaultCsvField $_ }) -join ',')
    foreach ($it in $Items) {
        $cells = @(ConvertTo-VaultCsvField $it.DocId)
        foreach ($cn in $Columns) { $cells += ConvertTo-VaultCsvField ($it.Cells[$cn] -join ',') }
        [void]$sb.AppendLine($cells -join ',')
    }

    # Sent as bytes with the charset stated. Windows PowerShell 5.1 will encode a string
    # body as ISO-8859-1 when the content type names no charset, which is the wrong answer
    # for a file the API requires to be UTF-8.
    $bytes = [Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
            -Path '/objects/documents/roles/batch' -Body $bytes -ContentType 'text/csv; charset=UTF-8'

    $byDoc = @{}
    foreach ($entry in @(Get-VaultField $r 'data' @())) {
        $id = "$(Get-VaultField $entry 'id' '')"
        if (-not $id) { continue }
        $ok = ((Get-VaultField $entry 'responseStatus' '') -eq 'SUCCESS')
        $msg = ''
        if (-not $ok) {
            $errs = @(Get-VaultField $entry 'errors' @())
            $msg = (($errs | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join '; ')
            if (-not $msg) { $msg = 'Vault reported FAILURE with no message' }
        }
        $byDoc[$id] = [pscustomobject]@{ Ok = $ok; Message = $msg }
    }
    return $byDoc
}
function Invoke-VaultRolesSurvey {
    # What is actually in scope, exactly, in about five seconds.
    #
    # This exists because the alternative was sampling: probing 300 documents at two reads
    # each to GUESS at the subtype list, when one paginated query returns every document's
    # type and subtype at 1,000 a page. Sixteen calls instead of six hundred, and the
    # answer is exact rather than "the subtypes that happened to be in the sample".
    #
    # No document is read individually and nothing is written.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][AllowEmptyString()][string]$Where)

    $c = $Context
    $w = $Where.Trim()
    $vql = if (-not $w) { 'SELECT id, type__v, subtype__v, lifecycle__v FROM documents' }
           else         { "SELECT id, type__v, subtype__v, lifecycle__v FROM documents WHERE $w" }
    Write-VaultLog "Surveying: $vql"

    $tally = @{}
    $total = 0
    $path  = '/query'
    $body  = "q=$([Uri]::EscapeDataString($vql))"
    $pages = 0

    while ($path -and $pages -lt 2000) {
        $pages++
        $r = if ($pages -eq 1) {
                Invoke-VaultApi -VaultHost $c.VaultHost -ApiVersion $c.Api -Method POST `
                    -Path $path -Body $body -ContentType 'application/x-www-form-urlencoded'
             } else {
                Invoke-VaultApi -VaultHost $c.VaultHost -ApiVersion $c.Api -Method GET -Path $path
             }
        foreach ($row in @(Get-VaultField $r 'data' @())) {
            $total++
            $ty  = "$(Get-VaultField $row 'type__v' '(no type)')"
            $sub = "$(Get-VaultField $row 'subtype__v' '')"
            if (-not $sub) { $sub = $ty }
            $lc  = "$(Get-VaultField $row 'lifecycle__v' '(no lifecycle)')"
            $k = "$ty|$sub"
            if (-not $tally.ContainsKey($k)) {
                $tally[$k] = [pscustomobject]@{
                    Type = $ty; Subtype = $sub; Count = 0
                    Lifecycles = (New-Object System.Collections.ArrayList)
                }
            }
            $tally[$k].Count++
            if ($tally[$k].Lifecycles -notcontains $lc) { [void]$tally[$k].Lifecycles.Add($lc) }
        }
        $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$total document(s) in scope, $($tally.Count) type/subtype combination(s), read in $pages page(s)"
    Write-VaultLog ''
    foreach ($k in ($tally.Keys | Sort-Object { -$tally[$_].Count })) {
        $e = $tally[$k]
        Write-VaultLog ("  {0,7:N0}  {1}" -f $e.Count, $(if ($e.Subtype -eq $e.Type) { $e.Type } else { "$($e.Type) / $($e.Subtype)" }))
        Write-VaultLog ("           lifecycle: {0}" -f (($e.Lifecycles | Sort-Object) -join ', '))
    }
    Write-VaultLog ''
    # Type defaults are cached per type and subtype, so this count IS the number of extra
    # calls the assign run makes for them - not one per document.
    Write-VaultLog "An assign run over this scope reads $total document(s) and resolves type defaults $($tally.Count) time(s)."
    $mins = [math]::Round((($total + $tally.Count * 3) * 0.3) / 60, 0)
    Write-VaultLog "At the rate this vault has been answering, that is roughly $mins minute(s)."
    return 0
}

function Invoke-VaultRolesProbe {
    # Read-only. Answers the questions that have to be answered before anything is
    # written, and answers them from the vault rather than from an assumption:
    #
    #   1. Which document types and subtypes does the map actually span?
    #   2. Within a subtype, do all documents report the same defaults? If they do, the
    #      subtype has one rule and a defaults table can be written for it. If they do
    #      not, something is conditional and a flat table would be wrong.
    #   3. Does defaultUsers/defaultGroups carry MORE than the lifecycle's role assignment
    #      rules? If it does, it is also carrying the document type's default security,
    #      and -Defaults is unnecessary. If it matches the lifecycle rules exactly, then
    #      the type defaults are NOT in there and -Defaults is the only way to apply them.
    #
    # It writes the discovered subtype/role/groups table out as a starter defaults file,
    # so the answer to (2) can be checked against the Admin screen side by side.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][array]$Documents, [int]$Limit = 0)

    $c   = $Context
    $dir = Get-VaultDirectory -Context $c

    $rules = @{}
    try { $rules = Get-VaultRoleAssignmentRule -Context $c -Directory $dir }
    catch { Write-VaultLog "Could not read the lifecycle role assignment rules: $_" 'WARN' }

    # Everything handed in, unless -Limit says otherwise. The scope was decided before
    # this function was called; it does not get to second-guess it.
    $docs = $Documents
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - surveying the first $Limit of $($docs.Count) document(s)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-VaultLog "$($docs.Count) document(s) to survey - two reads each"

    # subtypeKey -> role name -> what was seen
    $seen    = [ordered]@{}
    $rows    = New-Object System.Collections.ArrayList
    $errors  = 0
    $lifecyclesSeen = @{}
    $beyond  = 0    # roles whose document defaults exceed the lifecycle rule
    $equal   = 0    # roles whose document defaults match the lifecycle rule exactly
    $i = 0

    foreach ($doc in $docs) {
        $i++
        $docId = $doc.TargetId
        $info  = Get-VaultDocumentInfo -Context $c -DocId $docId
        if (-not $info.Subtype) { $errors++; continue }

        try { $roles = @(Get-VaultDocumentRole -Context $c -DocId $docId) }
        catch { Write-VaultLog "[$i/$($docs.Count)] doc $docId - ERROR reading roles: $_" 'ERROR'; $errors++; continue }

        if ($info.Lifecycle) { $lifecyclesSeen[$info.Lifecycle] = $true }
        $sk = ConvertTo-VaultKey $info.Subtype
        if (-not $seen.Contains($sk)) {
            $seen[$sk] = [pscustomobject]@{
                Subtype = $info.Subtype; Type = $info.Type
                Lifecycles = New-Object System.Collections.ArrayList
                Docs = 0
                Roles = [ordered]@{}
            }
        }
        $bucket = $seen[$sk]
        $bucket.Docs++
        if ($info.Lifecycle -and $bucket.Lifecycles -notcontains $info.Lifecycle) { [void]$bucket.Lifecycles.Add($info.Lifecycle) }

        foreach ($r in $roles) {
            $name  = "$(Get-VaultField $r 'name' '')"
            $label = "$(Get-VaultField $r 'label' $name)"
            if (-not $name) { continue }

            $defUsers  = @(@(Get-VaultField $r 'defaultUsers'  @()) | ForEach-Object { "$_" })
            $defGroups = @(@(Get-VaultField $r 'defaultGroups' @()) | ForEach-Object { "$_" })
            $asgUsers  = @(@(Get-VaultField $r 'assignedUsers' @()) | ForEach-Object { "$_" })
            $asgGroups = @(@(Get-VaultField $r 'assignedGroups' @()) | ForEach-Object { "$_" })

            # What the lifecycle's own default rule says, for the same role.
            # The rule that actually applies to THIS document - the matching override if
            # one matches, the default otherwise. Comparing against the default row alone
            # would report a false "beyond the rule" on every document an override covers.
            $ruleUsers = @(); $ruleGroups = @(); $overrides = 0; $haveRule = $false
            $which = ''
            $rk = "$(ConvertTo-VaultNameKey $info.Lifecycle)|$(ConvertTo-VaultNameKey $name)"
            if ($rules.ContainsKey($rk)) {
                $haveRule  = $true
                $overrides = $rules[$rk].Overrides.Count
                $applied   = Select-VaultRuleForDocument -Rule $rules[$rk] -Conditions $info.Conditions
                $ruleUsers  = @($applied.Users)
                $ruleGroups = @($applied.Groups)
                $which      = $applied.Which
            }

            $extraUsers  = @($defUsers  | Where-Object { $ruleUsers  -notcontains $_ })
            $extraGroups = @($defGroups | Where-Object { $ruleGroups -notcontains $_ })
            $verdict = 'NO_RULE'
            if ($haveRule) {
                if ($extraUsers.Count -or $extraGroups.Count) { $verdict = 'BEYOND_LIFECYCLE_RULE'; $beyond++ }
                else { $verdict = 'MATCHES_LIFECYCLE_RULE'; $equal++ }
            }

            $sig = ((@($defUsers | Sort-Object) -join ',') + '/' + (@($defGroups | Sort-Object) -join ','))
            if (-not $bucket.Roles.Contains($name)) {
                $bucket.Roles[$name] = [pscustomobject]@{
                    Label = $label
                    Users = $defUsers; Groups = $defGroups
                    Signature = $sig; Consistent = $true
                }
            }
            elseif ($bucket.Roles[$name].Signature -ne $sig) { $bucket.Roles[$name].Consistent = $false }

            [void]$rows.Add([pscustomobject][ordered]@{
                DocId = $docId; SourceDocId = $doc.SourceId
                Type = $info.Type; Subtype = $info.Subtype; Lifecycle = $info.Lifecycle
                Role = $name; RoleLabel = $label
                AssignedUsers  = ($asgUsers  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                AssignedGroups = ($asgGroups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                DefaultUsers   = ($defUsers  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                DefaultGroups  = ($defGroups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                LifecycleRuleUsers  = ($ruleUsers  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                LifecycleRuleGroups = ($ruleGroups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                OverrideRules = $overrides
                RuleApplied = $which
                Verdict = $verdict
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            })
        }
    }

    $reportPath = Join-Path $c.Out 'probe-report.csv'
    $rows | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    # The discovered table, in the shape -Defaults reads. Written whether or not the
    # defaults look trustworthy: it is a starting point to check against the screen, not
    # an answer to run unread.
    $defaultsPath = Join-Path $c.Out 'discovered-defaults.csv'
    $out = New-Object System.Collections.ArrayList
    foreach ($sk in $seen.Keys) {
        $b = $seen[$sk]
        foreach ($roleName in $b.Roles.Keys) {
            $r = $b.Roles[$roleName]
            if (-not $r.Users.Count -and -not $r.Groups.Count) { continue }
            [void]$out.Add([pscustomobject][ordered]@{
                subtype = $b.Subtype
                role    = $roleName
                users   = ($r.Users  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join ','
                groups  = ($r.Groups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join ','
            })
        }
    }
    if ($out.Count) { $out | Export-Csv -LiteralPath $defaultsPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false }

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($docs.Count) document(s) surveyed, $($seen.Count) subtype(s)"
    foreach ($sk in $seen.Keys) {
        $b = $seen[$sk]
        Write-VaultLog ''
        Write-VaultLog ("  {0}   ({1} document(s), lifecycle {2})" -f $b.Subtype, $b.Docs,
                   $(if ($b.Lifecycles.Count) { $b.Lifecycles -join ' / ' } else { '?' }))
        foreach ($roleName in $b.Roles.Keys) {
            $r = $b.Roles[$roleName]
            $bits = @()
            if ($r.Users.Count)  { $bits += 'users '  + (($r.Users  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join ', ') }
            if ($r.Groups.Count) { $bits += 'groups ' + (($r.Groups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join ', ') }
            $what = if ($bits.Count) { $bits -join ' + ' } else { 'no defaults reported' }
            $note = if (-not $r.Consistent) { '   *** documents in this subtype disagree - a flat table would be wrong ***' } else { '' }
            Write-VaultLog ("    {0,-24} {1}{2}" -f $roleName, $what, $note) $(if ($r.Consistent) { 'INFO' } else { 'WARN' })
        }
    }

    Write-VaultLog ''
    Write-VaultLog '----------------------------------------------------------------'
    if (-not $rules.Count) {
        Write-VaultLog 'The lifecycle role assignment rules could not be read, so no verdict on where the defaults come from.' 'WARN'
        Write-VaultLog 'Compare discovered-defaults.csv against Admin > Document Types > Security by hand.' 'WARN'
    }
    elseif ($beyond -gt 0) {
        Write-VaultLog "$beyond role(s) report defaults BEYOND the lifecycle's own rule." 'OK'
        Write-VaultLog 'So defaultUsers/defaultGroups carries more than the lifecycle rules - very likely the'
        Write-VaultLog 'document type default security too. Running without -Defaults should be right; confirm'
        Write-VaultLog 'on a few rows of probe-report.csv, then use -Plan.'
    }
    elseif ($equal -gt 0) {
        Write-VaultLog "Every role's defaults match its lifecycle rule exactly ($equal role(s) compared)." 'WARN'
        Write-VaultLog 'That is the signature of defaultUsers/defaultGroups carrying ONLY the lifecycle rules.'
        Write-VaultLog 'If the Admin screen shows groups that are not in probe-report.csv, they will NOT be'
        Write-VaultLog 'applied without -Defaults. Transcribe the screen, or start from discovered-defaults.csv.' 'WARN'
    }
    else {
        # Rules were read and documents were read, and not one pair joined. Saying nothing
        # here once let a probe look like a clean run while the entire rule lookup was
        # missing - and -DesiredFrom Lifecycle would then have assigned nobody, quietly,
        # after reading every document in the vault.
        Write-VaultLog 'NOT ONE role matched a lifecycle rule, though both were read.' 'ERROR'
        Write-VaultLog "  lifecycles on the documents:  $(($lifecyclesSeen.Keys | Sort-Object) -join ', ')" 'ERROR'
        Write-VaultLog "  lifecycles in the rules:      $((@($rules.Values | ForEach-Object { $_.Lifecycle }) | Select-Object -Unique | Sort-Object) -join ', ')" 'ERROR'
        Write-VaultLog '-DesiredFrom Lifecycle would assign NOTHING. Do not run it until these join.' 'ERROR'
    }
    if ($errors) { Write-VaultLog "$errors document(s) could not be read - the figures above are incomplete" 'ERROR' }
    Write-VaultLog ''
    Write-VaultLog "Report:            $reportPath"
    if ($out.Count) { Write-VaultLog "Starter defaults:  $defaultsPath" }
    return $errors
}

function Invoke-VaultRolesAssign {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Documents,
        [Parameter(Mandatory)][ValidateSet('Lifecycle', 'Document', 'Table')][string]$From,
        [AllowNull()]$Table,
        [AllowNull()]$Rules,
        # Declared, not inherited. These were script-scope parameters of a single-file
        # script; as a module function reaching for them would bind to whatever the
        # dispatcher happened to have in scope, which is how a switch belonging to one
        # command silently changes another.
        [ValidateSet('Both', 'Groups', 'Users')][string]$Assign = 'Both',
        [switch]$WithTypeDefaults,
        [switch]$Plan,
        [string[]]$Role = @(),
        [string[]]$ExcludeRole = @(),
        [int]$BatchSize = 200,
        [int]$Test = 0,
        [int]$Limit = 0,
        # Skip documents an earlier run already finished, instead of reading all of them
        # again. Off by default: reading current state is the safer thing to do, and the
        # only reason it is safe to stop doing it is that roles verify reads the vault
        # afterwards and says whether the claim was true.
        [switch]$Resume
    )

    $c   = $Context
    $dir = Get-VaultDirectory -Context $c

    # Lifecycle mode has to read each document: the rule that applies depends on the
    # document's own lifecycle and on the product/country/study an override turns on. A
    # subtype-keyed table needs the same read. Nothing else does, so nothing else pays.
    $needSubtype = ($From -eq 'Table') -and ($null -ne $Table) -and (@($Table | Where-Object { $_.Subtype }).Count -gt 0)
    $needInfo    = ($From -eq 'Lifecycle') -or $needSubtype -or $WithTypeDefaults

    $docs = $Documents
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - examining the first $Limit of $($docs.Count) document(s)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-VaultLog "$($docs.Count) document(s) in scope"
    if ($Resume) {
        # Said BEFORE the read, not after. The results file runs to tens of megabytes,
        # and loading it is a silent half minute - during which the only thing on screen
        # was a count of everything in scope, which is indistinguishable from a run that
        # ignored -Resume. Somebody watching that will kill it, and be right to.
        Write-VaultLog '-Resume: reading what earlier runs finished. A large results file takes a moment.' 'WARN'
    }

    # Prior rows are loaded either way - from the CSV and from the journal of a run that
    # was killed - because they are carried through into the results file. Whether they
    # SKIP anything is what -Resume decides.
    $res = New-VaultResults -Path (Join-Path $c.Out 'role-results.csv') `
               -KeyColumn 'Key' -DoneStatuses @() -Existing $c.Existing

    if ($Resume) {
        # A document counts as finished only if every row it has says the work is done.
        #
        # WOULD_ASSIGN is the trap. A plan run writes those rows to this same file, and
        # they mean the opposite of done - they are precisely the documents that need
        # assigning. Treating a row's mere existence as completion would skip every
        # document anybody had ever planned.
        #
        # ERROR and UNRESOLVED are not done either. Those are the ones most worth
        # retrying, so a resume that skipped them would quietly abandon exactly the
        # documents that failed.
        $finished = @{}
        foreach ($k in $res.Prior.Keys) {
            $row = $res.Prior[$k]
            $docId = "$(Get-VaultField $row 'DocId' '')"
            if (-not $docId) { continue }
            $st = "$(Get-VaultField $row 'Status' '')"
            if (-not $finished.ContainsKey($docId)) { $finished[$docId] = $true }
            if ($st -notin @('ASSIGNED', 'IN_STEP')) { $finished[$docId] = $false }
        }
        $doneIds = @{}
        foreach ($d in $finished.Keys) { if ($finished[$d]) { $doneIds[$d] = $true } }

        $before = $docs.Count
        $docs = @($docs | Where-Object { -not $doneIds.ContainsKey("$($_.TargetId)") })
        $skipped = $before - $docs.Count
        Write-VaultLog "-Resume: $($res.Prior.Count) row(s) read, covering $($finished.Count) document(s)"
        if ($skipped) {
            Write-VaultLog "-Resume: $skipped finished already - not read again. $($docs.Count) left to do." 'OK'
            Write-VaultLog 'roles verify is what confirms the skipped ones.' 'WARN'
        }
        else {
            Write-VaultLog '-Resume: none of them count as finished, so all of them are still to do.' 'WARN'
            Write-VaultLog 'A document counts only when every row says ASSIGNED or IN_STEP - a WOULD_ASSIGN row from a plan run does not.' 'WARN'
        }
    }
    Write-VaultLog "$($docs.Count) document(s) to examine"

    $stat = @{ Docs = 0; InStep = 0; NeedWork = 0; Changed = 0; Users = 0; Groups = 0
               Errors = 0; NoRoles = 0; RedundantUsers = 0 }
    $pending = New-Object System.Collections.ArrayList   # documents waiting for a batch
    $i = 0
    $stopped = $false

    function Submit-Pending {
        # Send everything queued, grouped by column shape, and record a row per document
        # and role. Called when a group fills up and once at the end.
        if (-not $pending.Count) { return }

        $groups = @{}
        foreach ($it in $pending) {
            $sig = ($it.Cells.Keys | Sort-Object) -join '|'
            if (-not $groups.ContainsKey($sig)) { $groups[$sig] = New-Object System.Collections.ArrayList }
            [void]$groups[$sig].Add($it)
        }

        Write-VaultLog "Writing $($pending.Count) document(s) to Vault"
        foreach ($sig in $groups.Keys) {
            $items   = @($groups[$sig])
            $columns = @($sig -split '\|')
            for ($off = 0; $off -lt $items.Count; $off += $BatchSize) {
                $slice = @($items[$off..([math]::Min($off + $BatchSize - 1, $items.Count - 1))])
                $byDoc = @{}
                $failAll = ''
                try {
                    $byDoc = Send-VaultRoleBatch -Context $c -Items $slice -Columns $columns
                }
                catch {
                    $failAll = "$_"
                    Write-VaultLog "Batch of $($slice.Count) document(s) failed: $_" 'ERROR'
                }

                foreach ($it in $slice) {
                    $ok = $false; $msg = $failAll
                    if (-not $failAll) {
                        if ($byDoc.ContainsKey($it.DocId)) { $ok = $byDoc[$it.DocId].Ok; $msg = $byDoc[$it.DocId].Message }
                        else { $msg = 'Vault returned no result for this document' }
                    }
                    if ($ok) {
                        $stat.Changed++
                        Write-VaultLog "  doc $($it.DocId) - assigned $($it.Summary)" 'OK'
                    }
                    else {
                        $stat.Errors++
                        Write-VaultLog "  doc $($it.DocId) - FAILED: $msg" 'ERROR'
                    }
                    foreach ($row in $it.Rows) {
                        $row.Status  = if ($ok) { 'ASSIGNED' } else { 'ERROR' }
                        $row.Message = $msg
                        [void]$res.Rows.Add($row)
                    }
                }
                Save-VaultResults -Results $res
            }
        }
        $pending.Clear()
    }

    :documents foreach ($doc in $docs) {
        $i++
        $docId  = $doc.TargetId
        $prefix = "[$i/$($docs.Count)] doc $docId"
        $stat.Docs++

        try { $roles = Get-VaultDocumentRole -Context $c -DocId $docId }
        catch {
            Write-VaultLog "$prefix - ERROR reading roles: $_" 'ERROR'
            $stat.Errors++
            # Same column set as every other row. Export-Csv takes its header from the
            # first object it sees, so a row of a different shape silently drops columns
            # from the whole file.
            [void]$res.Rows.Add([pscustomobject][ordered]@{
                Key = "$docId`:-"; DocId = $docId; SourceDocId = $doc.SourceId
                Lifecycle = ''; Type = ''; Subtype = ''; Role = ''; RoleLabel = ''
                RuleApplied = ''; RuleDetail = ''
                AssignedUsers = ''; AssignedGroups = ''; MissingUsers = ''; MissingGroups = ''
                Status = 'ERROR'; Message = "$_"; CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            })
            if (($i % $BatchSize) -eq 0) { Save-VaultResults -Results $res }
            continue
        }
        if (-not $roles.Count) {
            $stat.NoRoles++
            Write-VaultLog "$prefix - no roles reported" 'WARN'
            continue
        }

        $info    = if ($needInfo) { Get-VaultDocumentInfo -Context $c -DocId $docId } else { $null }
        $subtype = if ($needSubtype) { ConvertTo-VaultKey $info.Subtype } else { '' }

        $cells   = [ordered]@{}
        $rows    = New-Object System.Collections.ArrayList
        $summary = New-Object System.Collections.ArrayList
        $docNeedsWork = $false

        foreach ($r in $roles) {
            $name  = "$(Get-VaultField $r 'name' '')"
            $label = "$(Get-VaultField $r 'label' $name)"
            if (-not $name) { continue }

            $nk = ConvertTo-VaultKey $name; $lk = ConvertTo-VaultKey $label
            if ($Role.Count) {
                $wanted = @($Role | ForEach-Object { ConvertTo-VaultKey $_ })
                if ($wanted -notcontains $nk -and $wanted -notcontains $lk) { continue }
            }
            if ($ExcludeRole.Count) {
                $skip = @($ExcludeRole | ForEach-Object { ConvertTo-VaultKey $_ })
                if ($skip -contains $nk -or $skip -contains $lk) { continue }
            }

            $assignedUsers  = @(@(Get-VaultField $r 'assignedUsers'  @()) | ForEach-Object { "$_" })
            $assignedGroups = @(@(Get-VaultField $r 'assignedGroups' @()) | ForEach-Object { "$_" })
            $want = Get-VaultDesiredForRole -From $From -RoleRecord $r -Table $Table -Rules $Rules `
                        -Subtype $subtype -DocumentInfo $info

            # Document type default security is a SECOND source, not an alternative one.
            # The lifecycle rules and the type's "Default Settings for New Documents" are
            # two different screens, both of which the UI applies when it creates a
            # document - so repairing only one of them leaves the job half done.
            if ($WithTypeDefaults -and $info) {
                $td = Get-VaultDocTypeRoleDefault -Context $c -TypeLabel $info.Type `
                          -SubtypeLabel $info.Subtype -Directory $dir `
                          -ClassificationLabel $info.Classification
                if ($td.ContainsKey($name)) {
                    $want = [pscustomobject]@{
                        Users   = @(@($want.Users)  + @($td[$name].Users)  | Select-Object -Unique)
                        Groups  = @(@($want.Groups) + @($td[$name].Groups) | Select-Object -Unique)
                        Which   = $(if ($want.Which -in @('NO_RULE_FOR_ROLE', 'NO_RULES', '')) { 'TYPE_DEFAULT' }
                                    else { "$($want.Which)+TYPE_DEFAULT" })
                        Message = $want.Message
                    }
                }
            }

            $missingUsers  = @($want.Users  | Where-Object { $assignedUsers  -notcontains $_ } | Select-Object -Unique)
            $missingGroups = @($want.Groups | Where-Object { $assignedGroups -notcontains $_ } | Select-Object -Unique)

            # How many of those direct user assignments are just the membership of the
            # groups going on at the same time. A direct assignment outlives the group -
            # take someone out of the group and they keep the access - so writing hundreds
            # of thousands of them by accident is a mess that is hard to unpick later.
            $stat.RedundantUsers += (Get-VaultRedundantUserCount -Directory $dir -Groups $want.Groups -Users $missingUsers)

            if ($Assign -eq 'Groups') { $missingUsers  = @() }
            if ($Assign -eq 'Users')  { $missingGroups = @() }

            $row = [pscustomobject][ordered]@{
                Key = "$docId`:$name"; DocId = $docId; SourceDocId = $doc.SourceId
                # The facts this row's decision rested on. Recorded so veeva-validate.ps1
                # can confirm the premises later without re-running the reasoning.
                Lifecycle = $(if ($info) { $info.Lifecycle } else { '' })
                Type      = $(if ($info) { $info.Type }      else { '' })
                Subtype   = $(if ($info) { $info.Subtype }   else { '' })
                Role = $name; RoleLabel = $label
                RuleApplied = $want.Which; RuleDetail = $want.Message
                AssignedUsers  = ($assignedUsers  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                AssignedGroups = ($assignedGroups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                MissingUsers   = ($missingUsers   | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                MissingGroups  = ($missingGroups  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                Status = ''; Message = ''
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            }

            # A role whose rule could not be chosen is NOT the same as a role with nothing
            # to do, and must not be reported as in step. Nothing is written for it, and
            # it is counted as an error so the run's exit code is non-zero and the summary
            # says the figures are incomplete.
            if ($want.Which -in @('AMBIGUOUS_OVERRIDE', 'DOCUMENT_UNREADABLE', 'NO_LIFECYCLE', 'NO_DEFAULT_RULE')) {
                $row.Status  = 'UNRESOLVED'
                $row.Message = $want.Message
                $stat.Errors++
                Write-VaultLog "$prefix  $name  - $($want.Which): $($want.Message)" 'ERROR'
                [void]$res.Rows.Add($row)
                continue
            }

            if (-not $missingUsers.Count -and -not $missingGroups.Count) {
                $row.Status = 'IN_STEP'
                [void]$res.Rows.Add($row)
                continue
            }

            $docNeedsWork = $true
            $stat.Users  += $missingUsers.Count
            $stat.Groups += $missingGroups.Count

            $parts = @()
            if ($missingUsers.Count)  { $parts += "users $($row.MissingUsers)" }
            if ($missingGroups.Count) { $parts += "groups $($row.MissingGroups)" }
            [void]$summary.Add("$label ($($parts -join ', '))")
            # "needs", not "+". This line is printed when the gap is WORKED OUT, and the
            # write happens on the next batch flush - up to BatchSize documents later. A
            # line reading like an action, an hour before Vault has seen it, sent someone
            # to check a document in the UI and find nothing there. The confirmation is
            # the separate "assigned" line from Submit-Pending.
            Write-VaultLog "$prefix  $name  needs $($parts -join ' + ')"

            if ($missingUsers.Count)  { $cells["$name.users"]  = $missingUsers }
            if ($missingGroups.Count) { $cells["$name.groups"] = $missingGroups }

            $row.Status = if ($Plan) { 'WOULD_ASSIGN' } elseif ($c.WhatIf) { 'WHATIF' } else { 'PENDING' }
            [void]$rows.Add($row)
        }

        if (-not $docNeedsWork) {
            $stat.InStep++
        # Saved on a cadence, never per document. Save-VaultResults rewrites the WHOLE file,
        # so a save per document is quadratic: a verification pass, where every document
        # is in step, would rewrite a 110,000-row file 15,752 times. The point of saving
        # often is that an interrupted run leaves a usable file, and one save per batch
        # keeps that while costing a bounded amount.
            if (($i % $BatchSize) -eq 0) { Save-VaultResults -Results $res }
            continue
        }
        $stat.NeedWork++

        if ($Plan -or $c.WhatIf) {
            foreach ($row in $rows) { [void]$res.Rows.Add($row) }
            if (($i % $BatchSize) -eq 0) { Save-VaultResults -Results $res }
        }
        else {
            [void]$pending.Add([pscustomobject]@{
                DocId = $docId; Cells = $cells; Rows = @($rows); Summary = ($summary -join '; ')
            })
            if ($pending.Count -ge $BatchSize) { Submit-Pending }
        }

        if ($Test -gt 0) {
            $done = if ($Plan -or $c.WhatIf) { $stat.NeedWork } else { $stat.Changed + $pending.Count }
            if ($done -ge $Test) {
                Write-VaultLog "TEST: $done document(s) after examining $i - stopping" 'OK'
                $stopped = $true
                break documents
            }
        }
    }

    Submit-Pending
    Save-VaultResults -Results $res

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog ("examined {0}   already in step {1}   needing work {2}   no roles {3}" -f `
               $stat.Docs, $stat.InStep, $stat.NeedWork, $stat.NoRoles)
    if ($Plan -or $c.WhatIf) {
        $what = if ($Plan) { 'PLAN' } else { 'WhatIf' }
        Write-VaultLog "$what only - nothing was assigned. $($stat.Users) user and $($stat.Groups) group assignment(s) would be." 'OK'
        if ($stat.RedundantUsers -gt 0 -and $Assign -ne 'Groups') {
            Write-VaultLog ''
            Write-VaultLog "$($stat.RedundantUsers) of those $($stat.Users) user assignment(s) are people who are ALREADY" 'WARN'
            Write-VaultLog 'members of a group being assigned on the same document. Assigning them directly as' 'WARN'
            Write-VaultLog 'well outlives the group - take someone out of the group later and they keep the' 'WARN'
            Write-VaultLog 'access, because the direct assignment is still there. -Assign Groups writes only the' 'WARN'
            Write-VaultLog 'groups and leaves membership to do its job.' 'WARN'
        }
        # Errors are reported in every mode. A plan that could not read half the documents
        # is not a plan, and saying only "0 would be assigned" reads as good news rather
        # than as a run that never got off the ground.
        if ($stat.Errors) { Write-VaultLog "$($stat.Errors) document(s) could not be read - the figures above are incomplete" 'ERROR' }
    }
    else {
        Write-VaultLog ("Assigned on {0} document(s): {1} user and {2} group assignment(s). {3} failed." -f `
                   $stat.Changed, $stat.Users, $stat.Groups, $stat.Errors) $(if ($stat.Errors) { 'WARN' } else { 'OK' })
    }
    if ($stopped) { Write-VaultLog "TEST run - stopped after $i of $($docs.Count) document(s). NOT the whole set." 'WARN' }
    Write-VaultLog "Results: $($res.Path)"
    return $stat.Errors
}

function Get-VaultFoldedName {
    # Written independently of veeva-roles.ps1's ConvertTo-NameKey, and tested against the
    # same cases, because a shared folding bug would silently make both tools agree on the
    # wrong answer. Same contract: drop a trailing __c/__v/__sys, keep letters and digits,
    # lower case.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $s = $Value.Trim()
    foreach ($suffix in @('__c', '__v', '__sys')) {
        if ($s.EndsWith($suffix)) { $s = $s.Substring(0, $s.Length - $suffix.Length); break }
    }
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        if ([char]::IsLetterOrDigit($ch)) { [void]$sb.Append([char]::ToLowerInvariant($ch)) }
    }
    return $sb.ToString()
}




#
#  Built here rather than shared, and only groups are needed - this checks group
#  assignments, which is what -Assign Groups writes.
# ======================================================================================

function Get-VaultGroupIndex {
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion)
    $byName = @{}
    $byId   = @{}
    $r = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path '/objects/groups'
    foreach ($rec in @(Get-VaultField $r 'groups' @())) {
        $g = Get-VaultField $rec 'group' $null
        if ($null -eq $g) { $g = $rec }
        $id = "$(Get-VaultField $g 'id' '')"
        if (-not $id) { continue }
        foreach ($f in @('label__v', 'name__v')) {
            $n = "$(Get-VaultField $g $f '')"
            if (-not $n) { continue }
            $k = Get-VaultFoldedName $n
            if ($k -and -not $byName.ContainsKey($k)) { $byName[$k] = $id }
            if (-not $byId.ContainsKey($id)) { $byId[$id] = $n }
        }
    }
    Write-VaultLog "$($byId.Count) group(s) in this vault"
    return [pscustomobject]@{ ByName = $byName; ById = $byId }
}


# ======================================================================================
#  Current state, read through doc_role__sys
# ======================================================================================

function Get-VaultCurrentGroups {
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][array]$DocIds,
        # One document at a time instead of the bulk read, for a vault where the bulk
        # query is unavailable or disagrees with itself.
        [switch]$Slow
    )

    $byKey = @{}
    $bulk  = -not $Slow

    if ($bulk) {
        $chunk = 200
        for ($off = 0; $off -lt $DocIds.Count; $off += $chunk) {
            $slice = @($DocIds[$off..([math]::Min($off + $chunk - 1, $DocIds.Count - 1))])
            $vql = "SELECT document_id, role_name__sys, group__sys FROM doc_role__sys WHERE document_id CONTAINS ($($slice -join ','))"
            $path = '/query'
            $body = "q=$([Uri]::EscapeDataString($vql))"
            $pages = 0
            try {
                while ($path -and $pages -lt 500) {
                    $pages++
                    $r = if ($pages -eq 1) {
                            Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method POST -Path $path -Body $body `
                                -ContentType 'application/x-www-form-urlencoded' -MaxRetries 1
                         } else {
                            Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path $path -MaxRetries 1
                         }
                    foreach ($row in @(Get-VaultField $r 'data' @())) {
                        $d = "$(Get-VaultField $row 'document_id' '')"
                        $n = "$(Get-VaultField $row 'role_name__sys' '')"
                        $g = "$(Get-VaultField $row 'group__sys' '')"
                        if (-not $d -or -not $n -or -not $g) { continue }
                        $k = "$d|$(Get-VaultFoldedName $n)"
                        if (-not $byKey.ContainsKey($k)) { $byKey[$k] = @{} }
                        $byKey[$k][$g] = $true
                    }
                    $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
                }
            }
            catch {
                Write-VaultLog "doc_role__sys will not take that query, falling back to one read per document: $_" 'WARN'
                $bulk = $false
                break
            }
            Write-VaultLog "  read $([math]::Min($off + $chunk, $DocIds.Count)) of $($DocIds.Count)"
        }
    }

    if ($bulk) { return [pscustomobject]@{ ByKey = $byKey; Method = 'doc_role__sys (bulk)' } }

    # Fallback. Still not the same call the assign run made for its comparison - it reads
    # the roles endpoint, which is at least a different query - but the point of the bulk
    # path is that it is a genuinely separate route, so a fallback is worth saying out loud.
    $byKey = @{}
    $i = 0
    foreach ($docId in $DocIds) {
        $i++
        if (($i % 500) -eq 0) { Write-VaultLog "  read $i of $($DocIds.Count)" }
        try {
            $r = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path "/objects/documents/$docId/roles"
            foreach ($role in @(Get-VaultField $r 'documentRoles' @())) {
                $n = "$(Get-VaultField $role 'name' '')"
                if (-not $n) { continue }
                $k = "$docId|$(Get-VaultFoldedName $n)"
                if (-not $byKey.ContainsKey($k)) { $byKey[$k] = @{} }
                foreach ($g in @(Get-VaultField $role 'assignedGroups' @())) { $byKey[$k]["$g"] = $true }
            }
        }
        catch { Write-VaultLog "  could not read document ${docId}: $_" 'ERROR' }
    }
    return [pscustomobject]@{ ByKey = $byKey; Method = 'one read per document' }
}


function Get-VaultCurrentFacts {
    # type, subtype and lifecycle for a set of documents, in bulk.
    #
    # These are the INPUTS the run's decision rested on: the lifecycle picks the rule, the
    # type and subtype pick the MDL component. Confirming them checks the premises without
    # re-running the reasoning - which is the line this tool tries to hold. Re-deriving
    # what SHOULD be on a document would just be the same logic agreeing with itself.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion, [Parameter(Mandatory)][array]$DocIds)

    $byId  = @{}
    $chunk = 200
    for ($off = 0; $off -lt $DocIds.Count; $off += $chunk) {
        $slice = @($DocIds[$off..([math]::Min($off + $chunk - 1, $DocIds.Count - 1))])
        $vql = "SELECT id, type__v, subtype__v, lifecycle__v FROM documents WHERE id CONTAINS ($($slice -join ','))"
        $path = '/query'
        $body = "q=$([Uri]::EscapeDataString($vql))"
        $pages = 0
        try {
            while ($path -and $pages -lt 500) {
                $pages++
                $r = if ($pages -eq 1) {
                        Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method POST -Path $path -Body $body `
                            -ContentType 'application/x-www-form-urlencoded' -MaxRetries 1
                     } else {
                        Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path $path -MaxRetries 1
                     }
                foreach ($row in @(Get-VaultField $r 'data' @())) {
                    $id = "$(Get-VaultField $row 'id' '')"
                    if (-not $id) { continue }
                    $sub = "$(Get-VaultField $row 'subtype__v' '')"
                    $ty  = "$(Get-VaultField $row 'type__v' '')"
                    if (-not $sub) { $sub = $ty }
                    $byId[$id] = [pscustomobject]@{ Type = $ty; Subtype = $sub; Lifecycle = "$(Get-VaultField $row 'lifecycle__v' '')" }
                }
                $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
            }
        }
        catch {
            Write-VaultLog "Could not read document facts, so type and lifecycle go unchecked: $_" 'WARN'
            return @{}
        }
    }
    return $byId
}
# --------------------------------------------------------------------------------------
# The validator
#
# Proves that what a run RECORDED as assigned is actually on the documents. It does not
# work out what ought to be there - re-deriving that would be the same logic agreeing
# with itself, which proves nothing. It reads the claims out of the results file and
# checks them against the vault, along with the facts the run's decision rested on.
#
# A separate command, run when someone chooses to. Vault ignores group ids it cannot
# grant and still answers SUCCESS, so a run can report an assignment it did not make -
# which is exactly the failure this exists to find, and re-running the assign will not
# fix it.
# --------------------------------------------------------------------------------------

function Invoke-VaultRolesVerify {
    param(
        [Parameter(Mandatory)]$Context,
        [string]$ResultsFile = '',
        [switch]$Slow,
        [int]$Limit = 0,
        # The documents that were SUPPOSED to be done. Without it this reports how many
        # of its own claims held up, which is true and is not the question anyone is
        # asking - "14,928 confirmed" against an unstated denominator is a number, not
        # evidence.
        [string]$ExpectIds = '',
        # Check every document the run touched, not only the ones it changed. An IN_STEP
        # row records that the groups were ALREADY there - which is a statement about the
        # document just as much as an assignment is, and one nothing was checking.
        [switch]$All
    )
    $c = $Context

    $path = $ResultsFile
    if (-not $path) { $path = Join-Path $c.Out 'role-results.csv' }
    if (-not (Test-Path -LiteralPath $path)) {
        throw "No results file at $path. This checks what a run RECORDED; without one there is nothing to check."
    }
    Write-VaultLog "  results  $path"

    $rows = @(Import-Csv -LiteralPath $path)
    $statuses = @{}
    $claims = New-Object System.Collections.ArrayList
    foreach ($row in $rows) {
        $st = "$(Get-VaultField $row 'Status' '')"
        if ($st) { $statuses[$st] = 1 + $(if ($statuses.ContainsKey($st)) { $statuses[$st] } else { 0 }) }
        if ($All) {
            if ($st -notin @('ASSIGNED', 'IN_STEP')) { continue }
            # The full expected end state, from what the run itself recorded: the groups
            # it found already on the document plus the ones it added. No desired state is
            # re-derived here - that would be the same logic agreeing with itself, which
            # is the thing this tool exists not to do.
            $groups = ((@("$(Get-VaultField $row 'AssignedGroups' '')",
                          "$(Get-VaultField $row 'MissingGroups' '')") |
                        Where-Object { $_ }) -join ';')
        }
        else {
            if ($st -ne 'ASSIGNED') { continue }
            $groups = "$(Get-VaultField $row 'MissingGroups' '')"
        }
        if (-not $groups) { continue }
        [void]$claims.Add([pscustomobject]@{
            DocId     = "$(Get-VaultField $row 'DocId' '')"
            Role      = "$(Get-VaultField $row 'Role' '')"
            Lifecycle = "$(Get-VaultField $row 'Lifecycle' '')"
            Type      = "$(Get-VaultField $row 'Type' '')"
            Subtype   = "$(Get-VaultField $row 'Subtype' '')"
            Groups    = @($groups -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        })
    }
    Write-VaultLog "$($rows.Count) row(s): $((($statuses.Keys | Sort-Object) | ForEach-Object { "$_=$($statuses[$_])" }) -join ', ')"

    if (-not $claims.Count) {
        Write-VaultLog 'No ASSIGNED rows carrying groups. Nothing was claimed, so there is nothing to prove.' 'WARN'
        return 0
    }

    $docIds = @($claims | ForEach-Object { $_.DocId } | Select-Object -Unique)

    # Trimmed by DOCUMENT, then the claims are filtered to match - not the other way
    # round. Cutting the claim list first would leave a document half-checked, and a
    # document that is partly verified is the one thing worse than one that is not.
    if ($Limit -gt 0 -and $docIds.Count -gt $Limit) {
        Write-VaultLog "-n $Limit - checking the first $Limit of $($docIds.Count) document(s)" 'WARN'
        $docIds = @($docIds | Select-Object -First $Limit)
        $keep   = @{}
        foreach ($d in $docIds) { $keep[$d] = $true }
        $claims = @($claims | Where-Object { $keep.ContainsKey($_.DocId) })
    }

    if ($All) {
        Write-VaultLog '-All: checking the groups each row recorded as present OR assigned, not only the assignments.' 'WARN'
    }
    Write-VaultLog "$($claims.Count) claim(s) over $($docIds.Count) document(s)"

    $groups  = Get-VaultGroupIndex -VaultHost $c.VaultHost -ApiVersion $c.Api
    $current = Get-VaultCurrentGroups -VaultHost $c.VaultHost -ApiVersion $c.Api -DocIds $docIds -Slow:$Slow
    $facts   = Get-VaultCurrentFacts  -VaultHost $c.VaultHost -ApiVersion $c.Api -DocIds $docIds

    # One row per DOCUMENT, not per claim. A claim-level file for this scope runs to
    # hundreds of thousands of rows that nobody can scan; a document is the thing you
    # filter to a work list and then go and open in the UI. The detail is not lost - the
    # groups that failed are named in the row.
    $byDoc = @{}
    foreach ($claim in $claims) {
        if (-not $byDoc.ContainsKey($claim.DocId)) { $byDoc[$claim.DocId] = New-Object System.Collections.ArrayList }
        [void]$byDoc[$claim.DocId].Add($claim)
    }

    $out  = New-Object System.Collections.ArrayList
    $stat = @{ Documents = 0; Clean = 0; Missing = 0; Unresolved = 0
               LifecycleMismatch = 0; TypeMismatch = 0; NotChecked = 0
               ClaimsConfirmed = 0; ClaimsMissing = 0 }

    foreach ($docId in ($byDoc.Keys | Sort-Object)) {
        $stat.Documents++
        $docClaims = @($byDoc[$docId])

        $confirmed = 0
        $missing   = New-Object System.Collections.ArrayList
        $unres     = New-Object System.Collections.ArrayList
        $roles     = New-Object System.Collections.ArrayList

        foreach ($claim in $docClaims) {
            if ($roles -notcontains $claim.Role) { [void]$roles.Add($claim.Role) }
            $k    = "$docId|$(Get-VaultFoldedName $claim.Role)"
            $have = if ($current.ByKey.ContainsKey($k)) { $current.ByKey[$k] } else { @{} }
            foreach ($gName in $claim.Groups) {
                $gid = ''
                $fk  = Get-VaultFoldedName $gName
                if ($groups.ByName.ContainsKey($fk)) { $gid = $groups.ByName[$fk] }
                elseif ($gName -match '^\d+$')       { $gid = $gName }

                if (-not $gid)                   { [void]$unres.Add("$($claim.Role): $gName") }
                elseif ($have.ContainsKey($gid)) { $confirmed++ }
                else                             { [void]$missing.Add("$($claim.Role): $gName") }
            }
        }
        $stat.ClaimsConfirmed += $confirmed
        $stat.ClaimsMissing   += $missing.Count
        if ($unres.Count) { $stat.Unresolved++ }

        # The dimensions the run's decision rested on. Blank where the run did not record
        # them - older results files carry no Type or Subtype - which is reported as
        # NOT_RECORDED rather than quietly passing.
        $recLc  = "$($docClaims[0].Lifecycle)"
        $recTy  = "$($docClaims[0].Type)"
        $recSub = "$($docClaims[0].Subtype)"
        $now    = if ($facts.ContainsKey($docId)) { $facts[$docId] } else { $null }

        function Compare-Dimension {
            param([string]$Recorded, $Now, [string]$Field)
            if (-not $Recorded)  { return 'NOT_RECORDED' }
            if ($null -eq $Now)  { return 'NOT_CHECKED' }
            $current = "$(Get-VaultField $Now $Field '')"
            if (-not $current)   { return 'NOT_CHECKED' }
            if ((Get-VaultFoldedName $Recorded) -eq (Get-VaultFoldedName $current)) { return 'CONFIRMED' }
            return 'CHANGED'
        }

        $lcState  = Compare-Dimension -Recorded $recLc  -Now $now -Field 'Lifecycle'
        $tyState  = Compare-Dimension -Recorded $recTy  -Now $now -Field 'Type'
        $subState = Compare-Dimension -Recorded $recSub -Now $now -Field 'Subtype'

        if ($lcState -eq 'CHANGED') { $stat.LifecycleMismatch++ }
        if ($tyState -eq 'CHANGED' -or $subState -eq 'CHANGED') { $stat.TypeMismatch++ }
        if ($lcState -eq 'NOT_CHECKED') { $stat.NotChecked++ }

        $status =
            if ($missing.Count)                                  { $stat.Missing++; 'GROUPS_MISSING' }
            elseif ($lcState -eq 'CHANGED' -or $tyState -eq 'CHANGED' -or $subState -eq 'CHANGED') { 'DIMENSION_CHANGED' }
            elseif ($unres.Count)                                { 'NAMES_UNRESOLVED' }
            else                                                 { $stat.Clean++; 'CONFIRMED' }

        if ($status -ne 'CONFIRMED') {
            $why = if ($missing.Count) { ($missing | Select-Object -First 4) -join '; ' }
                   elseif ($unres.Count) { ($unres | Select-Object -First 4) -join '; ' }
                   else { "lifecycle $lcState, type $tyState, subtype $subState" }
            Write-VaultLog "  doc $docId - $status : $why" $(if ($status -eq 'GROUPS_MISSING') { 'ERROR' } else { 'WARN' })
        }

        [void]$out.Add([pscustomobject][ordered]@{
            DocId = $docId
            Status = $status
            RolesChecked = $roles.Count
            GroupsClaimed = $confirmed + $missing.Count + $unres.Count
            GroupsConfirmed = $confirmed
            GroupsMissing = $missing.Count
            MissingDetail = ($missing -join '; ')
            UnresolvedDetail = ($unres -join '; ')
            LifecycleRecorded = $recLc
            LifecycleNow = $(if ($now) { $now.Lifecycle } else { '' })
            LifecycleCheck = $lcState
            TypeRecorded = $recTy
            TypeNow = $(if ($now) { $now.Type } else { '' })
            TypeCheck = $tyState
            SubtypeRecorded = $recSub
            SubtypeNow = $(if ($now) { $now.Subtype } else { '' })
            SubtypeCheck = $subState
            CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
        })
    }

    $report = Join-Path $c.Out 'role-validate-results.csv'
    $out | Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($stat.Documents) document(s) checked, assignments read by $($current.Method)"
    Write-VaultLog ("  CONFIRMED           {0}" -f $stat.Clean) 'OK'
    if ($stat.Missing) {
        Write-VaultLog ("  GROUPS_MISSING      {0}  ({1} group assignment(s))" -f $stat.Missing, $stat.ClaimsMissing) 'ERROR'
        Write-VaultLog '  The run recorded these as assigned and the vault does not have them. Vault' 'ERROR'
        Write-VaultLog '  ignores ids it cannot grant and still reports SUCCESS, so re-running will not' 'ERROR'
        Write-VaultLog '  fix it. Check whether the account may grant those groups.' 'ERROR'
    }
    if ($stat.LifecycleMismatch) {
        Write-VaultLog ("  lifecycle changed   {0}  - not what the run saw, so its rule choice no longer holds" -f $stat.LifecycleMismatch) 'WARN'
    }
    if ($stat.TypeMismatch) {
        Write-VaultLog ("  type/subtype changed {0} - the run picked its type defaults from a different one" -f $stat.TypeMismatch) 'WARN'
    }
    if ($stat.Unresolved) {
        Write-VaultLog ("  NAMES_UNRESOLVED    {0}  - recorded under a name no group here answers to" -f $stat.Unresolved) 'WARN'
    }
    if ($stat.NotChecked) {
        Write-VaultLog ("  dimensions unchecked {0} - the document facts could not be read" -f $stat.NotChecked) 'WARN'
    }
    Write-VaultLog ("  {0} group assignment(s) confirmed in total" -f $stat.ClaimsConfirmed)
    if ($out.Count -and -not $out[0].TypeRecorded) {
        Write-VaultLog 'Type and subtype were NOT_RECORDED - this results file predates the run recording them.' 'WARN'
    }
    if (-not $stat.Missing -and -not $stat.Unresolved -and -not $stat.LifecycleMismatch -and -not $stat.TypeMismatch) {
        Write-VaultLog 'Every group the run recorded as assigned is on its document, on the facts it decided from.' 'OK'
    }
    Write-VaultLog "Report: $report"

    Write-VaultLog "Report: $report"

    # Every expected document in exactly one bucket, and the buckets that should be
    # empty named even when they are. Three different things were invisible in a bare
    # confirmed count: a document already correct and so never claimed, one that failed,
    # and one that was never processed at all. The first is fine and the other two are
    # not, and they looked identical.
    $unprocessed = 0
    if ($ExpectIds) {
        $expected = @(Import-VaultIdList -Path $ExpectIds)

        # What the results file knows about each expected document, whether or not this
        # verify had a claim to check.
        $seen   = @{}
        $failed = @{}
        foreach ($row in $rows) {
            $d = "$(Get-VaultField $row 'DocId' '')"
            if (-not $d) { continue }
            $seen[$d] = $true
            if ("$(Get-VaultField $row 'Status' '')" -in @('ERROR', 'UNRESOLVED')) { $failed[$d] = $true }
        }
        $claimed = @{}
        foreach ($cl in $claims) { $claimed["$($cl.DocId)"] = $true }

        $bChecked = @($expected | Where-Object { $claimed.ContainsKey("$_") }).Count
        $bFailed  = @($expected | Where-Object { $failed.ContainsKey("$_") -and -not $claimed.ContainsKey("$_") }).Count
        $bQuiet   = @($expected | Where-Object { $seen.ContainsKey("$_") -and -not $claimed.ContainsKey("$_") -and -not $failed.ContainsKey("$_") }).Count
        $missingIds = @($expected | Where-Object { -not $seen.ContainsKey("$_") })
        $unprocessed = $missingIds.Count

        Write-VaultLog '----------------------------------------------------------------'
        Write-VaultLog ("expected                      {0,7}   from $ExpectIds" -f $expected.Count)
        Write-VaultLog ("checked and CONFIRMED         {0,7}" -f ($bChecked - $stat.Missing - $stat.Unresolved)) 'OK'
        if ($stat.Missing -or $stat.Unresolved) {
            Write-VaultLog ("checked and NOT confirmed     {0,7}   the vault does not have them" -f ($stat.Missing + $stat.Unresolved)) 'ERROR'
        }
        Write-VaultLog ("in results, nothing claimed   {0,7}   already correct - nothing to verify" -f $bQuiet)
        if ($bFailed) { Write-VaultLog ("in results, failed            {0,7}   ERROR or UNRESOLVED" -f $bFailed) 'ERROR' }
        if ($unprocessed) {
            Write-VaultLog ("no record at all              {0,7}   NEVER PROCESSED" -f $unprocessed) 'ERROR'
            foreach ($line in (Format-VaultIdRows -Ids $missingIds)) { Write-VaultLog "  $line" 'ERROR' }
        }
        else {
            Write-VaultLog ("no record at all              {0,7}" -f 0) 'OK'
        }

        if (-not $unprocessed -and -not $bFailed -and -not $stat.Missing -and -not $stat.Unresolved) {
            Write-VaultLog 'Every expected document is accounted for, and everything claimed is on its document.' 'OK'
        }
    }
    else {
        Write-VaultLog 'No -ExpectIds given, so this says how many of its own claims held up and nothing about coverage.' 'WARN'
    }

    return ($stat.Missing + $unprocessed)
}

# --------------------------------------------------------------------------------------
# Scoping a permission sync
#
# A run that grants people access should never be able to reach further than it was told
# to. So the sync names WHOSE documents and HOW RECENT, both, every time - and the two
# together are a far tighter bound than either alone: one operator's work, in one window.
# --------------------------------------------------------------------------------------

function Get-VaultCreatedByScope {
    # The documents a named user created within the last N hours.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$CreatedBy,
        [Parameter(Mandatory)][int]$WithinHours,
        # Only needed to turn a NAME into an id. A numeric id needs nothing, and the
        # directory is every user and group in the vault - pages of calls against the
        # same burst allowance the run needs, spent on a lookup that was already done.
        [AllowNull()]$Directory,
        # Confirmed against endo-rim with `verify fields`, not taken from documentation:
        # document_creation_date__v is a DateTime and queryable, which is what makes an
        # hours-wide window expressible at all. created_date__v - which this used at
        # first - is a field on OBJECTS and does not exist on documents, and the vault
        # said so: "Unknown field 'created_date__v' in 'where clause'".
        [string]$DateField = 'document_creation_date__v',
        # An ObjectReference, which VQL compares by id.
        [string]$CreatorField = 'created_by__v'
    )
    # created_by__v holds a user ID, not a name - so a name has to be resolved, and a
    # name that resolves to nothing must stop the run. Falling back to "everyone" here
    # would turn the narrowest possible scope into the widest.
    if ($CreatedBy -match '^(?i)me$') {
        # The account doing the repair is usually the account that created the documents,
        # because both are the migration's own service user. Asking Vault who that is
        # costs one call and removes the step where somebody types the wrong id - which
        # would not fail, it would quietly repair somebody else's documents.
        $me = Get-VaultWhoAmI -VaultHost $Context.VaultHost -ApiVersion $Context.Api
        if (-not $me -or -not $me.UserId) {
            throw 'Could not ask the vault who this session belongs to, so -CreatedBy me cannot be resolved. Pass the numeric user id.'
        }
        $uid = $me.UserId
        $who = "$($me.User) (this session)"
    }
    elseif ($CreatedBy -match '^\d+$') {
        $uid = $CreatedBy
        $who = "user id $uid"
    }
    elseif (-not $Directory) {
        throw "'$CreatedBy' is not a user id or 'me', so it has to be looked up - and no directory was read. Pass the numeric id, or 'me' for this session's own user."
    }
    else {
        $uid = Resolve-VaultNameToId -Directory $Directory -Kind 'user' -Name $CreatedBy
        if (-not $uid) {
            throw "No user in this vault answers to '$CreatedBy'. created_by__v holds a user id, so the name has to resolve to one - check the spelling, or pass the id."
        }
        $who = Get-VaultDisplayName -Directory $Directory -Kind 'user' -Id $uid
    }

    # Hours before NOW, in UTC, because that is what Vault stores and compares against.
    # Both are logged: an operator reads the local time, and the query uses the other.
    $cutUtc   = (Get-Date).ToUniversalTime().AddHours(-1 * $WithinHours)
    $iso      = $cutUtc.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $cutLocal = $cutUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')

    Write-VaultLog "Scope: documents created by $who (id $uid)"
    Write-VaultLog "       in the last $WithinHours hour(s) - since $cutLocal local / $iso"
    Write-VaultLog "       matching on $CreatorField and $DateField"

    $vql = "SELECT id FROM documents WHERE $CreatorField = $uid AND $DateField > '$iso'"
    $docs = @(Get-VaultDocumentsByQuery -Context $Context -Where $vql)
    Write-VaultLog "$($docs.Count) document(s) match both conditions" 'OK'

    # A window wider than intended is the way this scope goes wrong, and it goes wrong
    # quietly - the run simply touches more than anyone meant. Said out loud rather than
    # left to be noticed in the results.
    if ($docs.Count -gt 5000) {
        Write-VaultLog "That is a lot for a $WithinHours hour window. Check the hours before letting this write." 'WARN'
    }
    return $docs
}

function Write-VaultScopeManifest {
    # Exactly which documents a scope resolved to, on screen and on disk.
    #
    # A count is not a check. "412 documents matched" is equally consistent with the
    # right filter and with a wrong one, and the only way to tell is to look at the ids -
    # so the ids are written every time, before anything is read or changed, and a sample
    # goes to the log where somebody will actually see it.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Documents,
        [Parameter(Mandatory)][string]$Path,
        [int]$Show = 20
    )
    $rows = New-Object System.Collections.ArrayList
    foreach ($d in $Documents) {
        [void]$rows.Add([pscustomobject]@{
            TargetId = "$(Get-VaultField $d 'TargetId' '')"
            SourceId = "$(Get-VaultField $d 'SourceId' '')"
        })
    }
    $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    # The scope itself IS sampled on screen - fifteen thousand ids scrolling past tells
    # nobody anything, and every one of them is in the file. The DIFFERENCES are the ones
    # printed in full, because those are what somebody has to act on.
    $ids = @($rows | ForEach-Object { $_.TargetId })
    Write-VaultLog "Target ids in scope ($($ids.Count)):"
    foreach ($line in (Format-VaultIdRows -Ids @($ids | Select-Object -First $Show))) { Write-VaultLog "  $line" }
    if ($ids.Count -gt $Show) { Write-VaultLog "  ... and $($ids.Count - $Show) more - all of them are in the file below" }
    Write-VaultLog "Scope written to $Path" 'OK'
    return $Path
}

function Format-VaultIdRows {
    # Ids in readable rows rather than one enormous line or one line each.
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$Ids, [int]$PerRow = 10)
    $out = New-Object System.Collections.ArrayList
    $all = @($Ids)
    for ($i = 0; $i -lt $all.Count; $i += $PerRow) {
        [void]$out.Add(($all[$i..([math]::Min($i + $PerRow - 1, $all.Count - 1))] -join ' '))
    }
    return @($out)
}

function Compare-VaultScopeToList {
    # Does the query return exactly the documents somebody expected?
    #
    # A count agreeing proves nothing: 412 from the query and 412 in the list can still
    # be 412 DIFFERENT documents. This compares the sets, and reports both directions,
    # because they mean opposite things - an id in the list the query missed says the
    # filter is too narrow, and one the query found that is not in the list says it is
    # too wide. Either is worth knowing before anything is granted.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Documents,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$OutPath,
        [int]$Show = 20
    )
    # One id per line, and tolerant of a header, blanks, quotes and repeats - the same
    # reader the document workflows use, so a list that works there works here.
    $expected = @(Import-VaultIdList -Path $Path)

    $got = @{}; $src = @{}
    foreach ($d in $Documents) {
        $t = "$(Get-VaultField $d 'TargetId' '')"; if ($t) { $got[$t] = $true }
        $s = "$(Get-VaultField $d 'SourceId' '')"; if ($s) { $src[$s] = $true }
    }
    $want = @{}
    foreach ($e in $expected) { $want["$e"] = $true }

    $matched = @($expected | Where-Object { $got.ContainsKey("$_") })
    $missing = @($expected | Where-Object { -not $got.ContainsKey("$_") })
    $extra   = @($got.Keys | Where-Object { -not $want.ContainsKey("$_") })

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "Reconciling the query against $($expected.Count) expected id(s)"
    Write-VaultLog ("  in both              {0}" -f $matched.Count) $(if ($matched.Count) { 'OK' } else { 'WARN' })
    # Every one of them on screen, not a sample. A file is where you go afterwards; the
    # question in front of somebody watching a run is "which documents", and answering it
    # with the first ten and a count makes them go and open a file to find out.
    if ($missing.Count) {
        Write-VaultLog ("  expected, not found  {0}  - the filter is narrower than the list" -f $missing.Count) 'ERROR'
        foreach ($line in (Format-VaultIdRows -Ids $missing)) { Write-VaultLog "    $line" 'ERROR' }
    }
    if ($extra.Count) {
        Write-VaultLog ("  found, not expected  {0}  - the filter is wider than the list" -f $extra.Count) 'ERROR'
        foreach ($line in (Format-VaultIdRows -Ids $extra)) { Write-VaultLog "    $line" 'ERROR' }
    }

    # The mistake this catches before it wastes anyone's afternoon: a list of SOURCE ids
    # compared against target ids matches nothing at all, which reads as a catastrophically
    # wrong filter rather than as the wrong column.
    if (-not $matched.Count -and $expected.Count -and $src.Count) {
        $asSource = @($expected | Where-Object { $src.ContainsKey("$_") }).Count
        if ($asSource) {
            Write-VaultLog "$asSource of them match the SOURCE ids instead. That list looks like source document ids, not target." 'WARN'
        }
    }

    # Only the differences. A file holding fifteen thousand rows that agree, with the
    # eleven that do not somewhere among them, is a file nobody reads - and the rows that
    # agree are already recorded in the scope manifest. This one is the work list.
    $rows = New-Object System.Collections.ArrayList
    foreach ($e in $missing) {
        [void]$rows.Add([pscustomobject]@{ Id = "$e"; Verdict = 'EXPECTED_NOT_FOUND'
                                           Means = 'in the list, not returned by the filter' })
    }
    foreach ($g in $extra) {
        [void]$rows.Add([pscustomobject]@{ Id = "$g"; Verdict = 'FOUND_NOT_EXPECTED'
                                           Means = 'returned by the filter, not in the list' })
    }
    if ($rows.Count) {
        (ConvertTo-VaultUniformRows -Rows $rows) |
            Export-Csv -LiteralPath $OutPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false
        Write-VaultLog "$($rows.Count) difference(s) written to $OutPath - that file is the work list" 'ERROR'
    }
    else {
        # Written even when empty: "we reconciled and found nothing" is a result worth
        # having on disk, and an absent file cannot be told from a check nobody ran.
        'Id,Verdict,Means' | Set-Content -LiteralPath $OutPath -Encoding UTF8 -WhatIf:$false
        Write-VaultLog "No differences. Empty reconciliation written to $OutPath"
    }

    if (-not $missing.Count -and -not $extra.Count) {
        Write-VaultLog 'The query returns exactly the expected documents.' 'OK'
    }
    return ($missing.Count + $extra.Count)
}

function Select-VaultScopeIntersection {
    # Where a map is also configured, take only what is in BOTH.
    #
    # The map says what the migration produced; the query says what this person made
    # recently. A document in one and not the other is not something to guess about, and
    # the intersection is the only reading that cannot reach further than either.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Documents,
        [Parameter(Mandatory)]$Map
    )
    # target id -> source id, so the intersection can carry the source through.
    $known = @{}
    foreach ($k in $Map.Keys) { $known["$($Map[$k])"] = "$k" }

    # TargetId, not id: the query hands back {TargetId, SourceId}, which is the shape the
    # rest of the roles flow reads. Matching on 'id' found nothing and quietly assigned
    # nothing - an empty intersection looks exactly like "there was no work to do".
    $keep = New-Object System.Collections.ArrayList
    foreach ($d in $Documents) {
        $id = "$(Get-VaultField $d 'TargetId' '')"
        if (-not $id -or -not $known.ContainsKey($id)) { continue }
        # The map knows which source document this came from; the query does not. Filling
        # it in here means the results file can say what a repaired document used to be.
        [void]$keep.Add([pscustomobject]@{ TargetId = $id; SourceId = "$($known[$id])" })
    }
    $dropped = $Documents.Count - $keep.Count
    Write-VaultLog "$($Documents.Count) from the query, $($known.Count) in the map, $($keep.Count) in both"
    if ($dropped) {
        Write-VaultLog "$dropped document(s) matched the user and window but are not in the map - not touched" 'WARN'
    }
    return @($keep)
}

# --------------------------------------------------------------------------------------
# Proving where the defaults come from
#
# `probe` observes that defaultUsers/defaultGroups holds MORE than the lifecycle rules
# and infers the surplus is the document type's default security. That is a reasonable
# inference and it is still an inference - and it decides which source a run that grants
# people access should take its answer from.
#
# This settles it by arithmetic instead. For each role on each document it reads all
# three independently and asks whether they reconcile:
#
#     D  what Vault reports as the default for this document and role
#     L  what the lifecycle's role assignment rule says
#     T  what the document type's default security says, read from MDL
#
# If D = L union T, then -DesiredFrom Document is exactly lifecycle plus type defaults
# and the question is answered. If D holds names neither source accounts for, something
# else is contributing and nobody should be granting access on the strength of a guess
# about what.
# --------------------------------------------------------------------------------------

function Invoke-VaultRolesExplain {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Documents,
        [Parameter(Mandatory)]$Rules,
        [Parameter(Mandatory)]$Directory,
        [int]$Limit = 25
    )
    $c = $Context
    $docs = @($Documents)
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - explaining the first $Limit of $($docs.Count) document(s)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-VaultLog "Decomposing the reported defaults on $($docs.Count) document(s)"

    $rows = New-Object System.Collections.ArrayList
    $stat = @{ Roles = 0; Explained = 0; Expanded = 0; ExpandedUsers = 0; Surplus = 0
               Absent = 0; Both = 0; NoDefaults = 0; TypeAdded = 0; LifecycleOnly = 0 }
    $i = 0
    foreach ($doc in $docs) {
        $i++
        $docId = $doc.TargetId
        $info  = Get-VaultDocumentInfo -Context $c -DocId $docId
        if (-not $info.Read) { Write-VaultLog "[$i] $docId - could not read the document, skipped" 'WARN'; continue }
        $td = Get-VaultDocTypeRoleDefault -Context $c -TypeLabel $info.Type -SubtypeLabel $info.Subtype `
                  -Directory $Directory -ClassificationLabel $info.Classification

        foreach ($r in @(Get-VaultDocumentRole -Context $c -DocId $docId)) {
            $name = "$(Get-VaultField $r 'name' '')"
            if (-not $name) { continue }
            $stat.Roles++

            $D = Get-VaultDesiredForRole -From 'Document' -RoleRecord $r -Table $null -Rules $null `
                     -Subtype $info.Subtype -DocumentInfo $info
            $L = Get-VaultDesiredForRole -From 'Lifecycle' -RoleRecord $r -Table $null -Rules $Rules `
                     -Subtype $info.Subtype -DocumentInfo $info
            $tU = @(); $tG = @()
            if ($td.ContainsKey($name)) { $tU = @($td[$name].Users); $tG = @($td[$name].Groups) }

            $dSet = @(@($D.Users | ForEach-Object { "u:$_" }) + @($D.Groups | ForEach-Object { "g:$_" }))
            $lSet = @(@($L.Users | ForEach-Object { "u:$_" }) + @($L.Groups | ForEach-Object { "g:$_" }))
            $tSet = @(@($tU        | ForEach-Object { "u:$_" }) + @($tG        | ForEach-Object { "g:$_" }))
            $union = @(@($lSet + $tSet) | Select-Object -Unique)

            $surplus = @($dSet | Where-Object { $union -notcontains $_ })
            $absent  = @($union | Where-Object { $dSet -notcontains $_ })

            # Most of the "surplus" is not a third contributor: it is the SAME
            # contributor, resolved. A lifecycle rule assigns a group; Vault reports
            # defaultUsers as that group's expanded membership, so one configured group
            # comes back as one group plus twenty-five individual users.
            #
            # That distinction decides the whole job. Assigning the group is what the
            # configuration says; assigning the expansion writes direct user assignments
            # that OUTLIVE the group - remove someone from the group afterwards and they
            # keep the access - which is a mess to unpick across fifteen thousand
            # documents.
            $wantGroups = @($union | Where-Object { $_ -like 'g:*' } | ForEach-Object { $_.Substring(2) })
            $surplusUsers = @($surplus | Where-Object { $_ -like 'u:*' } | ForEach-Object { $_.Substring(2) })
            $byMembership = Get-VaultRedundantUserCount -Directory $Directory -Groups $wantGroups -Users $surplusUsers
            $trueSurplus  = @($surplus | Where-Object { $_ -like 'g:*' }).Count + ($surplusUsers.Count - $byMembership)
            # What the type defaults contribute that the lifecycle rule does not - the
            # quantity `probe` saw as a surplus, now attributed rather than inferred.
            $tOnly   = @($tSet | Where-Object { $lSet -notcontains $_ })

            $verdict =
                if (-not $dSet.Count -and -not $union.Count)      { $stat.NoDefaults++;  'NO_DEFAULTS' }
                elseif ($trueSurplus -gt 0 -and $absent.Count)    { $stat.Both++;        'BOTH_WAYS' }
                elseif ($trueSurplus -gt 0)                       { $stat.Surplus++;     'UNEXPLAINED_SURPLUS' }
                elseif ($absent.Count)                            { $stat.Absent++;      'CONFIG_NOT_IN_DEFAULTS' }
                elseif ($byMembership -gt 0)                      { $stat.Expanded++;    'EXPLAINED_GROUP_EXPANSION' }
                else                                              { $stat.Explained++;   'EXPLAINED' }
            $stat.ExpandedUsers += $byMembership
            if ($tOnly.Count) { $stat.TypeAdded++ } elseif ($lSet.Count) { $stat.LifecycleOnly++ }

            [void]$rows.Add([pscustomobject]@{
                DocId = $docId; Type = $info.Type; Subtype = $info.Subtype; Lifecycle = $info.Lifecycle
                Role = $name
                ReportedDefaults = $dSet.Count; FromLifecycle = $lSet.Count; FromTypeDefaults = $tSet.Count
                TypeAddsBeyondLifecycle = $tOnly.Count
                SurplusTotal = $surplus.Count; SurplusIsGroupMembership = $byMembership
                UnexplainedSurplus = $trueSurplus; ConfigNotInDefaults = $absent.Count
                Verdict = $verdict
                SurplusNames = (($surplus | Select-Object -First 8) -join '; ')
                AbsentNames  = (($absent  | Select-Object -First 8) -join '; ')
            })
        }
    }

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($stat.Roles) role(s) examined across $($docs.Count) document(s)"
    Write-VaultLog ("  EXPLAINED               {0}  - reported defaults are exactly lifecycle + type defaults" -f $stat.Explained) 'OK'
    Write-VaultLog ("  EXPLAINED_GROUP_EXPANSION {0} - and the rest is the membership of those groups, resolved" -f $stat.Expanded) 'OK'
    Write-VaultLog ("  NO_DEFAULTS             {0}  - nothing reported and nothing configured" -f $stat.NoDefaults)
    if ($stat.Surplus) { Write-VaultLog ("  UNEXPLAINED_SURPLUS     {0}  - reported defaults hold names NEITHER source accounts for" -f $stat.Surplus) 'ERROR' }
    if ($stat.Absent)  { Write-VaultLog ("  CONFIG_NOT_IN_DEFAULTS  {0}  - configured but not reported as a default" -f $stat.Absent) 'WARN' }
    if ($stat.Both)    { Write-VaultLog ("  BOTH_WAYS               {0}" -f $stat.Both) 'ERROR' }
    Write-VaultLog ("  type defaults add something beyond the lifecycle rule on {0} role(s)" -f $stat.TypeAdded)

    $decided = $stat.Explained + $stat.Expanded + $stat.NoDefaults
    if ($stat.Roles -and $decided -eq $stat.Roles) {
        Write-VaultLog 'PROVEN: every reported default is accounted for by the lifecycle rules plus the type defaults.' 'OK'
        if ($stat.Expanded) {
            Write-VaultLog ("{0} user(s) appear in the reported defaults only as the membership of a group that is already there." -f $stat.ExpandedUsers) 'WARN'
            Write-VaultLog 'So -DesiredFrom Document would assign every one of them DIRECTLY, in addition to the group.' 'WARN'
            Write-VaultLog 'A direct assignment outlives the group. Use -DesiredFrom Lifecycle, which assigns the group.' 'WARN'
        }
        else {
            Write-VaultLog '-DesiredFrom Document is therefore exactly those two sources.' 'OK'
        }
    }
    elseif ($stat.Surplus -or $stat.Both) {
        Write-VaultLog 'NOT PROVEN: some reported defaults come from somewhere neither source explains.' 'ERROR'
        Write-VaultLog 'Look at SurplusNames in the report before granting anything on -DesiredFrom Document.' 'ERROR'
    }
    else {
        Write-VaultLog 'Reported defaults are a SUBSET of what the two sources configure - see ConfigNotInDefaults.' 'WARN'
        Write-VaultLog 'Document mode would then assign less than Lifecycle + -WithTypeDefaults would.' 'WARN'
    }

    $report = Join-Path $c.Out 'roles-explain.csv'
    (ConvertTo-VaultUniformRows -Rows $rows) |
        Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Write-VaultLog "Report: $report"
    return ($stat.Surplus + $stat.Both)
}

function Invoke-VaultDocTypeMdlDump {
    # Every attribute of a document type's MDL component, not the three we parse.
    #
    # Get-VaultDocTypeRoleDefault reads role_defaulting_editors, _viewers and _consumers
    # and nothing else, so a document type that defaults a CUSTOM role would be invisible
    # to it - and -WithTypeDefaults would silently apply less than the type configures.
    # That is a claim about the component's shape, and the component can be asked.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$TypeLabel,
        [AllowEmptyString()][string]$SubtypeLabel = '',
        [AllowEmptyString()][string]$ClassificationLabel = ''
    )
    $c = $Context
    $idx = Get-VaultDocTypeNameIndex -Context $c
    $typeKey = ConvertTo-VaultNameKey $TypeLabel

    if (-not $idx.Types.ContainsKey($typeKey)) {
        # What the Library shows, and therefore what anyone has to hand, is the SUBTYPE
        # label - "Study Protocol" is a subtype of "Clinical". Insisting on the type name
        # would mean knowing the hierarchy before being allowed to ask about it.
        # EVERY type is searched, not the first that matches. Hashtable order is not
        # meaningful, so stopping at the first hit picks an arbitrary parent when two
        # types both have a subtype of that label - and then reads the wrong component
        # and reports on it as if it were the right one.
        $hits = New-Object System.Collections.ArrayList
        foreach ($tk in @($idx.Types.Keys)) {
            $tn = $idx.Types[$tk]
            $sn = Get-VaultSubtypeName -Context $c -TypeName $tn -SubtypeLabel $TypeLabel
            if ($sn) { [void]$hits.Add($tn) }
        }
        if ($hits.Count -gt 1) {
            throw ("'$TypeLabel' is a subtype of more than one type: " + ($hits -join ', ') +
                   ". Name which one with -Type <type> -Subtype '$TypeLabel'.")
        }
        if ($hits.Count -eq 1) {
            Write-VaultLog "'$TypeLabel' is a subtype of $($hits[0]) - reading that type and this subtype." 'WARN'
            $typeName = $hits[0]
            $SubtypeLabel = $TypeLabel
        }
        elseif ($hits.Count -eq 0) {
            # Name them. "Run roles survey" is an instruction to go and find out
            # something this already knows.
            $labels = @($idx.Types.Keys | ForEach-Object { $idx.Types[$_] } | Sort-Object)
            throw ("No document type or subtype called '$TypeLabel'. This vault's types are:`n    " + ($labels -join "`n    "))
        }
    }
    else { $typeName = $idx.Types[$typeKey] }

    $candidates = New-Object System.Collections.ArrayList
    if ($SubtypeLabel -and (ConvertTo-VaultNameKey $SubtypeLabel) -ne $typeKey) {
        $subName = Get-VaultSubtypeName -Context $c -TypeName $typeName -SubtypeLabel $SubtypeLabel
        if ($subName) { [void]$candidates.Add("Doctype.$typeName.$subName") }
    }
    [void]$candidates.Add("Doctype.$typeName")
    [void]$candidates.Add('Doctype.base_document__v')

    if ($SubtypeLabel -and $ClassificationLabel) {
        $sn = Get-VaultSubtypeName -Context $c -TypeName $typeName -SubtypeLabel $SubtypeLabel
        if ($sn) {
            $cn = Get-VaultClassificationName -Context $c -TypeName $typeName -SubtypeName $sn `
                      -ClassificationLabel $ClassificationLabel
            if ($cn) { $candidates.Insert(0, "Doctype.$typeName.$sn.$cn") }
            else { Write-VaultLog "No classification called '$ClassificationLabel' under $typeName/$sn" 'WARN' }
        }
    }

    $rows = New-Object System.Collections.ArrayList
    foreach ($component in $candidates) {
        Write-VaultLog '----------------------------------------------------------------'
        Write-VaultLog "$component"
        $r = $null
        foreach ($path in @("/configuration/$component", "/api/mdl/components/$component")) {
            try { $r = Invoke-VaultApi -VaultHost $c.VaultHost -ApiVersion $c.Api -Method GET -Path $path -MaxRetries 1; break }
            catch { }
        }
        if ($null -eq $r) { Write-VaultLog '  could not be read' 'WARN'; continue }

        $data = Get-VaultField $r 'data' $null
        if (-not $data) { $data = $r }

        $props = @()
        try { $props = @($data.PSObject.Properties) } catch { }
        if (-not $props.Count) {
            $raw = "$(Get-VaultField $r 'raw' '')"
            Write-VaultLog "  not JSON - raw MDL, $($raw.Length) character(s). Saved to the file below."
            [void]$rows.Add([pscustomobject]@{ Component = $component; Attribute = '(raw)'; Kind = 'text'; Count = $raw.Length; Value = $raw })
            continue
        }

        foreach ($p in ($props | Sort-Object Name)) {
            $v = $p.Value
            $kind = 'scalar'; $count = 1; $shown = "$v"
            if ($v -is [Array]) { $kind = 'array'; $count = $v.Count; $shown = (@($v | Select-Object -First 6) -join '; ') }
            elseif ($null -eq $v) { $shown = '' }
            if ($shown.Length -gt 160) { $shown = $shown.Substring(0, 160) + ' ...' }

            # Anything that looks like it defaults a principal into a role. This is the
            # question: are there more of these than the three we parse?
            $interesting = ($p.Name -match 'role|default|permission|shar')
            $line = ("  {0,-38} {1,-7} {2,4}  {3}" -f $p.Name, $kind, $count, $shown)
            if ($interesting) { Write-VaultLog $line 'OK' } else { Write-VaultLog $line }

            [void]$rows.Add([pscustomobject]@{
                Component = $component; Attribute = $p.Name; Kind = $kind; Count = $count; Value = $shown
            })
        }
    }

    $known = @('role_defaulting_editors', 'role_defaulting_viewers', 'role_defaulting_consumers')
    $defaulting = @($rows | Where-Object { $_.Attribute -like 'role_defaulting*' })
    $unparsed   = @($defaulting | Where-Object { $known -notcontains $_.Attribute })

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($defaulting.Count) role_defaulting_* attribute(s) across the components read"
    if ($unparsed.Count) {
        Write-VaultLog "$($unparsed.Count) of them are NOT read by -WithTypeDefaults:" 'ERROR'
        foreach ($u in $unparsed) { Write-VaultLog "  $($u.Component)  $($u.Attribute)  = $($u.Value)" 'ERROR' }
        Write-VaultLog 'Type defaults for those roles are configured and would not be applied.' 'ERROR'
    }
    else {
        Write-VaultLog 'Only editors, viewers and consumers - which is exactly what -WithTypeDefaults reads.' 'OK'
        Write-VaultLog 'So a document type cannot default a custom role, and nothing is being missed.' 'OK'
    }

    $out = Join-Path $c.Out 'doctype-mdl.csv'
    (ConvertTo-VaultUniformRows -Rows $rows) |
        Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Write-VaultLog "Every attribute written to $out"
    return $unparsed.Count
}

function Invoke-VaultRolesAudit {
    # Do these documents have the settings the configuration says they should?
    #
    # A different question from "did the run do what it recorded", and the one people
    # actually mean. For every document it reads the roles Vault holds now, works out
    # what the lifecycle's role assignment rules and the document type's defaults name
    # for it, and reports the difference.
    #
    # Be clear about what this proves. It recomputes the desired state with the same
    # logic the assign used, so it cannot catch a mistake in that logic - `roles explain`
    # is what checks the logic against the configuration itself. What it does catch is
    # everything between intent and outcome: a document no run ever reached, an
    # assignment Vault accepted and silently did not make, a role emptied since, a
    # lifecycle changed underneath.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Documents,
        [Parameter(Mandatory)]$Rules,
        [Parameter(Mandatory)]$Directory,
        [switch]$WithTypeDefaults,
        [int]$Limit = 0
    )
    $c = $Context
    $docs = @($Documents)
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - auditing the first $Limit of $($docs.Count)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-VaultLog "Auditing $($docs.Count) document(s) against the lifecycle rules$(if ($WithTypeDefaults) { ' and the document type defaults' })"

    $res = New-VaultResults -Path (Join-Path $c.Out 'role-audit-results.csv') `
               -KeyColumn 'DocId' -DoneStatuses @() -Existing 'Fresh'

    $stat = @{ Correct = 0; Incomplete = 0; NoRoles = 0; Unreadable = 0
               GroupsMissing = 0; UsersMissing = 0; GroupsPresentTotal = 0 }
    $i = 0
    foreach ($doc in $docs) {
        $i++
        $docId = "$(Get-VaultField $doc 'TargetId' '')"
        if (-not $docId) { $docId = "$doc" }
        if (($i % 200) -eq 0) { Write-VaultLog "  audited $i of $($docs.Count)" }

        $row = [ordered]@{
            DocId = $docId; Lifecycle = ''; Type = ''; Subtype = ''; Classification = ''
            RolesChecked = 0; GroupsExpected = 0; GroupsPresent = 0
            GroupsMissing = 0; UsersMissing = 0
            MissingDetail = ''; Status = ''
        }
        try {
            $info = Get-VaultDocumentInfo -Context $c -DocId $docId
            if (-not $info.Read) {
                $row.Status = 'UNREADABLE'; $stat.Unreadable++
                Add-VaultResult -Results $res -Row ([pscustomobject]$row); continue
            }
            $row.Lifecycle = $info.Lifecycle; $row.Type = $info.Type
            $row.Subtype = $info.Subtype; $row.Classification = $info.Classification

            $td = @{}
            if ($WithTypeDefaults) {
                $td = Get-VaultDocTypeRoleDefault -Context $c -TypeLabel $info.Type `
                          -SubtypeLabel $info.Subtype -Directory $Directory `
                          -ClassificationLabel $info.Classification
            }

            $roles = @(Get-VaultDocumentRole -Context $c -DocId $docId)
            if (-not $roles.Count) {
                $row.Status = 'NO_ROLES'; $stat.NoRoles++
                Add-VaultResult -Results $res -Row ([pscustomobject]$row); continue
            }

            $missing = New-Object System.Collections.ArrayList
            foreach ($r in $roles) {
                $name = "$(Get-VaultField $r 'name' '')"
                if (-not $name) { continue }
                $row.RolesChecked++

                $want = Get-VaultDesiredForRole -From 'Lifecycle' -RoleRecord $r -Table $null `
                            -Rules $Rules -Subtype $info.Subtype -DocumentInfo $info
                $wantG = @($want.Groups); $wantU = @($want.Users)
                if ($td.ContainsKey($name)) {
                    $wantG = @(@($wantG) + @($td[$name].Groups) | Select-Object -Unique)
                    $wantU = @(@($wantU) + @($td[$name].Users)  | Select-Object -Unique)
                }

                # assignedGroups / assignedUsers, which is what /documents/{id}/roles
                # actually returns. Reading 'groups' and 'users' gets an empty array and
                # every document then looks like it is missing everything.
                $haveG = @(@(Get-VaultField $r 'assignedGroups' @()) | ForEach-Object { "$_" })
                $haveU = @(@(Get-VaultField $r 'assignedUsers'  @()) | ForEach-Object { "$_" })

                $row.GroupsExpected += $wantG.Count
                foreach ($g in $wantG) {
                    if ($haveG -contains $g) { $row.GroupsPresent++; continue }
                    $row.GroupsMissing++
                    [void]$missing.Add("$name needs group $(Get-VaultDisplayName -Directory $Directory -Kind 'group' -Id $g)")
                }
                foreach ($u in $wantU) {
                    if ($haveU -contains $u) { continue }
                    $row.UsersMissing++
                    [void]$missing.Add("$name needs user $(Get-VaultDisplayName -Directory $Directory -Kind 'user' -Id $u)")
                }
            }

            $stat.GroupsMissing      += $row.GroupsMissing
            $stat.UsersMissing       += $row.UsersMissing
            $stat.GroupsPresentTotal += $row.GroupsPresent
            if ($row.GroupsMissing -or $row.UsersMissing) {
                $row.Status = 'INCOMPLETE'; $stat.Incomplete++
                $row.MissingDetail = (($missing | Select-Object -First 12) -join '; ')
                Write-VaultLog "[$i] $docId - INCOMPLETE: $($row.MissingDetail)" 'ERROR'
            }
            else { $row.Status = 'CORRECT'; $stat.Correct++ }
        }
        catch {
            $row.Status = 'ERROR'; $row.MissingDetail = "$_"; $stat.Unreadable++
            Write-VaultLog "[$i] $docId - ERROR: $_" 'ERROR'
        }
        Add-VaultResult -Results $res -Row ([pscustomobject]$row)
    }

    Save-VaultResults -Results $res
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($docs.Count) document(s) audited against the configuration"

    # Every document short, and not one group found present anywhere. That is not a vault
    # in which every document is wrong - it is this code reading the wrong field, which is
    # exactly how it failed the first time. Said before the totals, so nobody acts on them.
    if ($stat.Incomplete -eq $docs.Count -and $docs.Count -gt 5 -and $stat.GroupsPresentTotal -eq 0) {
        Write-VaultLog 'EVERY document is short and NOTHING was found present. Suspect this audit, not the vault.' 'ERROR'
        Write-VaultLog 'That is the signature of reading the wrong field off the roles response.' 'ERROR'
    }
    Write-VaultLog ("  CORRECT       {0,7}  - has every group and user the configuration names" -f $stat.Correct) 'OK'
    if ($stat.Incomplete) {
        Write-VaultLog ("  INCOMPLETE    {0,7}  - {1} group and {2} user assignment(s) short" -f $stat.Incomplete, $stat.GroupsMissing, $stat.UsersMissing) 'ERROR'
    }
    if ($stat.NoRoles)    { Write-VaultLog ("  NO_ROLES      {0,7}  - the document reports no roles at all" -f $stat.NoRoles) 'WARN' }
    if ($stat.Unreadable) { Write-VaultLog ("  UNREADABLE    {0,7}" -f $stat.Unreadable) 'ERROR' }
    Write-VaultLog 'This recomputes the desired state with the same logic the assign used, so it'
    Write-VaultLog 'cannot catch a mistake in that logic - roles explain checks it against the'
    Write-VaultLog 'configuration. It catches everything between intent and outcome.'
    Write-VaultLog "Report: $($res.Path)"
    # Stamped, and never written again. This file is the evidence that the permissions
    # are right - the working copy is rotated aside by the next run, so the record of
    # what THIS audit found has to survive independently of it.
    $snap = Copy-VaultResultsSnapshot -Path $res.Path
    if ($snap) { Write-VaultLog "This run : $snap" }
    return ($stat.Incomplete + $stat.Unreadable)
}

# ===== VaultKit/Verify.ps1 =====

# Is this document actually migrated?
#
# The per-workflow checks each answer their own question: documents verify proves a file
# reached File Staging, attachments verify proves the attachments match, roles verify
# proves what a run claimed it assigned. None of them answers the question someone
# actually asks at the end, which is about a DOCUMENT rather than about a step:
#
#   source document -> destination document, and everything that hangs off it
#
# So this checks a source/target PAIR across four dimensions - the document's own file,
# its attachments, its Sharing Settings, and that both ends exist at all - and gives one
# verdict per pair. It reads both vaults and writes to neither.
#
# It is deliberately independent of the other results files. A report assembled from what
# earlier runs RECORDED inherits their mistakes; this one asks the vaults.

# --------------------------------------------------------------------------------------
# How much to check
#
# Checking everything is the honest default and often the wrong economics: a DEEP census
# of 15,775 documents downloads both copies of each, which is twice what the migration
# itself moved. So the scope is chosen explicitly, and the choice is recorded in the log
# and the report - a sample nobody can reproduce is an anecdote.
# --------------------------------------------------------------------------------------

function Get-VaultSampleSize {
    # Cochran's formula with the finite population correction.
    #
    #   n0 = z^2 * p(1-p) / e^2          then    n = n0 / (1 + (n0 - 1) / N)
    #
    # p is fixed at 0.5 because that maximises the variance, which is the conservative
    # choice when you do not already know the failure rate - and if you knew it, you
    # would not be sampling. So the answer does not depend on a guess about how good the
    # migration is.
    #
    # 95% with a 5% margin over any large population lands near 384, which is why that
    # number turns up in every sampling table. The finite correction pulls it down for a
    # population this size.
    param(
        [Parameter(Mandatory)][int]$Population,
        [ValidateSet(90, 95, 99)][int]$Confidence = 95,
        [ValidateRange(0.1, 50)][double]$MarginPct = 5
    )
    if ($Population -le 0) { return 0 }

    $z = switch ($Confidence) { 90 { 1.645 } 95 { 1.96 } 99 { 2.576 } }
    $p = 0.5
    $e = $MarginPct / 100.0

    $n0 = ($z * $z * $p * (1 - $p)) / ($e * $e)
    $n  = $n0 / (1 + (($n0 - 1) / $Population))
    $n  = [int][math]::Ceiling($n)
    if ($n -gt $Population) { $n = $Population }
    return $n
}

function Select-VaultSample {
    # A reproducible random subset.
    #
    # Seeded on purpose. An auditor asking "which documents did you check, and would you
    # get the same ones again" needs an answer, and "random" is not one. The seed is
    # logged and recorded, so the same seed over the same population selects the same
    # documents - and a different seed is a genuinely independent second sample.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Items,
        [Parameter(Mandatory)][int]$Count,
        [int]$Seed = 0
    )
    if ($Count -ge $Items.Count) { return @($Items) }
    if ($Count -le 0) { return @() }

    $rng = if ($Seed -ne 0) { New-Object System.Random($Seed) } else { New-Object System.Random }

    # Fisher-Yates over a copy, taking the first $Count. Not "sort by a random key",
    # which is biased by the sort's tie handling, and not "pick until you have enough",
    # which repeats.
    $a = @($Items)
    $picked = New-Object System.Collections.ArrayList
    $n = $a.Count
    for ($i = 0; $i -lt $Count; $i++) {
        $j = $rng.Next($i, $n)
        $tmp = $a[$i]; $a[$i] = $a[$j]; $a[$j] = $tmp
        [void]$picked.Add($a[$i])
    }
    return @($picked)
}

function Resolve-VaultVerifyScope {
    # Turn a mode into a list of pairs, and say out loud what it decided.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Pairs,
        [Parameter(Mandatory)][ValidateSet('trial', 'sample', 'census')][string]$Mode,
        [int]$TrialSize = 25,
        [int]$Confidence = 95,
        [double]$MarginPct = 5,
        [int]$Seed = 0
    )
    $population = $Pairs.Count
    switch ($Mode) {
        'census' {
            Write-VaultLog "census: all $population document(s)" 'OK'
            return @($Pairs)
        }
        'trial' {
            $n = [math]::Min($TrialSize, $population)
            $chosen = Select-VaultSample -Items $Pairs -Count $n -Seed $Seed
            Write-VaultLog "trial: $n of $population document(s), chosen at random (seed $Seed)" 'WARN'
            Write-VaultLog 'A trial proves the check works. It says nothing about the migration.' 'WARN'
            return $chosen
        }
        'sample' {
            $n = Get-VaultSampleSize -Population $population -Confidence $Confidence -MarginPct $MarginPct
            $chosen = Select-VaultSample -Items $Pairs -Count $n -Seed $Seed
            Write-VaultLog "sample: $n of $population document(s) for $Confidence% confidence, +/-$MarginPct% margin (seed $Seed)" 'OK'
            Write-VaultLog 'Cochran with the finite population correction, p=0.5 - the conservative assumption.'
            return $chosen
        }
    }
}

# --------------------------------------------------------------------------------------
# What relates a source document to its target
#
# A hand-maintained CSV is the weakest anchor there is: it says what somebody INTENDED,
# it goes stale the moment anyone loads a document outside it, and it cannot tell you
# about a document it does not mention - which is exactly the document you would want to
# hear about.
#
# A field on the target document holding the source id is a far better one, because it is
# in the vault, it is what the load actually did, and it covers everything. Vault has no
# single blessed field for this, so which one carries it is a question about THIS
# migration - and the answer is discoverable rather than guessable.
# --------------------------------------------------------------------------------------

function Get-VaultDocumentFieldName {
    # Every document field this vault defines.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$VaultHost)
    $r = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $Context.Api -Method GET `
            -Path '/metadata/objects/documents/properties'
    $names = New-Object System.Collections.ArrayList
    foreach ($p in @(Get-VaultField $r 'properties' @())) {
        $n = "$(Get-VaultField $p 'name' '')"
        if ($n) { [void]$names.Add($n) }
    }
    return @($names)
}

function Invoke-VaultFieldList {
    # Which fields this vault's documents actually have, and of what type.
    #
    # Exists because guessing was wrong twice. created_date__v is a field on objects and
    # not on documents; document_creation_date__v is documented for documents but every
    # example uses a bare date, which does not say whether a time of day is usable. Both
    # questions are answered by asking the vault, in one call, for free.
    param([Parameter(Mandatory)]$Context, [string]$Match = '')
    $c = $Context
    Write-VaultLog "$($c.TargetHost) document fields"

    $r = Invoke-VaultApi -VaultHost $c.TargetHost -ApiVersion $c.Api -Method GET `
            -Path '/metadata/objects/documents/properties'
    $props = @(Get-VaultField $r 'properties' @())
    Write-VaultLog "$($props.Count) field(s) defined"

    $rows = New-Object System.Collections.ArrayList
    foreach ($p in $props) {
        $name = "$(Get-VaultField $p 'name' '')"
        if (-not $name) { continue }
        if ($Match -and ($name -notmatch $Match)) { continue }
        [void]$rows.Add([pscustomobject]@{
            Name       = $name
            Type       = "$(Get-VaultField $p 'type' '')"
            Queryable  = "$(Get-VaultField $p 'queryable' '')"
            Editable   = "$(Get-VaultField $p 'editable' '')"
            Label      = "$(Get-VaultField $p 'label' '')"
        })
    }

    if ($Match) { Write-VaultLog "$($rows.Count) match '$Match'" 'OK' }
    foreach ($row in ($rows | Sort-Object Name)) {
        Write-VaultLog ("  {0,-34} {1,-12} queryable={2,-5} {3}" -f $row.Name, $row.Type, $row.Queryable, $row.Label)
    }

    $out = Join-Path $c.Out 'document-fields.csv'
    (ConvertTo-VaultUniformRows -Rows $rows) |
        Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Write-VaultLog "Written to $out"
    return 0
}

function Invoke-VaultAnchorProbe {
    # Which field, if any, relates the two vaults - answered from the vaults.
    #
    # Read only. Reports every candidate field, how many documents carry a value, what
    # those values look like, and - when a map is available - how many of them actually
    # hit a source id the map knows. A field that is populated but whose values match
    # nothing is worse than no field at all, because it looks like an anchor.
    param([Parameter(Mandatory)]$Context, [int]$Limit = 500)
    $c = $Context

    Write-VaultLog "target vault: $($c.TargetHost)"
    $fields = Get-VaultDocumentFieldName -Context $c -VaultHost $c.TargetHost
    Write-VaultLog "$($fields.Count) document field(s) defined on the target"

    # Names a migration puts a legacy id in. Deliberately broad: a false candidate costs
    # one query and is reported as empty, where a missed one costs the whole approach.
    $pattern = 'external|legacy|migrat|source|origin|prior|previous|old_|_old|mnk|mallinckrodt|xref|cross_ref'
    $candidates = @($fields | Where-Object { $_ -match $pattern })

    # The document's own id space is worth checking too: some loads carry the source id
    # in a name or number field rather than a purpose-made one.
    foreach ($extra in @('external_id__v', 'document_number__v', 'name__v')) {
        if (($fields -contains $extra) -and ($candidates -notcontains $extra)) { $candidates += $extra }
    }

    if (-not $candidates.Count) {
        Write-VaultLog 'No field name suggests a legacy id. There may still be one under a name this does not match.' 'WARN'
        Write-VaultLog "Fields defined: $((@($fields | Sort-Object) -join ', '))"
        return 1
    }
    Write-VaultLog "$($candidates.Count) candidate field(s): $($candidates -join ', ')"

    # A map, if there is one, turns "populated" into "populated with something real".
    $known = @{}
    if ($c.Map -and $c.Map.Count) {
        foreach ($k in $c.Map.Keys) { $known["$k"] = $true }
        Write-VaultLog "$($known.Count) source id(s) from the map, to check candidate values against"
    }

    $rows = New-Object System.Collections.ArrayList
    foreach ($f in $candidates) {
        $populated = 0; $hits = 0; $samples = New-Object System.Collections.ArrayList
        try {
            $q = "SELECT id, $f FROM documents WHERE $f != '' MAXROWS $Limit"
            $docs = Get-VaultDocumentsByQuery -Context $c -Where $q -Stop $Limit
            foreach ($d in $docs) {
                $v = "$(Get-VaultField $d $f '')"
                if (-not $v) { continue }
                $populated++
                if ($known.Count -and $known.ContainsKey($v)) { $hits++ }
                if ($samples.Count -lt 3) { [void]$samples.Add($v) }
            }
        }
        catch {
            Write-VaultLog "  $f - not queryable: $_" 'WARN'
            continue
        }

        $verdict =
            if (-not $populated)                     { 'EMPTY' }
            elseif ($known.Count -and $hits -eq 0)   { 'POPULATED_BUT_UNRELATED' }
            elseif ($known.Count -and $hits -lt $populated) { 'PARTIAL' }
            elseif ($known.Count)                    { 'ANCHOR' }
            else                                     { 'POPULATED' }

        $level = switch ($verdict) { 'ANCHOR' { 'OK' } 'EMPTY' { 'INFO' } default { 'WARN' } }
        Write-VaultLog ("  {0,-28} {1,-24} {2} of {3} sampled carry a mapped source id  e.g. {4}" -f `
                        $f, $verdict, $hits, $populated, (($samples) -join ' ')) $level

        [void]$rows.Add([pscustomobject]@{
            Field = $f; Verdict = $verdict; Sampled = $populated
            MatchedMapSource = $hits; Examples = ($samples -join ' ')
        })
    }

    $report = Join-Path $c.Out 'anchor-candidates.csv'
    (ConvertTo-VaultUniformRows -Rows $rows) |
        Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    $best = @($rows | Where-Object { $_.Verdict -eq 'ANCHOR' })
    Write-VaultLog '----------------------------------------------------------------'
    if ($best.Count) {
        Write-VaultLog "Anchor: $($best[0].Field) - build the pair list from the vault with: verify map -Anchor $($best[0].Field)" 'OK'
    }
    else {
        Write-VaultLog 'No field relates the two vaults. The map is the only anchor there is, and it' 'WARN'
        Write-VaultLog 'cannot tell you about a document it does not mention.' 'WARN'
    }
    Write-VaultLog "Report: $report"
    return 0
}

function Invoke-VaultBuildPairMap {
    # Derive the source/target pairs from the target vault itself and write them out.
    #
    # The result is the same shape as the hand-maintained map, so everything downstream
    # takes it unchanged - but it is generated from what the load actually produced, and
    # a document loaded outside anyone's spreadsheet appears in it.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Anchor,
        [string]$OutFile = ''
    )
    $c = $Context
    $path = $OutFile
    if (-not $path) { $path = Join-Path $c.Out 'derived-map.csv' }

    Write-VaultLog "Reading $($c.TargetHost) for documents carrying $Anchor"
    $docs = Get-VaultDocumentsByQuery -Context $c -Where "SELECT id, $Anchor FROM documents WHERE $Anchor != ''"

    $rows = New-Object System.Collections.ArrayList
    $dupes = @{}
    foreach ($d in $docs) {
        $src = "$(Get-VaultField $d $Anchor '')"
        $tgt = "$(Get-VaultField $d 'id' '')"
        if (-not $src -or -not $tgt) { continue }
        if ($dupes.ContainsKey($src)) {
            # Two target documents claiming one source is a real finding: the load ran
            # twice, or two loads overlapped. Reported rather than silently deduped.
            $dupes[$src] += ",$tgt"
            continue
        }
        $dupes[$src] = $tgt
        [void]$rows.Add([pscustomobject]@{ source_id = $src; target_id = $tgt })
    }

    $repeated = @($dupes.Keys | Where-Object { $dupes[$_] -match ',' })
    if ($repeated.Count) {
        Write-VaultLog "$($repeated.Count) source id(s) claimed by more than one target document - the load may have run twice" 'ERROR'
        foreach ($k in ($repeated | Select-Object -First 5)) { Write-VaultLog "  $k -> $($dupes[$k])" 'ERROR' }
    }

    $rows | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Write-VaultLog "$($rows.Count) pair(s) written to $path" 'OK'
    Write-VaultLog 'Point [attachments] map or [roles] map at it to use it as the spine.'
    return $(if ($repeated.Count) { 1 } else { 0 })
}

# --------------------------------------------------------------------------------------
# The four dimensions
# --------------------------------------------------------------------------------------

function Test-VaultMigratedDocument {
    # One source/target pair, end to end. Returns the row; decides nothing about scope.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$TargetId,
        [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
        [AllowNull()]$Rules,
        [AllowNull()]$Directory
    )
    $c = $Context
    $row = [ordered]@{
        SourceDocId = $SourceId; TargetDocId = $TargetId
        SourceName = ''; TargetName = ''; Title = ''
        SourceBytes = 0; TargetBytes = 0; SourceMd5 = ''; TargetMd5 = ''
        FileStatus = 'NOT_CHECKED'
        SourceAttachments = 0; TargetAttachments = 0
        AttachmentsMatched = 0; AttachmentsMissing = 0; AttachmentsDiffering = 0; AttachmentsExtra = 0
        AttachmentStatus = 'NOT_CHECKED'
        RolesTotal = 0; RolesWithPeople = 0; GroupsMissing = 0; UsersMissing = 0
        RoleStatus = 'NOT_CHECKED'
        Method = $Depth; Status = ''; Message = ''
        CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
    }
    $notes  = New-Object System.Collections.ArrayList
    $srcTmp = $null; $tgtTmp = $null; $work = ''

    # ---- 1 and 2: the documents themselves, and their files ----
    $srcDoc = $null; $tgtDoc = $null
    try {
        $r = Invoke-VaultApi -VaultHost $c.SourceHost -ApiVersion $c.Api -Method GET -Path "/objects/documents/$SourceId"
        $srcDoc = Get-VaultField $r 'document' $null
    } catch { [void]$notes.Add("source: $_") }
    try {
        $r = Invoke-VaultApi -VaultHost $c.TargetHost -ApiVersion $c.Api -Method GET -Path "/objects/documents/$TargetId"
        $tgtDoc = Get-VaultField $r 'document' $null
    } catch { [void]$notes.Add("target: $_") }

    if ($srcDoc) {
        $row.SourceName  = "$(Get-VaultField $srcDoc 'filename__v' '')"
        $row.Title       = "$(Get-VaultField $srcDoc 'name__v' '')"
        $row.SourceBytes = [long]"$(Get-VaultField $srcDoc 'size__v' 0)"
    }
    if ($tgtDoc) {
        $row.TargetName  = "$(Get-VaultField $tgtDoc 'filename__v' '')"
        $row.TargetBytes = [long]"$(Get-VaultField $tgtDoc 'size__v' 0)"
    }

    if     (-not $srcDoc) { $row.FileStatus = 'MISSING_ON_SOURCE' }
    elseif (-not $tgtDoc) { $row.FileStatus = 'MISSING_ON_TARGET' }
    elseif ($row.TargetBytes -le 0 -and $row.SourceBytes -gt 0) {
        # The target document exists but carries no file. For this migration that is the
        # expected state until the Loader has consumed File Staging - so it is reported
        # as its own answer rather than as a mismatch, which would read as corruption.
        $row.FileStatus = 'NO_FILE_ON_TARGET'
        [void]$notes.Add('target document has no source file yet')
    }
    elseif ($Depth -eq 'FAST') {
        $row.FileStatus = if ($row.SourceBytes -eq $row.TargetBytes) { 'MATCH' } else { 'MISMATCH' }
    }
    else {
        try {
            Assert-VaultDiskBudget -Path $c.Scratch -Needed ($row.SourceBytes * 2) -ReserveMB $c.ReserveMB
            $work   = New-VaultScratch -Root $c.Scratch -Name "$SourceId-$TargetId"
            $srcTmp = Save-VaultFile -VaultHost $c.SourceHost -ApiVersion $c.Api `
                          -Path "/objects/documents/$SourceId/file" -Destination $work -FileName 'source.bin'
            $tgtTmp = Save-VaultFile -VaultHost $c.TargetHost -ApiVersion $c.Api `
                          -Path "/objects/documents/$TargetId/file" -Destination $work -FileName 'target.bin'
            $row.SourceMd5   = (Get-FileHash -LiteralPath $srcTmp.Path -Algorithm MD5).Hash
            $row.TargetMd5   = (Get-FileHash -LiteralPath $tgtTmp.Path -Algorithm MD5).Hash
            $row.SourceBytes = $srcTmp.Size
            $row.TargetBytes = $tgtTmp.Size
            $row.FileStatus  = if ($row.SourceMd5 -ieq $row.TargetMd5) { 'MATCH' } else { 'MISMATCH' }
        }
        catch {
            $row.FileStatus = 'ERROR'
            [void]$notes.Add("file: $_")
        }
        finally {
            Remove-VaultScratchFile -File $srcTmp -Scratch $c.Scratch
            Remove-VaultScratchFile -File $tgtTmp -Scratch $c.Scratch
            if ($work) { Remove-VaultScratchDir -Path $work }
        }
    }

    # ---- 3: attachments ----
    # By name and MD5 out of the listings. Vault reports both, so nothing is downloaded
    # to answer this - which is why the attachment dimension is nearly free even on a
    # census.
    if ($srcDoc -and $tgtDoc) {
        try {
            $sAtt = @(Get-VaultDocumentAttachment -VaultHost $c.SourceHost -ApiVersion $c.Api -DocId $SourceId)
            $tAtt = @(Get-VaultDocumentAttachment -VaultHost $c.TargetHost -ApiVersion $c.Api -DocId $TargetId)
            $row.SourceAttachments = $sAtt.Count
            $row.TargetAttachments = $tAtt.Count

            $byName = @{}
            foreach ($t in $tAtt) { $byName["$($t.Name)".ToLowerInvariant()] = $t }
            $seen = @{}
            foreach ($s in $sAtt) {
                $k = "$($s.Name)".ToLowerInvariant()
                $seen[$k] = $true
                if (-not $byName.ContainsKey($k)) { $row.AttachmentsMissing++; continue }
                $t = $byName[$k]
                if ($s.Checksum -and $t.Checksum) {
                    if ($s.Checksum -ieq $t.Checksum) { $row.AttachmentsMatched++ } else { $row.AttachmentsDiffering++ }
                }
                elseif ($s.Size -eq $t.Size) { $row.AttachmentsMatched++ }
                else { $row.AttachmentsDiffering++ }
            }
            foreach ($t in $tAtt) { if (-not $seen.ContainsKey("$($t.Name)".ToLowerInvariant())) { $row.AttachmentsExtra++ } }

            $row.AttachmentStatus =
                if     (-not $sAtt.Count -and -not $tAtt.Count) { 'NONE' }
                elseif ($row.AttachmentsMissing -or $row.AttachmentsDiffering) { 'INCOMPLETE' }
                elseif ($row.AttachmentsExtra) { 'EXTRA_ON_TARGET' }
                else { 'MATCH' }
        }
        catch {
            $row.AttachmentStatus = 'ERROR'
            [void]$notes.Add("attachments: $_")
        }
    }

    # ---- 4: permissions ----
    if ($tgtDoc) {
        try {
            $roles = @(Get-VaultDocumentRole -Context $c -DocId $TargetId)
            $row.RolesTotal = $roles.Count
            foreach ($r in $roles) {
                # assignedUsers / assignedGroups - what the roles endpoint returns.
                $u = @(Get-VaultField $r 'assignedUsers' @()).Count
                $g = @(Get-VaultField $r 'assignedGroups' @()).Count
                if ($u -or $g) { $row.RolesWithPeople++ }
            }

            if ($Rules -and $Rules.Count -and $Directory) {
                # What the configuration says should be there, against what is. This is
                # the same question `roles assign` answers - asked here of the vault
                # rather than of a run's own record of what it did.
                $info    = Get-VaultDocumentInfo -Context $c -DocId $TargetId
                $subtype = Get-VaultSubtypeName -Context $c -DocumentInfo $info
                foreach ($r in $roles) {
                    $want = Get-VaultDesiredForRole -From 'Lifecycle' -RoleRecord $r -Table $null `
                                -Rules $Rules -Subtype $subtype -DocumentInfo $info
                    $haveU = @(Get-VaultField $r 'assignedUsers' @())
                    $haveG = @(Get-VaultField $r 'assignedGroups' @())
                    foreach ($g in @($want.Groups)) { if ($haveG -notcontains $g) { $row.GroupsMissing++ } }
                    foreach ($u in @($want.Users))  { if ($haveU -notcontains $u) { $row.UsersMissing++ } }
                }
            }

            $row.RoleStatus =
                if     (-not $row.RolesTotal)                        { 'NO_ROLES' }
                elseif ($row.GroupsMissing -or $row.UsersMissing)    { 'INCOMPLETE' }
                elseif (-not $row.RolesWithPeople)                   { 'EMPTY' }
                else                                                 { 'POPULATED' }
        }
        catch {
            $row.RoleStatus = 'ERROR'
            [void]$notes.Add("roles: $_")
        }
    }

    # ---- the verdict ----
    # VERIFIED means every dimension that could be checked passed. A dimension that could
    # not be checked never counts as a pass - the whole point is that this row can be
    # handed to somebody as evidence, and evidence that quietly treats "unknown" as "fine"
    # is worse than none.
    $fileOk   = $row.FileStatus -eq 'MATCH'
    $attOk    = $row.AttachmentStatus -in @('MATCH', 'NONE')
    $roleOk   = $row.RoleStatus -eq 'POPULATED'
    $anyError = ($row.FileStatus -eq 'ERROR') -or ($row.AttachmentStatus -eq 'ERROR') -or ($row.RoleStatus -eq 'ERROR')

    $row.Status =
        if     ($anyError)                    { 'ERROR' }
        elseif ($fileOk -and $attOk -and $roleOk) { 'VERIFIED' }
        elseif ($row.FileStatus -in @('MISSING_ON_SOURCE', 'MISSING_ON_TARGET', 'MISMATCH')) { 'FAILED' }
        else                                  { 'PARTIAL' }

    $row.Message = ($notes -join ' | ')
    return [pscustomobject]$row
}

# --------------------------------------------------------------------------------------
# The run
# --------------------------------------------------------------------------------------

function Invoke-VaultMigrationVerify {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][ValidateSet('trial', 'sample', 'census')][string]$Mode,
        [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
        [int]$TrialSize = 25,
        [ValidateSet(90, 95, 99)][int]$Confidence = 95,
        [double]$MarginPct = 5,
        [int]$Seed = 0,
        [switch]$WithRoleRules,
        [int]$Limit = 0
    )
    $c = $Context
    if (-not $c.Map -or -not $c.Map.Count) {
        throw 'No map. The pairs come from [verify] map - the source and target id columns of the migration.'
    }

    $pairs = @($c.Map.Keys | ForEach-Object { [pscustomobject]@{ Source = "$_"; Target = "$($c.Map[$_])" } })
    if ($Limit -gt 0 -and $pairs.Count -gt $Limit) { $pairs = @($pairs | Select-Object -First $Limit) }

    Write-VaultLog "$($c.SourceHost)  vs  $($c.TargetHost)"
    Write-VaultLog "$($pairs.Count) mapped pair(s) in the population"

    $chosen = Resolve-VaultVerifyScope -Pairs $pairs -Mode $Mode -TrialSize $TrialSize `
                  -Confidence $Confidence -MarginPct $MarginPct -Seed $Seed

    if ($c.Workers -gt 1 -and $chosen.Count -gt 1) {
        if ($Depth -eq 'DEEP') {
            Write-VaultLog "DEEP across $($c.Workers) worker(s) holds up to $($c.Workers * 2) files on disk at once" 'WARN'
        }
        # The scope was chosen HERE. Each worker censuses its own shard, so the sample is
        # drawn once rather than eight times - eight independent samples of one population
        # is not a sample of it.
        return Invoke-VaultShardedRun -Context $c -Pending $chosen -Workers $c.Workers `
                   -Command @('verify', 'census') -LogPattern "verify-$Mode-*.log" `
                   -ResultsName 'migration-validate-results.csv' -KeyColumn 'SourceDocId' `
                   -SuccessStatus 'VERIFIED' -Verb 'Verified' -ShardKind 'map' `
                   -ExtraArgs @('-Depth', $Depth)
    }

    $rules = $null; $dir = $null
    if ($WithRoleRules) {
        # One read for the whole run, not one per document.
        Write-VaultLog 'Reading the lifecycle role assignment rules, to check roles against configuration'
        $dir   = Get-VaultDirectory -Context $c
        $rules = Get-VaultRoleAssignmentRule -Context $c -Directory $dir
        if (-not $rules.Count) { Write-VaultLog 'No role assignment rules readable - roles will be reported as present or empty only.' 'WARN' }
    }

    $results = New-VaultResults -Path (Join-Path $c.Out 'migration-validate-results.csv') `
                   -KeyColumn 'SourceDocId' -DoneStatuses @() -Existing $c.Existing

    $stat = @{ Verified = 0; Failed = 0; Partial = 0; Errors = 0 }
    $i = 0
    foreach ($pair in $chosen) {
        $i++
        $prefix = "[$i/$($chosen.Count)] $($pair.Source) -> $($pair.Target)"
        $row = Test-VaultMigratedDocument -Context $c -SourceId $pair.Source -TargetId $pair.Target `
                   -Depth $Depth -Rules $rules -Directory $dir
        switch ($row.Status) {
            'VERIFIED' { $stat.Verified++; Write-VaultLog "$prefix - VERIFIED" 'OK' }
            'FAILED'   { $stat.Failed++;   Write-VaultLog "$prefix - FAILED file=$($row.FileStatus) $($row.Message)" 'ERROR' }
            'ERROR'    { $stat.Errors++;   Write-VaultLog "$prefix - ERROR $($row.Message)" 'ERROR' }
            default    { $stat.Partial++;  Write-VaultLog "$prefix - PARTIAL file=$($row.FileStatus) att=$($row.AttachmentStatus) roles=$($row.RoleStatus)" 'WARN' }
        }
        Add-VaultResult -Results $results -Row $row
    }

    # The tail: Add-VaultResult writes on a cadence, so the last rows are in memory.
    Save-VaultResults -Results $results
    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($chosen.Count) of $($pairs.Count) document(s) checked ($Mode, $Depth)"
    Write-VaultLog ("  VERIFIED  {0}" -f $stat.Verified) 'OK'
    if ($stat.Failed)  { Write-VaultLog ("  FAILED    {0}" -f $stat.Failed) 'ERROR' }
    if ($stat.Partial) { Write-VaultLog ("  PARTIAL   {0}  - some dimension is not done yet, or could not be checked" -f $stat.Partial) 'WARN' }
    if ($stat.Errors)  { Write-VaultLog ("  ERROR     {0}" -f $stat.Errors) 'ERROR' }

    if ($Mode -ne 'census') {
        # Said every time. A sample says something about the population only as a
        # sample - reading "0 failed" off 376 documents as "15,775 documents are fine"
        # is the mistake this line exists to prevent.
        $pct = if ($pairs.Count) { 100.0 * $chosen.Count / $pairs.Count } else { 0 }
        Write-VaultLog ("This is a {0} of {1:N1}% of the population. It does not certify the {2} document(s) not checked." -f $Mode, $pct, ($pairs.Count - $chosen.Count)) 'WARN'
    }
    Write-VaultLog "Results: $($results.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $results.Path
    if ($snap) { Write-VaultLog "This run : $snap" }
    return ($stat.Failed + $stat.Errors)
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
        $file = $MapFile
        if (-not $file) { $file = Get-VaultSetting -Config $script:Cfg -Section $Section -Key $MapKey -Default '' }
        if (-not $file) { throw "[$Section] $MapKey is not set in $($script:CfgPath)" }
        $map = Import-VaultIdMap -Path $file -SourceColumn $SourceColumn -TargetColumn $TargetColumn -LegacyNames @('map.csv')
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
        # Roles repairs ONE vault - the target of the migration - so it reads this
        # rather than choosing between the two.
        VaultHost  = $script:TargetHost
        Out        = $script:Out
        Scratch    = (New-VaultScratch -Root $script:Out -Name 'scratch')
        Map        = $map
        Ids        = $ids
        TargetPath = $tpath
        # ---- submissions ----
        # One vault: the dossiers are already on the TARGET's File Staging and are
        # imported into the TARGET. The source vault is never touched by this workflow.
        StagingPath         = (Get-VaultSetting -Config $script:Cfg -Section submissions -Key path -Default '')
        LookupField         = (Get-VaultSetting -Config $script:Cfg -Section submissions -Key lookupfield -Default 'name__v')
        SubmissionMatch     = (Get-VaultSetting -Config $script:Cfg -Section submissions -Key submissionmatch -Default 'prefix')
        ApplicationObject   = (Get-VaultSetting -Config $script:Cfg -Section submissions -Key applicationobject -Default 'application__v')
        ApplicationKeyField = (Get-VaultSetting -Config $script:Cfg -Section submissions -Key applicationkeyfield -Default 'name__v')
        ApplicationRefField = (Get-VaultSetting -Config $script:Cfg -Section submissions -Key applicationreffield -Default 'application__v')
        DossierFormatId     = (Get-VaultSetting -Config $script:Cfg -Section submissions -Key dossierformatid -Default '')
        JobTimeoutMinutes   = [int](Get-VaultSetting -Config $script:Cfg -Section submissions -Key jobtimeoutminutes -Default 120)
        JobPollSeconds      = [int](Get-VaultSetting -Config $script:Cfg -Section submissions -Key jobpollseconds -Default 20)
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

        # Nothing else to fetch. When the module was twelve separate downloads this is
        # where a version added since had to be discovered and pulled, or the new
        # dispatcher would land and fail on its first run saying a file was missing -
        # observed exactly that when Roles and Verify were added. The parts now travel
        # inside vault.ps1, so that whole class of half-applied update is gone.

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
    # VaultKit\ is the same idea one layout later. An operator who updated from the
    # version that shipped the module as twelve files still has the folder, and nothing
    # loads it any more - the parts live inside vault.ps1 now. Left in place and named,
    # not deleted: it is somebody's working folder, and the real cost of leaving it is
    # that a person edits a file in there to fix something and nothing happens.
    $kit = Join-Path $here 'VaultKit'
    if (Test-Path -LiteralPath $kit) {
        Write-Host ''
        Write-Host '  VaultKit\ is here and nothing loads it. The module is built into vault.ps1' -ForegroundColor Yellow
        Write-Host '  now, so those files are a copy of an older version - editing them changes' -ForegroundColor Yellow
        Write-Host '  nothing. Delete the folder once you are sure nothing of yours is in it.' -ForegroundColor Yellow
    }

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
                          -ReplaceDiffering:$ReplaceDiffering -Prefilter:$Prefilter `
                          -TestCount $Test -Limit $Limit
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

function Resolve-VaultSubmissionsHost {
    # Which vault holds the Submissions Archive - resolved, then confirmed.
    #
    # ONE vault: the dossiers are already on its File Staging and are imported into it.
    # Nothing here reads the migration's source, so confirming both would make an
    # operator log in to a production vault this command never touches.
    #
    # Which one is a question, not a given, and File Staging being shared across the
    # instances on a domain means it is a question the staging path cannot answer. This
    # used to default to [vault] target and merely SAY so; a stated default is still a
    # default, and it is read by the same person who is about to hit Enter. It is now
    # offered as a suggestion inside the prompt instead - see Confirm-VaultSubmissionsVault.
    param([switch]$Yes)
    $candidate = ''
    $source    = ''
    if ($VaultHost) {
        $candidate = $VaultHost
        $source    = '-VaultHost'
    }
    else {
        $candidate = Get-VaultSetting -Config $script:Cfg -Section submissions -Key vault -Default ''
        if ($candidate) { $source = '[submissions] vault' }
    }
    return (Confirm-VaultSubmissionsVault -ConfigPath $script:CfgPath -Candidate $candidate `
                -Suggested $script:TargetHost -ApiVersion $script:Api -Source $source -Yes:$Yes)
}

function Invoke-Submissions {
    param([string]$Action)
    switch ($Action) {
        'list' {
            Initialize-VaultRun -LogName 'submissions-list'
            Write-VaultLog "vault $ScriptVersion - submissions list"
            $ctx = New-VaultContext -Section 'submissions'
            $ctx.VaultHost = Resolve-VaultSubmissionsHost -Yes:$Yes
            $ctx.StagingPath = Confirm-VaultStagingPath -ConfigPath $script:CfgPath -Path $ctx.StagingPath -Yes:$Yes
            [void](Invoke-VaultSubmissionsList -Context $ctx -Limit $Limit)
            Write-VaultLog "Log: $script:VaultLogFile"
        }
        'import' {
            Initialize-VaultRun -LogName 'submissions-import'
            Start-VaultLock -Name 'submissions'
            try {
                Write-VaultLog "vault $ScriptVersion - submissions import$(if ($Plan) { ' (plan)' })"
                $ctx = New-VaultContext -Section 'submissions'
                $ctx.VaultHost = Resolve-VaultSubmissionsHost -Yes:$Yes
                $ctx.StagingPath = Confirm-VaultStagingPath -ConfigPath $script:CfgPath -Path $ctx.StagingPath -Yes:$Yes
                $bad = Invoke-VaultSubmissionsImport -Context $ctx -Plan:$Plan -TestCount $Test -Limit $Limit
                Write-VaultLog "Log: $script:VaultLogFile"
                if ($bad -gt 0) { exit 1 }
            }
            finally { Stop-VaultLock }
        }
        default {
            Write-Host "vault.ps1 submissions <list|import>" -ForegroundColor Red
            Write-Host "  list            what is under [submissions] path. No vault writes, no VQL" -ForegroundColor Red
            Write-Host "  import -Plan    resolve every submission id, import nothing" -ForegroundColor Red
            Write-Host "  import          do it for real" -ForegroundColor Red
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

function Invoke-Roles {
    # Document Sharing Settings a migration left empty.
    #
    # ONE vault. This repairs the target of a migration rather than comparing two, so the
    # source is never consulted and never confirmed - being asked to confirm a vault a
    # command will not touch teaches people to say yes without reading.
    param([string]$Action)

    if ($Action -notin @('survey', 'probe', 'explain', 'mdl', 'scope', 'plan', 'assign', 'verify', 'audit')) {
        Write-Host 'vault.ps1 roles <survey|probe|explain|mdl|scope|plan|assign|verify|audit>' -ForegroundColor Red
        exit 2
    }

    Initialize-VaultRun -LogName "roles-$Action"
    Start-VaultLock -Name 'roles'
    try {
        Write-VaultLog "vault $ScriptVersion - roles $Action"
        if (-not $script:TargetHost) { throw "No vault configured. Set [vault] target = ... in $($script:CfgPath)" }
        [void](Confirm-VaultSessions -Vaults @(@{ Role = 'target'; Name = $script:TargetHost }) `
                   -ApiVersion $script:Api -Yes:$Yes)

        # A command of its own, and it needs no document list and no map: it reads the
        # claims out of the results file a run wrote. Ahead of everything that resolves a
        # scope, because it has none - it asked for [roles] map and refused to run
        # without one, for a file it never opens.
        #
        # Never chained onto assign either. Vault ignores group ids it cannot grant and
        # still answers SUCCESS, so the run that made the claim is the last thing that
        # should be trusted to check it.
        if ($Action -eq 'verify') {
            $ctxV = New-VaultContext -Section 'roles'
            $bad = Invoke-VaultRolesVerify -Context $ctxV -Slow:$Slow -Limit $Limit -ExpectIds $ExpectIds -All:$All
            Write-VaultLog "Log: $script:VaultLogFile"
            if ($bad -gt 0) { exit 1 }
            return
        }

        # Reads one document type's whole MDL component. No scope, no documents.
        if ($Action -eq 'mdl') {
            if (-not $Type) { throw "roles mdl needs -Type '<document type label>'. roles survey lists them." }
            $ctxM = New-VaultContext -Section 'roles'
            $bad = Invoke-VaultDocTypeMdlDump -Context $ctxM -TypeLabel $Type -SubtypeLabel $Subtype `
                       -ClassificationLabel $Classification
            Write-VaultLog "Log: $script:VaultLogFile"
            if ($bad -gt 0) { exit 1 }
            return
        }

        $mapSetting = Get-VaultSetting -Config $script:Cfg -Section roles -Key map -Default ''
        if ($Where -and $mapSetting -and -not $MapFile) {
            # Both name the documents to repair. The map says what the migration produced;
            # a query says what matches a condition today, and those stop being the same
            # set the moment anyone adds a document by hand.
            Write-VaultLog "-Where given, so [roles] map is ignored for this run" 'WARN'
        }

        # The window is the required half. The user defaults to this session's own
        # account - which is the one that created the documents, so asking for it again
        # only creates the chance to type a different id by mistake. There is no
        # equivalent default for "how far back": every answer is a different blast
        # radius, and none of them is the obvious one.
        $scoped = ($WithinHours -gt 0)
        if ($scoped -and $Where) { throw '-Where and -WithinHours both name the scope. Pass one.' }
        if ($Action -in @('scope', 'plan', 'assign') -and -not $scoped) {
            throw @'
A permission sync has to say how far back to go:

    roles scope  -WithinHours <n>     just the ids, nothing else
    roles plan   -WithinHours <n>
    roles assign -WithinHours <n>

-WithinHours is required. This command grants people access to documents, and there
is no safe default for how much of the past that should cover.

-CreatedBy defaults to this session's own user, which is normally the account that
created the documents. Pass a numeric user id to name a different one.

roles survey and roles probe write nothing and need no scope.
'@
        }

        $ctx = if ($Where -or ($scoped -and -not $mapSetting)) { New-VaultContext -Section 'roles' }
               else { New-VaultContext -Section 'roles' -MapKey 'map' }

        # -Survey does its own single query and needs no document list, so it answers
        # before the enumeration every other mode depends on.
        if ($Action -eq 'survey') {
            $bad = Invoke-VaultRolesSurvey -Context $ctx -Where $Where
            Write-VaultLog "Log: $script:VaultLogFile"
            if ($bad -gt 0) { exit 1 }
            return
        }

        # Scope is capped only where this command GUESSED it, never where it was given. A
        # probe over a named scope surveys all of it: sampling 25 of 577 documents can
        # miss a subtype entirely and then report that everything is consistent, which is
        # worse than not having run it.
        $documents =
            if ($scoped) {
                # The directory is read ONLY to turn a name into an id. A numeric id
                # needs no lookup, and reading every user and group to print a nicer
                # log line is pages of calls out of the allowance the run itself needs.
                $dirForScope = if ($CreatedBy -match '^(?i)(me|\d+)$') { $null } else { Get-VaultDirectory -Context $ctx }
                $found = Get-VaultCreatedByScope -Context $ctx -CreatedBy $CreatedBy -WithinHours $WithinHours `
                             -Directory $dirForScope -DateField $DateField -CreatorField $CreatorField
                # Narrowed again by the map where there is one: only documents the
                # migration produced AND this person made in the window.
                if ($ctx.Map -and $ctx.Map.Count) { Select-VaultScopeIntersection -Documents $found -Map $ctx.Map }
                else { $found }
            }
            elseif ($Where) { Get-VaultDocumentsByQuery -Context $ctx -Where $Where }
            elseif ($ctx.Map -and $ctx.Map.Count) {
                # {TargetId, SourceId} objects, which is what the roles flow reads. Bare
                # ids are strings, and $doc.TargetId on a string is a terminating error
                # under StrictMode - so this path threw the moment it was taken.
                $byTarget = [ordered]@{}
                foreach ($k in $ctx.Map.Keys) {
                    $t = "$($ctx.Map[$k])"
                    if ($t -and -not $byTarget.Contains($t)) { $byTarget[$t] = "$k" }
                }
                @($byTarget.Keys | ForEach-Object { [pscustomobject]@{ TargetId = "$_"; SourceId = "$($byTarget[$_])" } })
            }
            elseif ($Action -eq 'probe') {
                Write-VaultLog 'No map or -Where given, so sampling the vault in whatever order it returns.'
                Write-VaultLog 'This can miss a subtype entirely. Set [roles] map or pass -Where.' 'WARN'
                Get-VaultDocumentsByQuery -Context $ctx -Where '' -Stop $(if ($Limit -gt 0) { $Limit } else { 200 })
            }
            else {
                # Assign and plan never default to "the whole vault". A probe writes
                # nothing, so guessing its scope costs an operator some time; guessing the
                # scope of a run that grants people access costs a great deal more.
                throw 'No documents named. Set [roles] map, or pass -Where "<VQL condition>".'
            }

        # The ids the scope resolved to, recorded before anything is read or written. A
        # count cannot tell a right filter from a wrong one; the ids can.
        if ($scoped) {
            $stamp = if ($script:VaultLogFile -and ($script:VaultLogFile -match '(\d{8}-\d{6})')) { $Matches[1] } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
            [void](Write-VaultScopeManifest -Documents $documents -Path (Join-Path $ctx.Out "roles-scope-$stamp.csv"))
        }

        $drift = 0
        if ($scoped -and $ExpectIds) {
            $stamp2 = if ($script:VaultLogFile -and ($script:VaultLogFile -match '(\d{8}-\d{6})')) { $Matches[1] } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
            $drift = Compare-VaultScopeToList -Documents $documents -Path $ExpectIds `
                         -OutPath (Join-Path $ctx.Out "roles-scope-reconcile-$stamp2.csv")
        }

        # scope stops here on purpose: one query, no document reads, nothing written. It
        # is the cheapest way to check the filter before spending anything on it.
        if ($Action -eq 'scope') {
            Write-VaultLog 'Nothing was read or changed. Run roles plan next to see the assignments.' 'OK'
            Write-VaultLog "Log: $script:VaultLogFile"
            if ($drift -gt 0) { exit 1 }
            return
        }

        # Reads all three sources and checks they reconcile. Answers the question probe
        # can only infer: whether the reported defaults ARE the lifecycle rules plus the
        # type defaults, or whether something else is contributing.
        if ($Action -eq 'explain') {
            $dirX   = Get-VaultDirectory -Context $ctx
            $rulesX = Get-VaultRoleAssignmentRule -Context $ctx -Directory $dirX
            $bad = Invoke-VaultRolesExplain -Context $ctx -Documents $documents -Rules $rulesX `
                       -Directory $dirX -Limit $(if ($Limit -gt 0) { $Limit } else { 25 })
            Write-VaultLog "Log: $script:VaultLogFile"
            if ($bad -gt 0) { exit 1 }
            return
        }

        # Are the documents right, per the lifecycle rules and the type defaults? Not
        # "did the run do what it recorded" - that is verify - but the question underneath
        # it, asked of the vault as it stands.
        if ($Action -eq 'audit') {
            $dirA   = Get-VaultDirectory -Context $ctx
            $rulesA = Get-VaultRoleAssignmentRule -Context $ctx -Directory $dirA
            if (-not $rulesA.Count) { throw 'No lifecycle role assignment rules were returned, so there is nothing to audit against.' }
            $bad = Invoke-VaultRolesAudit -Context $ctx -Documents $documents -Rules $rulesA `
                       -Directory $dirA -WithTypeDefaults:$WithTypeDefaults -Limit $Limit
            Write-VaultLog "Log: $script:VaultLogFile"
            if ($bad -gt 0) { exit 1 }
            return
        }

        if ($Action -eq 'probe') {
            $bad = Invoke-VaultRolesProbe -Context $ctx -Documents $documents -Limit $Limit
            Write-VaultLog "Log: $script:VaultLogFile"
            if ($bad -gt 0) { exit 1 }
            return
        }

        # -Defaults names a table, so it settles the question on its own. Saying both
        # -Defaults and -DesiredFrom something else is a contradiction, not a preference.
        $table = $null
        $rules = $null
        $from  = $DesiredFrom
        $defaultsPath = $Defaults
        if (-not $defaultsPath) { $defaultsPath = Get-VaultSetting -Config $script:Cfg -Section roles -Key defaults -Default '' }

        if ($defaultsPath) {
            if ($PSBoundParameters.ContainsKey('DesiredFrom') -and $DesiredFrom -ne 'Table') {
                throw "-Defaults and -DesiredFrom $DesiredFrom contradict each other. Drop one."
            }
            $from = 'Table'
        }
        elseif ($from -eq 'Table') {
            throw '-DesiredFrom Table needs a table. Pass -Defaults, or set [roles] defaults.'
        }

        switch ($from) {
            'Table' {
                $table = Import-VaultDefaultsTable -Path $defaultsPath -Directory (Get-VaultDirectory -Context $ctx)
                Write-VaultLog 'Desired state: the defaults table.'
            }
            'Lifecycle' {
                $rules = Get-VaultRoleAssignmentRule -Context $ctx -Directory (Get-VaultDirectory -Context $ctx)
                Write-VaultLog "Desired state: each document's lifecycle role assignment rules."
                if (-not $rules.Count) {
                    throw 'No lifecycle role assignment rules were returned, so there is nothing to apply. Check the account can read Admin configuration, or use -DesiredFrom Document.'
                }
            }
            default {
                Write-VaultLog 'Desired state: the defaultUsers and defaultGroups Vault reports per document.'
                Write-VaultLog 'Run roles probe if you have not - it says whether those carry the type defaults too.' 'WARN'
            }
        }

        $planning = $Plan -or ($Action -eq 'plan')
        $bad = Invoke-VaultRolesAssign -Context $ctx -Documents $documents -From $from -Table $table -Rules $rules `
                   -Assign $Assign -WithTypeDefaults:$WithTypeDefaults -Plan:$planning `
                   -Role $Role -ExcludeRole $ExcludeRole -BatchSize $BatchSize -Test $Test -Limit $Limit `
                   -Resume:$Resume
        Write-VaultLog "Log: $script:VaultLogFile"
        if ($bad -gt 0) { exit 1 }
    }
    finally { Stop-VaultLock }
}

function Invoke-Query {
    # Run one VQL query and show what comes back. Read-only, and the only command that
    # takes a query rather than composing one.
    #
    # It exists because every diagnosis of "why did this not resolve" ended with wanting
    # to ask the vault a question the kit had no way to ask, and the alternative was
    # hand-rolling a session and a curl. VQL cannot write, so there is nothing here to
    # guard against beyond a query that pages for ever, which the page cap handles.
    param([string]$Action)
    $vql = "$Action".Trim()
    if (-not $vql) {
        Write-Host 'vault.ps1 query "<VQL>" -VaultHost <host> [-OutFile results.csv]' -ForegroundColor Red
        Write-Host '  -VaultHost is required - a query aimed at the wrong vault still answers' -ForegroundColor Red
        Write-Host '  e.g. vault.ps1 query "SELECT id, name__v FROM submission__v"' -ForegroundColor Red
        exit 2
    }
    Initialize-VaultRun -LogName 'query'
    Write-VaultLog "vault $ScriptVersion - query"

    # No silent default. Every other command composes its own query against a vault it
    # was designed for; this one runs whatever it is handed, wherever it is pointed, and
    # is the command most likely to be typed ad hoc with a flag forgotten. Falling back
    # to [vault] target would mean a forgotten -VaultHost reads a live migration vault
    # and returns rows that look like they describe the one you meant.
    $h = Get-VaultHostName $VaultHost
    if (-not $h) {
        throw 'query needs -VaultHost. It is not defaulted, because a query aimed at the wrong vault still answers.'
    }
    [void](Confirm-VaultSessions -Vaults @(@{ Role = 'query'; Name = $h }) -ApiVersion $script:Api -Yes:$Yes)

    Write-VaultLog $vql
    $rows = @(Invoke-VaultQuery -VaultHost $h -ApiVersion $script:Api -Vql $vql)
    Write-VaultLog "$($rows.Count) row(s)" 'OK'

    if ($OutFile) {
        $out = Resolve-VaultOutputPath -Path $OutFile
        $rows | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8 -WhatIf:$false
        Write-VaultLog "Written to $out" 'OK'
    }
    else {
        # To the host, not the log: this is a result set being read by a person, and
        # putting a hundred formatted rows through the timestamped logger makes both the
        # table and the log worse.
        $rows | Format-Table -AutoSize | Out-String -Width 4096 | Write-Host
    }
    Write-VaultLog "Log: $script:VaultLogFile"
}

function Invoke-Map {
    # The map, checked and normalised. Needs no vault: this is about a file, and being
    # able to answer "is my map usable" without credentials is most of the point - it is
    # the question you have before a run, not during one.
    param([string]$Action)

    if ($Action -notin @('check', 'write')) {
        Write-Host 'vault.ps1 map <check|write>' -ForegroundColor Red
        Write-Host '  check   read the map and report what it holds. Changes nothing' -ForegroundColor Red
        Write-Host '  write   rewrite it in the canonical two-column form' -ForegroundColor Red
        exit 2
    }

    Initialize-VaultRun -LogName "map-$Action"
    Write-VaultLog "vault $ScriptVersion - map $Action"

    $file = $MapFile
    if (-not $file) { $file = Get-VaultSetting -Config $script:Cfg -Section verify -Key map -Default '' }
    if (-not $file) { $file = Get-VaultSetting -Config $script:Cfg -Section attachments -Key map -Default '' }
    if (-not $file) { throw 'No map named. Pass -MapFile <csv>, or set [verify] map.' }

    # A map has two columns; a list has one. Both are inputs someone needs checked before
    # a run, and refusing a list because it is not a map answers a question nobody asked -
    # the operator wants to know whether their file is usable, not what shape it is.
    $resolved = Resolve-VaultInput -Path $file
    if (-not $resolved) { throw "Not found: $file" }
    $head = @(Get-Content -LiteralPath $resolved -TotalCount 1)
    $isList = $true
    if ($head.Count) {
        foreach ($d in @(',', "`t", ';', '|')) { if ($head[0].Contains($d)) { $isList = $false; break } }
    }

    if ($isList) {
        Write-VaultLog 'One column, so this is read as a list of ids rather than a map.'
        $ids = @(Import-VaultIdList -Path $resolved)
        Write-VaultLog '----------------------------------------------------------------'
        Write-VaultLog "  file        $resolved"
        Write-VaultLog "  ids         $($ids.Count)" 'OK'
        Write-VaultLog "  first few   $((@($ids | Select-Object -First 5)) -join ' ')"
        Write-VaultLog "  last few    $((@($ids | Select-Object -Last 5)) -join ' ')"
        Write-VaultLog 'A list names documents. It cannot say what any of them came from - that needs a map.'

        if ($Action -eq 'write') {
            $out = $OutFile
            if (-not $out) { $out = Join-Path $script:Out 'ids.txt' }
            # Resolved before the guard, not only before the write: the comparison has
            # the same process-working-directory problem, so an unresolved -OutFile could
            # read as a different file from the one it was about to overwrite.
            $out = Resolve-VaultOutputPath -Path $out
            if ($out -eq (Resolve-VaultOutputPath -Path $resolved)) {
                throw "That would overwrite the file it just read ($out). Name a different -OutFile."
            }
            [IO.File]::WriteAllLines($out, $ids, (New-Object Text.UTF8Encoding $false))
            Write-VaultLog "$($ids.Count) id(s) written to $out, one per line, deduplicated" 'OK'
        }
        Write-VaultLog "Log: $script:VaultLogFile"
        exit 0
    }

    $map = Import-VaultIdMap -Path $file -SourceColumn $SourceColumn -TargetColumn $TargetColumn
    $st  = $script:VaultIdMapStats

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "  file        $($st.Path)"
    Write-VaultLog "  encoding    $(if ($st.Bom) { 'UTF-8 with BOM' } else { 'no BOM' })"
    Write-VaultLog "  delimiter   $($st.Delimiter)"
    Write-VaultLog "  columns     $($st.Headers -join ', ')"
    Write-VaultLog "  ids from    '$($st.SourceColumn)' -> '$($st.TargetColumn)'  ($($st.How))"
    Write-VaultLog "  data rows   $($st.Rows)"
    Write-VaultLog "  pairs       $($st.Pairs)" 'OK'
    if ($st.RepeatedPairs) { Write-VaultLog "  repeats     $($st.RepeatedPairs)  - the same pair more than once, which a row-per-file export produces" }
    if ($st.Skipped)       { Write-VaultLog "  skipped     $($st.Skipped)  - no usable id pair. Those documents are NOT processed" 'WARN' }
    Write-VaultLog "  canonical   $(if ($st.Canonical) { 'yes' } else { 'no - source_id,target_id comma separated is the canonical shape' })" `
        $(if ($st.Canonical) { 'OK' } else { 'WARN' })

    if ($Action -eq 'write') {
        $out = $OutFile
        if (-not $out) { $out = Join-Path $script:Out 'map.csv' }
        $out = Resolve-VaultOutputPath -Path $out
        if ($out -eq (Resolve-VaultOutputPath -Path $st.Path)) {
            throw "That would overwrite the map it just read ($out). Name a different -OutFile."
        }
        $n = Export-VaultIdMap -Map $map -Path $out
        Write-VaultLog "$n pair(s) written to $out in canonical form" 'OK'
        Write-VaultLog 'Point [verify] map at it and nothing downstream has to guess again.'
    }

    Write-VaultLog "Log: $script:VaultLogFile"

    # Set explicitly, both ways. A script that simply runs off its end leaves whatever
    # $LASTEXITCODE the previous command happened to set, so a clean check looked like a
    # failure purely because something before it had failed.
    if ($st.Skipped) {
        Write-VaultLog "Exit 1: $($st.Skipped) row(s) name no document that will be migrated." 'WARN'
        exit 1
    }
    exit 0
}

function Invoke-Verify {
    # Is this document migrated? One verdict per source/target pair, across the document's
    # own file, its attachments and its Sharing Settings.
    param([string]$Action)

    if ($Action -eq 'fields') {
        Initialize-VaultRun -LogName 'verify-fields'
        Write-VaultLog "vault $ScriptVersion - verify fields (read only, nothing is changed)"
        [void](Confirm-VaultSessions -Vaults @(@{ Role = 'target'; Name = $script:TargetHost }) `
                   -ApiVersion $script:Api -Yes:$Yes)
        $ctxF = New-VaultContext -Section 'verify'
        [void](Invoke-VaultFieldList -Context $ctxF -Match $Match)
        Write-VaultLog "Log: $script:VaultLogFile"
        return
    }

    if ($Action -in @('anchors', 'map')) {
        Initialize-VaultRun -LogName "verify-$Action"
        Write-VaultLog "vault $ScriptVersion - verify $Action (read only, nothing is changed)"
        [void](Confirm-VaultsForRun)
        $ctx = New-VaultContext -Section 'verify' -MapKey 'map'
        $bad = if ($Action -eq 'anchors') { Invoke-VaultAnchorProbe -Context $ctx -Limit $(if ($Limit -gt 0) { $Limit } else { 500 }) }
               else {
                   if (-not $Anchor) { throw 'verify map needs -Anchor <field>. Run verify anchors to find one.' }
                   Invoke-VaultBuildPairMap -Context $ctx -Anchor $Anchor
               }
        Write-VaultLog "Log: $script:VaultLogFile"
        if ($bad -gt 0) { exit 1 }
        return
    }

    if ($Action -notin @('trial', 'sample', 'census')) {
        Write-Host 'vault.ps1 verify <trial|sample|census>   (also: fields, anchors, map)' -ForegroundColor Red
        Write-Host '  trial   a fixed handful at random - proves the check runs' -ForegroundColor Red
        Write-Host '  sample  sized for a confidence level - evidence about the population' -ForegroundColor Red
        Write-Host '  census  every mapped document' -ForegroundColor Red
        exit 2
    }

    Initialize-VaultRun -LogName "verify-$Action"
    Start-VaultLock -Name 'verify'
    try {
        Write-VaultLog "vault $ScriptVersion - verify $Action ($Depth)"
        [void](Confirm-VaultsForRun)
        $ctx = New-VaultContext -Section 'verify' -MapKey 'map'
        $bad = Invoke-VaultMigrationVerify -Context $ctx -Mode $Action -Depth $Depth `
                   -TrialSize $TrialSize -Confidence $Confidence -MarginPct $Margin -Seed $Seed `
                   -WithRoleRules:$WithRoleRules -Limit $Limit
        Write-VaultLog "Log: $script:VaultLogFile"
        if ($bad -gt 0) { exit 1 }
    }
    finally { Stop-VaultLock }
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

  submissions list         What dossiers are under [submissions] path. No vault writes
  submissions import       Import them into RIM Submissions Archive. -Plan resolves only

  query "<VQL>"            Run one VQL query and show the rows. Read-only

  roles survey             What is in scope: subtypes, roles, defaults. Changes nothing
  roles probe              Whether a defaults table is needed, and what it should say
  roles explain            Prove where the reported defaults come from. Changes nothing
  roles mdl                Every attribute of a document type's MDL component
  roles scope              Which documents the filter selects. One query, changes nothing
  roles plan               Exactly who would be added to which role. Changes nothing
  roles assign             Fill in the Sharing Settings the migration left empty
                           Needs -WithinHours. Every time
  roles verify             Prove what a run recorded is actually on the documents
  roles audit              Do the documents have what the configuration says? Reads only

  verify trial             Is it migrated? A fixed handful at random, to prove the check
  verify sample            The same, sized for a confidence level (95% by default)
  verify census            The same, over every mapped document
  verify fields            Which fields the target's documents have, and of what type
  verify anchors           Which field, if any, relates the two vaults
  verify map               Build the source/target pairs from the vault itself

  map check                Read a map or an id list and report it. No vault needed
  map write                Rewrite it as canonical source_id,target_id
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
  -Where <vql>             roles: name the documents by condition instead of a map
  -DesiredFrom <src>       roles: Lifecycle (default), Document, or Table
  -Assign Both|Groups|Users  roles: what kind of principal to assign
  -WithTypeDefaults        roles: apply the document type's defaults as well
  -Defaults <csv>          roles: a defaults table. Overrides [roles] defaults
  -Role / -ExcludeRole     roles: only these roles, or all but these
  -BatchSize <n>           roles: assignments per request (default 200)
  -CreatedBy <user>        roles: only documents this user created. 'me' is this
                           session's own user, which is usually the one that made them
  -WithinHours <n>         roles scope/plan/assign: how far back. REQUIRED
  -DateField <name>        roles: default document_creation_date__v (a DateTime)
  -CreatorField <name>     roles: default created_by__v
  -ExpectIds <txt>         roles scope: check the query returns exactly these ids
                           roles verify: account for every one of them, one per line
  -Resume                  roles assign: skip what an earlier run finished
  -Slow                    roles verify: read roles per document, not in bulk
  -All                     roles verify: check documents that were already correct too
  -TrialSize <n>           verify trial: how many (default 25)
  -Confidence 90|95|99     verify sample: confidence level (default 95)
  -Margin <pct>            verify sample: margin of error (default 5)
  -Seed <n>                verify: fix the random selection so it can be repeated
  -WithRoleRules           verify: check roles against the lifecycle rules as well
  -Anchor <field>          verify map: the target field holding the source id
  -Match <regex>           verify fields: show only fields matching this
  -Type / -Subtype / -Classification
                           roles mdl: which document type to dump, to three levels
  -MapFile <csv>           map: which file to read
  -OutFile <csv>           map write: where to put the canonical copy
  -SourceColumn <name>     map: name the id columns instead of detecting them
  -TargetColumn <name>
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

roles reads ONE vault - the target it repairs - so it confirms that one only.

Not yet ported: the object record pull that get-attachments.bat does today -
attachments hanging off submission__v records, staged for the loader.

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
    'submissions' { Invoke-Submissions -Action $sub }
    'roles'       { Invoke-Roles -Action $sub }
    'verify'      { Invoke-Verify -Action $sub }
    'map'         { Invoke-Map -Action $sub }
    'query'       { Invoke-Query -Action $Subcommand }
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
