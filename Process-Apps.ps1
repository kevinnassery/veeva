<#
.SYNOPSIS
    Runs Import-VaultSubmissions.ps1 for every application listed in apps.txt.

.DESCRIPTION
    Reads apps.txt (one application per line), and for each one invokes the import
    script with that application's staging path, writing results to a per-application
    folder so nothing overwrites. Credentials are entered once and reused for all.

    Everything else - VaultDNS, ApiVersion, field mappings, etc. - is inherited from
    config.ini, exactly as a single run would use it.

.PARAMETER Mode
    MANIFEST | DRYRUN | IMPORT. Same meaning as MODE in config.ini, applied to every app.
    Defaults to DRYRUN so a multi-app run can't import by accident.

.EXAMPLE
    .\Process-Apps.ps1 -Mode DRYRUN
    .\Process-Apps.ps1 -Mode IMPORT
#>

[CmdletBinding()]
param(
    [ValidateSet('MANIFEST','DRYRUN','IMPORT')]
    [string]$Mode        = 'DRYRUN',
    [string]$AppsFile    = '',
    [string]$ConfigFile  = '',
    [string]$OutputRoot  = '',
    [string]$StagingRoot = '/SubmissionsArchive',
    [pscredential]$Credential,
    [switch]$Force        # skip the IMPORT confirmation
)

$ErrorActionPreference = 'Stop'
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).ProviderPath }

$script = Join-Path $here 'Import-VaultSubmissions.ps1'
if (-not (Test-Path -LiteralPath $script)) { throw "Import-VaultSubmissions.ps1 not found beside this wrapper." }
if (-not $AppsFile)   { $AppsFile   = Join-Path $here 'apps.txt' }
if (-not (Test-Path -LiteralPath $AppsFile)) { throw "Applications list not found: $AppsFile" }
if (-not $ConfigFile) { $ConfigFile = Join-Path $here 'config.ini' }

# Base OutputRoot: -OutputRoot, else the OutputRoot from config.ini, else here.
if (-not $OutputRoot -and (Test-Path -LiteralPath $ConfigFile)) {
    $line = (Get-Content -LiteralPath $ConfigFile | Where-Object { $_ -match '^\s*OutputRoot\s*=' } | Select-Object -Last 1)
    if ($line) {
        $v = ($line -replace '^\s*OutputRoot\s*=\s*', '')
        $v = ($v -split '\s+[#;]', 2)[0].Trim().Trim('"', "'")
        $OutputRoot = [Environment]::ExpandEnvironmentVariables($v)
    }
}
if (-not $OutputRoot) { $OutputRoot = Join-Path $here 'import-runs' }

$apps = @(Get-Content -LiteralPath $AppsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
if ($apps.Count -eq 0) { throw "No applications listed in $AppsFile" }

Write-Host "Applications ($($apps.Count)): $($apps -join ', ')" -ForegroundColor Cyan
Write-Host "Mode: $Mode   OutputRoot: $OutputRoot" -ForegroundColor Cyan

if ($Mode -eq 'IMPORT' -and -not $Force) {
    $ans = Read-Host "About to IMPORT $($apps.Count) application(s) FOR REAL. Type YES to continue"
    if ($ans -ne 'YES') { Write-Host "Aborted."; return }
}

# One credential prompt for the whole batch (skipped if config.ini has a SessionId).
if (-not $Credential) { $Credential = Get-Credential -Message "Vault credentials (used for every application)" }

$modeArgs = @{}
switch ($Mode) {
    'MANIFEST' { $modeArgs['GenerateManifest'] = $true }
    'DRYRUN'   { $modeArgs['WhatIf']           = $true }
    'IMPORT'   { }
}

$summary = New-Object System.Collections.ArrayList
$n = 0
foreach ($app in $apps) {
    $n++
    $staging = if ($app.StartsWith('/')) { $app } else { "$StagingRoot/$app" }
    $label   = @($staging -split '/' | Where-Object { $_ })[-1]
    $out     = Join-Path $OutputRoot $label

    Write-Host ""
    Write-Host "=== [$n/$($apps.Count)] $label  ->  $staging  ($Mode) ===" -ForegroundColor Cyan
    $exit = 0
    try {
        & $script -ConfigFile $ConfigFile -SourceStagingPath $staging -OutputRoot $out -Credential $Credential @modeArgs
        $exit = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    }
    catch {
        Write-Host "  $label FAILED: $_" -ForegroundColor Red
        $exit = 1
    }
    [void]$summary.Add([pscustomobject]@{ App = $label; Staging = $staging; Exit = $exit; Results = (Join-Path $out 'import-results.csv') })
}

Write-Host ""
Write-Host "==== Summary ($Mode) ====" -ForegroundColor Cyan
$summary | Format-Table App, Exit, Results -AutoSize

$bad = @($summary | Where-Object { $_.Exit -ne 0 }).Count
if ($bad) {
    Write-Host "$bad application(s) reported failures - see each import-results.csv above." -ForegroundColor Yellow
    exit 1
}
Write-Host "All $($apps.Count) application(s) processed. Results under $OutputRoot\<app>\import-results.csv" -ForegroundColor Green
