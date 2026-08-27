<#
.SYNOPSIS
    Log in once and cache the session id in session.txt, so the other scripts stop
    asking for a username and password on every run.

.DESCRIPTION
    Each script invocation is its own process, so with SessionId blank every run logs
    in again. This writes the session id to session.txt next to the scripts; probe.bat
    and Run-Documents.bat both pick it up automatically when SessionId in documents.ini
    is blank.

    session.txt holds a live bearer token for your Vault account. It is gitignored and
    should be treated like a password: do not paste it into documents.ini (that file is
    in a public repo), do not mail it, and delete it when you are done.

    Vault expires sessions on inactivity. When that happens the scripts prompt once and
    refresh session.txt themselves.
#>

[CmdletBinding()]
param(
    [string] $ConfigFile = '',
    [string] $VaultDNS   = '',
    [ValidatePattern('^v\d+\.\d+$')]
    [string] $ApiVersion = 'v26.2',
    [pscredential] $Credential,
    [switch] $Clear
)

$ScriptVersion = '2026.08.27-20'

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-Field {
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }
$SessionFile = Join-Path $here 'session.txt'

if ($Clear) {
    if (Test-Path -LiteralPath $SessionFile) { Remove-Item -LiteralPath $SessionFile -Force -WhatIf:$false; Write-Host 'session.txt deleted.' -ForegroundColor Green }
    else { Write-Host 'No session.txt to delete.' }
    return
}

if ([string]::IsNullOrWhiteSpace($ConfigFile)) { $ConfigFile = Join-Path $here 'documents.ini' }
if (Test-Path -LiteralPath $ConfigFile) {
    foreach ($line in (Get-Content -LiteralPath $ConfigFile)) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';') -or $t.StartsWith('[')) { continue }
        $eq = $t.IndexOf('='); if ($eq -lt 1) { continue }
        $k = $t.Substring(0, $eq).Trim(); $v = $t.Substring($eq + 1).Trim()
        if ($v -notmatch '^["'']') { $v = ($v -split '\s+[#;]', 2)[0].TrimEnd() }
        $v = $v.Trim('"', "'")
        if ([string]::IsNullOrWhiteSpace($v)) { continue }
        if ($k -eq 'VaultDNS'   -and -not $PSBoundParameters.ContainsKey('VaultDNS'))   { $VaultDNS   = $v }
        if ($k -eq 'ApiVersion' -and -not $PSBoundParameters.ContainsKey('ApiVersion')) { $ApiVersion = $v }
    }
}
if ([string]::IsNullOrWhiteSpace($VaultDNS)) { throw "VaultDNS is not set. Add it to $ConfigFile, or pass -VaultDNS." }
$VaultDNS = $VaultDNS -replace '^https?://', '' -replace '/+$', ''

if (-not $Credential) { $Credential = Get-Credential -Message "Vault credentials for $VaultDNS" }
$r = Invoke-RestMethod -Method Post -Uri "https://$VaultDNS/api/$ApiVersion/auth" `
        -Body @{ username = $Credential.UserName; password = $Credential.GetNetworkCredential().Password } `
        -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' }
if ((Get-Field $r 'responseStatus') -ne 'SUCCESS') { throw "Authentication failed: $($r | ConvertTo-Json -Depth 5 -Compress)" }
if (-not "$(Get-Field $r 'sessionId' '')") { throw "Authentication returned no sessionId. Vault said: $($r | ConvertTo-Json -Depth 5 -Compress)" }

Set-Content -LiteralPath $SessionFile -Value $r.sessionId -Encoding ASCII -NoNewline -WhatIf:$false

Write-Host ''
Write-Host "Get-VaultSession.ps1 $ScriptVersion" -ForegroundColor DarkGray
Write-Host "Logged in to $VaultDNS  (vaultId $($r.vaultId), userId $($r.userId))" -ForegroundColor Green
Write-Host "Session cached in $SessionFile" -ForegroundColor Green
Write-Host 'probe.bat and Run-Documents.bat will use it - no more password prompts.' -ForegroundColor Green
Write-Host ''
Write-Host 'session.txt is a live token for your account. Do not paste it into' -ForegroundColor Yellow
Write-Host 'documents.ini (public repo) or mail it. login.bat -Clear deletes it.' -ForegroundColor Yellow
