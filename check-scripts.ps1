# Pre-push check: parse every script, then confirm each command it calls is either
# defined in that file or a real cmdlet. Parsing alone does not catch a call to a
# function that was never defined - which is exactly how a helper went missing.
#
#   pwsh -NoProfile -File check-scripts.ps1
#
foreach ($f in @('Transfer-VaultDocuments.ps1','Invoke-VaultDocumentAction.ps1','Probe-Vault.ps1','Get-VaultSession.ps1')) {
  $errs=$null; $toks=$null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f).Path,[ref]$toks,[ref]$errs)
  if ($errs.Count) { "PARSE FAIL $f"; continue }
  $defined = @($ast.FindAll({$args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true) | ForEach-Object { $_.Name })
  $called  = @($ast.FindAll({$args[0] -is [System.Management.Automation.Language.CommandAst]},$true) |
               ForEach-Object { $_.GetCommandName() } | Where-Object { $_ } | Sort-Object -Unique)
  $missing = @()
  foreach ($c in $called) {
    if ($defined -contains $c) { continue }
    if (Get-Command $c -ErrorAction SilentlyContinue) { continue }
    $missing += $c
  }
  if ($missing.Count) { 'FAIL {0} -> {1}' -f $f, ($missing -join ', ') } else { 'OK   {0}' -f $f }
}
