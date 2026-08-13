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

.PARAMETER SamplePercent
    Process a random percentage (1-100) of each application's submissions instead of
    all of them. 0 = no sampling. Applied per application, so every app in apps.txt is
    sampled, not just some of the apps.

.PARAMETER ExistingResults
    What to do when reports from an earlier run are already in an application's output
    folder. Prompt (default) asks ONCE for the whole batch and applies the answer to
    every application; Resume keeps them; Restart rotates them aside and begins fresh.
    The importer itself is always given an explicit answer, so it never stops mid-wave.

.EXAMPLE
    .\Process-Apps.ps1 -Mode DRYRUN
    .\Process-Apps.ps1 -Mode IMPORT
    .\Process-Apps.ps1 -Mode DRYRUN -SamplePercent 10
    .\Process-Apps.ps1 -Mode IMPORT -ExistingResults Restart
#>

[CmdletBinding()]
param(
    [ValidateSet('MANIFEST','DRYRUN','IMPORT')]
    [string]$Mode        = 'DRYRUN',
    [string]$AppsFile    = '',
    [string]$ConfigFile  = '',
    [string]$OutputRoot  = '',
    [string]$StagingRoot = '/SubmissionsArchive',
    [ValidateRange(0, 100)]
    [int]$SamplePercent  = 0,   # 0 = every submission; 1-100 = a random sample per app
    [ValidateSet('Prompt','Resume','Restart')]
    [string]$ExistingResults = 'Prompt',   # what to do with reports from an earlier run
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

# Work out each application's staging path and output folder up front - the existing-report
# check below needs them before the run starts, and the loop then reuses the same plan.
$plan = @(foreach ($app in $apps) {
    $staging = if ($app.StartsWith('/')) { $app } else { "$StagingRoot/$app" }
    $label   = @($staging -split '/' | Where-Object { $_ })[-1]
    [pscustomobject]@{ App = $label; Staging = $staging; Out = (Join-Path $OutputRoot $label) }
})

$sampling = ($SamplePercent -gt 0 -and $SamplePercent -lt 100)

Write-Host "Applications ($($apps.Count)): $($apps -join ', ')" -ForegroundColor Cyan
Write-Host "Mode: $Mode   OutputRoot: $OutputRoot" -ForegroundColor Cyan
if ($sampling) {
    Write-Host "Sampling: a random $SamplePercent% of each application's submissions" -ForegroundColor Yellow
}

if ($Mode -eq 'IMPORT' -and -not $Force) {
    $what = if ($sampling) { "a random $SamplePercent% of $($apps.Count) application(s)" } else { "$($apps.Count) application(s)" }
    $ans  = Read-Host "About to IMPORT $what FOR REAL. Type YES to continue"
    if ($ans -ne 'YES') { Write-Host "Aborted."; return }
}

# Settle the existing-reports question ONCE for the whole batch. Asking per application
# would stop a twelve-app wave twelve times, so the answer is resolved here and passed
# down explicitly - the importer then never prompts mid-run.
if ($ExistingResults -eq 'Prompt') {
    $stale = @(foreach ($p in $plan) {
        foreach ($f in 'import-results.csv', 'manifest.csv') {
            $path = Join-Path $p.Out $f
            if (Test-Path -LiteralPath $path) { "$($p.App)\$f" }
        }
    })
    if ($stale.Count -eq 0) {
        $ExistingResults = 'Resume'   # nothing there, nothing to ask about
    }
    else {
        Write-Host ""
        Write-Host "Reports from an earlier run already exist for $(@($stale | ForEach-Object { ($_ -split '\\')[0] } | Select-Object -Unique).Count) of $($plan.Count) application(s):" -ForegroundColor Yellow
        $stale | ForEach-Object { Write-Host "  $OutputRoot\$_" -ForegroundColor Yellow }
        # Both conditions - see the same guard in Import-VaultSubmissions.ps1.
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
            $ans = ''
            while ($ans -notmatch '^(C|CONTINUE|R|RESTART)$') {
                $ans = "$(Read-Host '[C]ontinue (skip what already succeeded), or [R]estart (rotate these aside and begin fresh)? [C]')".Trim().ToUpperInvariant()
                if (-not $ans) { $ans = 'C' }
            }
            $ExistingResults = if ($ans -match '^R') { 'Restart' } else { 'Resume' }
        }
        else {
            $ExistingResults = 'Resume'
            Write-Host "Not an interactive session - continuing. Pass -ExistingResults Restart to start fresh." -ForegroundColor Yellow
        }
        Write-Host "Applying '$ExistingResults' to all $($plan.Count) application(s)." -ForegroundColor Yellow
    }
}

# One credential prompt for the whole batch (skipped if config.ini has a SessionId).
if (-not $Credential) { $Credential = Get-Credential -Message "Vault credentials (used for every application)" }

$modeArgs = @{}
switch ($Mode) {
    'MANIFEST' { $modeArgs['GenerateManifest'] = $true }
    'DRYRUN'   { $modeArgs['WhatIf']           = $true }
    'IMPORT'   { }
}
# Only pass it when set, so config.ini's SamplePercent still applies when the wrapper
# doesn't override it - an explicit -SamplePercent 0 would beat the file.
if ($SamplePercent -gt 0) { $modeArgs['SamplePercent'] = $SamplePercent }
# Always explicit, never 'Prompt' - the batch has already asked.
$modeArgs['ExistingResults'] = $ExistingResults

$summary = New-Object System.Collections.ArrayList
$n = 0
foreach ($p in $plan) {
    $n++
    $staging = $p.Staging
    $label   = $p.App
    $out     = $p.Out

    Write-Host ""
    $tag = if ($sampling) { "$Mode, $SamplePercent% sample" } else { $Mode }
    Write-Host "=== [$n/$($apps.Count)] $label  ->  $staging  ($tag) ===" -ForegroundColor Cyan
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
if ($sampling) {
    Write-Host "Sampled run: a random $SamplePercent% of each application, NOT the full wave." -ForegroundColor Yellow
}

$bad = @($summary | Where-Object { $_.Exit -ne 0 }).Count
if ($bad) {
    Write-Host "$bad application(s) reported failures - see each import-results.csv above." -ForegroundColor Yellow
    exit 1
}
Write-Host "All $($apps.Count) application(s) processed. Results under $OutputRoot\<app>\import-results.csv" -ForegroundColor Green
