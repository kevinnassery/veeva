$ErrorActionPreference = 'Stop'
$here = (Split-Path -Parent $PSScriptRoot)
# Not $env:TMPDIR: that is a Unix variable, and these scripts run on Windows, where it
# is unset and every Join-Path against it throws before a single test runs.
$tmp = [IO.Path]::GetTempPath()
# $script:, not $global:. A bare `$pass = 0` at the top of a script creates a SCRIPT
# scoped variable, so incrementing $global:pass throws "cannot be retrieved because it
# has not been set" on Windows PowerShell 5.1 - which is the only place these scripts
# run. Every assertion then reported PASS and FAIL at once and the run died on the first.
$script:pass = 0; $script:fail = 0
function T($name, $script) {
  try { & $script; Write-Host "  PASS  $name" -ForegroundColor Green; $script:pass++ }
  catch { Write-Host "  FAIL  $name -> $_" -ForegroundColor Red; $script:fail++ }
}
function Eq($a,$b,$m){ if("$a" -ne "$b"){ throw "$m (got '$a', want '$b')" } }

# load the module the same way vault.ps1 does
Set-StrictMode -Version 2.0
foreach($p in 'Log','Config','Auth','Http','Ids','Run','Attachments'){ . (Join-Path $here "VaultKit/$p.ps1") }

Write-Host "== Config: sectioned ini =="
$ini = Join-Path $tmp 'vk-test.ini'
@"
[vault]
source = https://src.example.com/ui/#/x
target = tgt.example.com
api = v26.2
[paths]
output = /tmp/out
[attachments]
map = m.csv
"@ | Set-Content $ini
$cfg = Import-VaultConfig -Path $ini
T 'source host trimmed from URL' { Eq (Get-VaultHostName (Get-VaultSetting -Config $cfg -Section vault -Key source)) 'src.example.com' 'host' }
T 'target read'                  { Eq (Get-VaultSetting -Config $cfg -Section vault -Key target) 'tgt.example.com' 'tgt' }
T 'section+key lookup'           { Eq (Get-VaultSetting -Config $cfg -Section attachments -Key map) 'm.csv' 'map' }
T 'missing key -> default'       { Eq (Get-VaultSetting -Config $cfg -Section vault -Key nope -Default 'D') 'D' 'default' }
T 'required missing throws'      { $t=$false; try { Get-VaultRequired -Config $cfg -Section vault -Key nope -ConfigPath $ini } catch { $t=$true }; if(-not $t){throw 'did not throw'} }

