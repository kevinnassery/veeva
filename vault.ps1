<#
.SYNOPSIS
    One command for the Vault migration work.

.DESCRIPTION
    vault <command> [subcommand] [options]

    Authentication is its own flow: `vault login` prompts once, authenticates every
    vault named in vault.ini, and caches the sessions to .vault-session.json. Every
    other command reads that file and never prompts - unless it is missing, in which
    case the command logs in itself, so a first run works without knowing login exists.

.NOTES
    Windows PowerShell 5.1 compatible. No modules to install.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)][string]$Command = 'help',
    [Parameter(Position = 1)][string]$Subcommand = '',
    [string]$ConfigFile = '',
    [string]$OutputRoot = '',
    [switch]$NoPrompt
)

$ScriptVersion = '2026.08.28-3'

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$here = $PSScriptRoot
if (-not $here) { $here = (Get-Location).ProviderPath }

foreach ($part in @('Log', 'Config', 'Auth', 'Http')) {
    $f = Join-Path (Join-Path $here 'VaultKit') "$part.ps1"
    if (-not (Test-Path -LiteralPath $f)) { throw "VaultKit\$part.ps1 is missing next to vault.ps1" }
    . $f
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
}

function Get-ConfiguredHosts {
    $hosts = @()
    if ($script:SourceHost) { $hosts += $script:SourceHost }
    if ($script:TargetHost -and $script:TargetHost -ne $script:SourceHost) { $hosts += $script:TargetHost }
    if (-not $hosts.Count) { throw "No vaults configured. Set [vault] source = ... in $($script:CfgPath)" }
    return $hosts
}

# --------------------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------------------

function Invoke-Login {
    Initialize-VaultRun -LogName 'login'
    $hosts = Get-ConfiguredHosts
    Write-VaultLog "vault $ScriptVersion - logging in to $($hosts.Count) vault(s)"

    # One prompt for all of them: the same account exists on each side. Get-VaultCredential
    # caches in memory, so the second Connect reuses the first answer.
    $cred = Get-VaultCredential -Message "Vault credentials (used for all $($hosts.Count) vault(s))"
    foreach ($h in $hosts) { [void](Connect-VaultHost -VaultHost $h -ApiVersion $script:Api -Credential $cred) }

    Write-VaultLog "Sessions cached in $(Get-VaultSessionPath)" 'OK'
    Write-VaultLog 'That file is a live token for your account. Treat it like a password; vault logout removes it.' 'WARN'
}

function Invoke-Whoami {
    Initialize-VaultRun
    $sessions = Read-VaultSessions
    if (-not $sessions.Count) {
        Write-VaultLog "No cached sessions. Run: vault login" 'WARN'
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

function Invoke-Help {
    $v = $ScriptVersion
    Write-Host @"

vault $v

  vault login              Log in to every configured vault, cache the sessions
  vault whoami             Who each cached session belongs to, and its age
  vault logout             Delete the cached sessions
  vault probe              Read-only survey of each vault. Changes nothing
  vault version            Print the version
  vault help               This

Options
  -ConfigFile <path>       Default: vault.ini beside this script
  -OutputRoot <path>       Overrides [paths] output
  -NoPrompt                Fail instead of asking for credentials

Config is vault.ini, sectioned:

  [vault]
  source = your-source-vault.veevavault.com
  target = your-target-vault.veevavault.com
  api    = v26.2

  [paths]
  output = C:\Users\you\vault-work

Sessions are cached in .vault-session.json beside this script, keyed by vault
host. It holds live tokens: treat it like a password, and run vault logout when
you are finished.

Not yet ported from legacy\: attachments sync and verify, documents transfer,
submissions import, object record pull.

"@
}

# --------------------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------------------

$verb = "$Command".ToLowerInvariant()
$sub  = "$Subcommand".ToLowerInvariant()

switch ($verb) {
    'login'   { Invoke-Login }
    'whoami'  { Invoke-Whoami }
    'logout'  { Invoke-Logout }
    'probe'   { Invoke-Probe }
    'version' { Write-Host $ScriptVersion }
    'help'    { Invoke-Help }
    ''        { Invoke-Help }
    default   {
        Write-Host "Unknown command '$Command'." -ForegroundColor Red
        if ($sub) { Write-Host "(subcommand '$Subcommand' was also given)" -ForegroundColor Red }
        Invoke-Help
        exit 2
    }
}
