# Pre-push check: every script parses, and every command it calls is either defined
# somewhere in this repo or is a real cmdlet.
#
# Functions are collected across ALL files first, because VaultKit is one module split
# over several files - Auth.ps1 calls Write-VaultLog from Log.ps1, and checking each
# file alone would report that as undefined.
#
#   pwsh -NoProfile -File check-scripts.ps1

$files = Get-ChildItem -Path . -Filter *.ps1 -Recurse |
         Where-Object { $_.FullName -notmatch '[\\/]docs[\\/]' -and $_.Name -ne 'check-scripts.ps1' }

# Cmdlets that exist on Windows PowerShell but not on this host. Their absence here
# says nothing about the scripts, which only ever run on Windows.
$windowsOnly = @('Get-Acl', 'Set-Acl', 'Get-CimInstance', 'Get-WmiObject', 'Export-Clixml', 'Import-Clixml')

$asts = @{}
$defined = New-Object System.Collections.Generic.HashSet[string]
$parseFailed = @()

foreach ($f in $files) {
    $errs = $null; $toks = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$toks, [ref]$errs)
    if ($errs.Count) {
        $parseFailed += $f
        "PARSE FAIL {0}" -f $f.FullName
        $errs | Select-Object -First 3 | ForEach-Object { "    line {0}: {1}" -f $_.Extent.StartLineNumber, $_.Message }
        continue
    }
    $asts[$f.FullName] = $ast
    $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
        ForEach-Object { [void]$defined.Add($_.Name) }
}

foreach ($path in ($asts.Keys | Sort-Object)) {
    $called = @($asts[$path].FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true) |
                ForEach-Object { $_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique)
    $missing = @()
    foreach ($c in $called) {
        if ($defined.Contains($c)) { continue }
        if ($windowsOnly -contains $c) { continue }
        if (Get-Command $c -ErrorAction SilentlyContinue) { continue }
        $missing += $c
    }
    if ($missing.Count) { "FAIL {0} -> {1}" -f $path, ($missing -join ', ') }
    else { "OK   {0}" -f $path }
}

if ($parseFailed.Count) { exit 1 }