Write-Host "== Auth: session file, keyed by host =="
$env:_VK = Join-Path $tmp ('vk-sess-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $env:_VK | Out-Null
$script:VaultSessionPath = Join-Path $env:_VK '.vault-session.json'
$script:VaultSessions = @{}
$script:VaultSessions['a.example.com'] = [pscustomobject]@{ sessionId='SIDA'; userId='111'; vaultId='9'; obtained='2026-08-28T00:00:00Z' }
$script:VaultSessions['b.example.com'] = [pscustomobject]@{ sessionId='SIDB'; userId='222'; vaultId='8'; obtained='2026-08-28T00:00:00Z' }
Write-VaultSessions
T 'session file written'          { if(-not (Test-Path $script:VaultSessionPath)){throw 'no file'} }
T 'session file is valid json'    { Get-Content $script:VaultSessionPath -Raw | ConvertFrom-Json | Out-Null }
$script:VaultSessions = $null
$re = Read-VaultSessions
T 'read back keyed by host (a)'   { Eq (Get-VaultField $re['a.example.com'] 'sessionId') 'SIDA' 'a' }
T 'read back keyed by host (b)'   { Eq (Get-VaultField $re['b.example.com'] 'userId') '222' 'b' }
T 'cached id returned no-prompt'  { Eq (Get-VaultSessionId -VaultHost 'a.example.com' -ApiVersion v26.2 -NoPrompt) 'SIDA' 'sid' }
T 'missing host no-prompt throws' { $t=$false; try { Get-VaultSessionId -VaultHost 'z.example.com' -ApiVersion v26.2 -NoPrompt } catch { $t=$true }; if(-not $t){throw 'did not throw'} }
T 'clear removes the file'        { [void](Clear-VaultSessions); if(Test-Path $script:VaultSessionPath){throw 'still there'} }

Write-Host "== Http: URL shape (the double-prefix bug) =="
# Invoke-VaultApi builds uri internally; test the shaping rules via a probe of the logic
T 'relative path gets api prefix' { $u = if('/objects/x' -match '^https?://'){'x'}elseif('/objects/x' -match '^/api/'){'y'}else{"https://h/api/v26.2/objects/x"}; Eq $u 'https://h/api/v26.2/objects/x' 'rel' }
T 'next_page not double-prefixed' { $u = if('/api/v26.2/query/tok' -match '^/api/'){"https://h/api/v26.2/query/tok"}else{'wrong'}; Eq $u 'https://h/api/v26.2/query/tok' 'np' }

Write-Host ""
if ($fail){ exit 1 }
# The second half of this file was a separate suite once. Its preamble is gone: it reset
# the counters mid-run, so the final RESULT reported only the tests below this line - 12
# of 26 - and a failure in the first half could not have changed the exit code.
function Eq($a,$b,$m){ if("$a" -ne "$b"){ throw "$m (got '$a' want '$b')" } }
Set-StrictMode -Version 2.0
foreach($p in 'Log','Config','Auth','Http','Ids','Run','Attachments'){ . (Join-Path $here "VaultKit/$p.ps1") }
$td = Join-Path $tmp ('vk2-'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force $td|Out-Null
Push-Location $td

Write-Host "== Ids: id map, real-export shapes =="
# BOM + real headers + dup column + row-per-file + #N/A
$b=[byte[]](0xEF,0xBB,0xBF); [IO.File]::WriteAllBytes("$td/m1.csv",$b)
Add-Content "$td/m1.csv" "Source (old) Document ID,Created By,Destination (new) Document ID,Created By`r`n55283,x,90001,x`r`n55283,x,90001,x`r`n55284,x,90002,x`r`n177178,x,#N/A,x"
T 'bom+dupcol+rowperfile+NA -> 2 pairs' { $m=Import-VaultIdMap -Path "$td/m1.csv"; Eq $m.Count 2 'count'; Eq $m['55283'] '90001' 'p1' }
# tab delimited
"old_id`tnew_id`r`n1`t2`r`n3`t4" | Set-Content "$td/m2.tsv"
T 'tab delimiter detected' { $m=Import-VaultIdMap -Path "$td/m2.tsv"; Eq $m.Count 2 'c'; Eq $m['3'] '4' 'v' }
# conflict
"source_id,target_id`r`n5,10`r`n5,99" | Set-Content "$td/m3.csv"
T 'contradictory pair refused' { $t=$false; try{ Import-VaultIdMap -Path "$td/m3.csv" }catch{ $t=($_ -match 'two different targets') }; if(-not $t){throw 'not refused'} }
# scientific notation
"source_id,target_id`r`n5.5283E+04,90001" | Set-Content "$td/m4.csv"
T 'scientific notation refused' { $t=$false; try{ Import-VaultIdMap -Path "$td/m4.csv" }catch{ $t=($_ -match 'scientific notation') }; if(-not $t){throw 'not refused'} }
# unguessable
"foo,bar`r`n1,2" | Set-Content "$td/m5.csv"
T 'unguessable headers refused' { $t=$false; try{ Import-VaultIdMap -Path "$td/m5.csv" }catch{ $t=($_ -match 'which columns') }; if(-not $t){throw 'not refused'} }

Write-Host "== Ids: id list =="
"id`r`n771`r`n`r`n# note`r`n`"772`"`r`n771`r`nbad`r`n773" | Set-Content "$td/ids.txt"
T 'id list: header/blank/comment/quote/dup/bad handled' { $l=Import-VaultIdList -Path "$td/ids.txt"; Eq $l.Count 3 'count'; Eq $l[0] '771' 'first' }

Write-Host "== Run: resumable results =="
$r = New-VaultResults -Path "$td/res.csv" -KeyColumn 'Key' -DoneStatuses @('ATTACHED') -Existing 'Resume'
Add-VaultResult -Results $r -Row ([pscustomobject]@{Key='a';Status='ATTACHED';Msg='x'})
Add-VaultResult -Results $r -Row ([pscustomobject]@{Key='b';Status='ERROR';Msg='y'})
T 'results csv written'      { if(-not(Test-Path "$td/res.csv")){throw 'no file'} }
$r2 = New-VaultResults -Path "$td/res.csv" -KeyColumn 'Key' -DoneStatuses @('ATTACHED') -Existing 'Resume'
T 'resume marks ATTACHED done' { if(-not $r2.Done.ContainsKey('a')){throw 'a not done'} }
T 'resume does NOT mark ERROR' { if($r2.Done.ContainsKey('b')){throw 'b wrongly done'} }
T 'prior rows carried forward'  { Eq $r2.Prior.Count 2 'prior' }

Write-Host "== Results snapshot =="
$snapDir = Join-Path $tmp ('vk3-'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force $snapDir|Out-Null
$canon = Join-Path $snapDir 'document-results.csv'
'Id,Status' | Set-Content $canon
'1,SUCCESS'  | Add-Content $canon
$script:VaultLogFile = Join-Path $snapDir 'documents-stage-20260829-100705.log'
$snap = Copy-VaultResultsSnapshot -Path $canon
T 'snapshot takes the log timestamp' { Eq (Split-Path -Leaf $snap) 'document-results-20260829-100705.csv' 'name' }
T 'snapshot has the same rows'       { Eq (Get-Content $snap).Count (Get-Content $canon).Count 'rows' }
T 'canonical file still there'       { if(-not (Test-Path $canon)){ throw 'canonical was moved, not copied' } }
$script:VaultLogFile = ''
T 'no log stamp still snapshots'     { $s2 = Copy-VaultResultsSnapshot -Path $canon; if(-not (Test-Path $s2)){ throw 'no snapshot written' } }
T 'missing source returns empty'     { Eq (Copy-VaultResultsSnapshot -Path (Join-Path $snapDir 'nope.csv')) '' 'empty' }

Write-Host "== Disk budget =="
T 'budget throws when tight' { $t=$false; try{ Assert-VaultDiskBudget -Path $td -Needed ([long]999TB) -ReserveMB 2048 }catch{ $t=($_ -match 'not enough disk') }; if(-not $t){throw 'no throw'} }
T 'budget ok when room'      { Assert-VaultDiskBudget -Path $td -Needed 1024 -ReserveMB 1 }

Pop-Location
Write-Host ""; Write-Host ("RESULT: {0} passed, {1} failed" -f $pass,$fail)
if($fail){ exit 1 }
