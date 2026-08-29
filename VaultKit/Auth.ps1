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

    $blocked = $script:VaultNoPrompt
    if (-not $blocked) {
        try { $blocked = [Console]::IsInputRedirected } catch { }
    }
    if ($blocked) {
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
    $canAsk = $true
    if ($script:VaultNoPrompt) { $canAsk = $false }
    if ($canAsk) { try { if ([Console]::IsInputRedirected) { $canAsk = $false } } catch { } }
    if (-not $canAsk) {
        Write-VaultLog 'Not a console - proceeding without confirmation.' 'WARN'
        return $rows
    }

    $answer = Read-Host 'Are these the right two vaults? [y/N]'
    if ($answer -notmatch '^[Yy]') { throw 'Stopped: the vaults were not confirmed.' }
    return $rows
}
