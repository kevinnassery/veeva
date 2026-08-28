# Exercise the parts of veeva-validate.ps1 that do not need a vault.
#
# Kept separate from test-roles.ps1 for the same reason the validator is kept separate
# from the tool: a shared harness is one more thing that could be wrong in both places at
# once. The name-folding cases here are written as literal expected values, NOT compared
# against veeva-roles.ps1's ConvertTo-NameKey - two implementations agreeing with each
# other proves nothing if they are both wrong.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$src   = Join-Path $PSScriptRoot 'veeva-validate.ps1'
$lines = Get-Content -LiteralPath $src
$start = ($lines | Select-String -Pattern '^#  Small things$' | Select-Object -First 1).LineNumber
$cut   = ($lines | Select-String -Pattern '^#  Run$' | Select-Object -First 1).LineNumber
if (-not $start -or -not $cut) { throw 'Could not find the section banners in veeva-validate.ps1' }
Invoke-Expression (($lines[$start..($cut - 3)]) -join "`n")

$Slow = $false
$pass = 0; $fail = 0
function ok  { param($m) Write-Host "  PASS  $m" -ForegroundColor Green; $script:pass++ }
function bad { param($m) Write-Host "  FAIL  $m" -ForegroundColor Red;   $script:fail++ }
function eq  { param($m, $a, $b) if ("$a" -eq "$b") { ok $m } else { bad "$m  (got '$a', want '$b')" } }

Write-Host "`n== Get-FoldedName, against literal expectations =="
eq 'drops a __v suffix'      (Get-FoldedName 'editor__v')            'editor'
eq 'drops a __c suffix'      (Get-FoldedName 'technical_editor__c')  'technicaleditor'
eq 'drops a __sys suffix'    (Get-FoldedName 'doc_role__sys')        'docrole'
eq 'folds a UI label'        (Get-FoldedName 'Business Administrators') 'businessadministrators'
eq 'label and name agree'    (Get-FoldedName 'General Lifecycle')    (Get-FoldedName 'general_lifecycle__c')
eq 'only a TRAILING suffix'  (Get-FoldedName 'a__c_b__v')            'acb'
eq 'digits survive'          (Get-FoldedName 'Group 2__c')           'group2'
eq 'empty stays empty'       (Get-FoldedName '')                     ''
eq 'punctuation only'        (Get-FoldedName '---')                  ''

Write-Host "`n== current state is read through doc_role__sys, not the roles endpoint =="
$script:calls = New-Object System.Collections.ArrayList
function Invoke-Api {
  param($VaultHost, $Method, $Path, $Body, $ContentType, $MaxRetries)
  [void]$script:calls.Add([pscustomobject]@{ Path = $Path; Body = $Body })
  return ([pscustomobject]@{ responseStatus = 'SUCCESS'; data = @(
    [pscustomobject]@{ document_id = 771; role_name__sys = 'editor__v';   group__sys = 11 },
    [pscustomobject]@{ document_id = 771; role_name__sys = 'editor__v';   group__sys = 12 },
    [pscustomobject]@{ document_id = 772; role_name__sys = 'consumer__v'; group__sys = 16 }
  ) })
}
$cur = Get-CurrentGroups -VaultHost 'x.veevavault.com' -DocIds @('771', '772')
eq 'asked doc_role__sys'      ($script:calls[0].Body -match 'doc_role__sys') $true
eq 'never the roles endpoint' (@($script:calls | Where-Object { $_.Path -like '*/roles' }).Count) 0
eq 'reports its method'       $cur.Method 'doc_role__sys (bulk)'
eq 'both groups on 771'       (($cur.ByKey['771|editor'].Keys | Sort-Object) -join ',') '11,12'
eq 'group on 772'             (($cur.ByKey['772|consumer'].Keys | Sort-Object) -join ',') '16'
eq 'a role with none absent'  ($cur.ByKey.ContainsKey('772|editor')) $false

Write-Host "`n== a vault that refuses the query falls back rather than passing everything =="
$script:calls.Clear()
function Invoke-Api {
  param($VaultHost, $Method, $Path, $Body, $ContentType, $MaxRetries)
  [void]$script:calls.Add([pscustomobject]@{ Path = $Path; Body = $Body })
  if ($Path -eq '/query') { throw 'MALFORMED_QUERY: doc_role__sys will not take that' }
  return ([pscustomobject]@{ responseStatus = 'SUCCESS'; documentRoles = @(
    [pscustomobject]@{ name = 'editor__v'; assignedGroups = @(11, 13) }) })
}
$cur2 = Get-CurrentGroups -VaultHost 'x.veevavault.com' -DocIds @('771')
eq 'fell back'              $cur2.Method 'one read per document'
eq 'and still read state'   (($cur2.ByKey['771|editor'].Keys | Sort-Object) -join ',') '11,13'

Write-Host "`n== the group index answers to labels and to API names =="
function Invoke-Api {
  param($VaultHost, $Method, $Path, $Body, $ContentType, $MaxRetries)
  return ([pscustomobject]@{ responseStatus = 'SUCCESS'; groups = @(
    [pscustomobject]@{ group = [pscustomobject]@{ id = 11; label__v = 'Business Administrators'; name__v = 'business_administrators__c' } },
    [pscustomobject]@{ group = [pscustomobject]@{ id = 16; label__v = 'Document Users';          name__v = 'document_users__c' } }
  ) })
}
$g = Get-GroupIndex -VaultHost 'x.veevavault.com'
eq 'by label'    $g.ByName[(Get-FoldedName 'Business Administrators')] '11'
eq 'by api name' $g.ByName[(Get-FoldedName 'business_administrators__c')] '11'
eq 'id to name'  $g.ById['16'] 'Document Users'

Write-Host ''
Write-Host "$pass passed, $fail failed" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
if ($fail) { exit 1 }
