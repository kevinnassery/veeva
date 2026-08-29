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

# A local that differs from one of the function's own parameters only in case.
#
# PowerShell variable names are case-insensitive, so $staged and $Staged are ONE
# variable. Writing to what looks like a fresh local silently overwrites the parameter -
# and if the parameter is typed, as a [switch] is, every call fails with "Cannot convert
# System.Object[] to SwitchParameter". That shipped once and broke every document in a
# verify run. Same-case assignment is deliberate and not reported; differing case is
# almost always someone believing they are two variables.
$shadow = @()
foreach ($path in ($asts.Keys | Sort-Object)) {
    foreach ($fn in $asts[$path].FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        $params = @()
        if ($fn.Parameters) { $params += $fn.Parameters }
        if ($fn.Body -and $fn.Body.ParamBlock) { $params += $fn.Body.ParamBlock.Parameters }
        $names = @($params | ForEach-Object { $_.Name.VariablePath.UserPath })
        if (-not $names.Count) { continue }

        $assigned = @($fn.FindAll({ $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
                      ForEach-Object { $_.Left } |
                      Where-Object { $_ -is [System.Management.Automation.Language.VariableExpressionAst] } |
                      ForEach-Object { $_.VariablePath.UserPath } |
                      Sort-Object -Unique)

        foreach ($a in $assigned) {
            foreach ($n in $names) {
                if (($n -eq $a) -and ($n -cne $a)) {
                    $shadow += "SHADOW {0} -> {1}() assigns `${2}, shadowing its parameter `${3}" -f $path, $fn.Name, $a, $n
                }
            }
        }
    }
}
if ($shadow.Count) { $shadow | Sort-Object -Unique }

if ($parseFailed.Count -or $shadow.Count) { exit 1 }
