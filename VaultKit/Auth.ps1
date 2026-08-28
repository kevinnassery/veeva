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

$script:VaultSessions   = $null
$script:VaultSessionPath = ''
$script:VaultCredential = $null   # held in memory only, for silent re-auth mid-run

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

function Write-VaultSessions {
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
    # Refuse to prompt where nobody can answer. Get-Credential blocks indefinitely when
    # stdin is redirected - a scheduled run, a pipeline, anything non-interactive - so a
    # command with no cached session hangs for ever instead of failing. Fail loudly
    # instead, naming the fix.
    param([string]$Message = 'Vault credentials')
    if ($script:VaultCredential) { return $script:VaultCredential }

    $blocked = $script:VaultNoPrompt
    if (-not $blocked) {
        try { $blocked = [Console]::IsInputRedirected } catch { }
    }
    if ($blocked) {
        throw "No cached session and no way to ask for credentials here. Run 'vault login' from a console first."
    }

    $script:VaultCredential = Get-Credential -Message $Message
    if (-not $script:VaultCredential) { throw 'No credentials given.' }
    return $script:VaultCredential
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
    if (-not $Credential) { $Credential = Get-VaultCredential -Message "Vault credentials for $VaultHost" }

    $body = @{ username = $Credential.UserName; password = $Credential.GetNetworkCredential().Password }
    $r = Invoke-RestMethod -Method Post -Uri "https://$VaultHost/api/$ApiVersion/auth" `
            -Body $body -ContentType 'application/x-www-form-urlencoded' `
            -Headers @{ Accept = 'application/json' }

    if ((Get-VaultField $r 'responseStatus') -ne 'SUCCESS') {
        throw "Authentication failed for ${VaultHost}: $($r | ConvertTo-Json -Depth 5 -Compress)"
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
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -WhatIf:$false
        return $true
    }
    return $false
}
