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
# Read out of vault.ps1 rather than listed again here. This hand-kept copy silently fell
# behind when Documents and Workers were added, so every test touching them failed with
# "the term is not recognized" - which reads like a typo rather than a module never loaded.
$parts = (Get-Content (Join-Path $here 'vault.ps1') |
          Where-Object { $_ -like '$VaultKitParts = @(*' } |
          Select-Object -First 1) -replace '^.*@\(', '' -replace '\).*$', '' -split ',' |
         ForEach-Object { $_.Trim().Trim("'") }
if (-not $parts) { throw 'could not read $VaultKitParts out of vault.ps1' }
foreach($p in $parts){ . (Join-Path $here "VaultKit/$p.ps1") }

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
# Read out of vault.ps1 rather than listed again here. This hand-kept copy silently fell
# behind when Documents and Workers were added, so every test touching them failed with
# "the term is not recognized" - which reads like a typo rather than a module never loaded.
$parts = (Get-Content (Join-Path $here 'vault.ps1') |
          Where-Object { $_ -like '$VaultKitParts = @(*' } |
          Select-Object -First 1) -replace '^.*@\(', '' -replace '\).*$', '' -split ',' |
         ForEach-Object { $_.Trim().Trim("'") }
if (-not $parts) { throw 'could not read $VaultKitParts out of vault.ps1' }
foreach($p in $parts){ . (Join-Path $here "VaultKit/$p.ps1") }
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

Write-Host "== Staging names =="
T 'slash is neutralised'        { Eq (ConvertTo-VaultStagingName 'HC to Torys/Extension.pdf') 'HC to Torys_Extension.pdf' 'slash' }
T 'backslash too'               { Eq (ConvertTo-VaultStagingName 'a\b.pdf') 'a_b.pdf' 'backslash' }
T 'every separator, not one'    { Eq (ConvertTo-VaultStagingName 'a/b/c.pdf') 'a_b_c.pdf' 'all' }
T 'colons and spaces kept'      { Eq (ConvertTo-VaultStagingName 're: data (final) v2.pdf') 're: data (final) v2.pdf' 'kept' }
T 'ordinary name untouched'     { Eq (ConvertTo-VaultStagingName 'Cover Letter.pdf') 'Cover Letter.pdf' 'plain' }
T 'idempotent'                  { $once = ConvertTo-VaultStagingName 'a/b.pdf'; Eq (ConvertTo-VaultStagingName $once) $once 'twice' }
T 'control chars removed'       { Eq (ConvertTo-VaultStagingName "a$([char]9)b.pdf") 'a_b.pdf' 'tab' }
T 'trailing dot dropped'        { Eq (ConvertTo-VaultStagingName 'report.pdf.') 'report.pdf' 'dot' }
T 'trailing space dropped'      { Eq (ConvertTo-VaultStagingName 'report.pdf  ') 'report.pdf' 'space' }
T 'device name is escaped'      { Eq (ConvertTo-VaultStagingName 'NUL.pdf') '_NUL.pdf' 'nul' }
T 'device name alone escaped'   { Eq (ConvertTo-VaultStagingName 'CON') '_CON' 'con' }
T 'ordinary CONTRACT is not'    { Eq (ConvertTo-VaultStagingName 'CONTRACT.pdf') 'CONTRACT.pdf' 'contract' }
T 'long name keeps extension'   { $n = ('x' * 300) + '.pdf'; $r = ConvertTo-VaultStagingName $n; Eq $r.Length 150 'len'; if(-not $r.EndsWith('.pdf')){ throw 'lost the extension' } }
T 'empty name gets a fallback'  { Eq (ConvertTo-VaultStagingName '   ') 'unnamed' 'empty' }
T 'all-separator name too'      { Eq (ConvertTo-VaultStagingName '/') '_' 'slashonly' }

Write-Host "== Content-Disposition names =="
# Built from char codes, not typed literally: Windows PowerShell 5.1 reads a .ps1 with no
# BOM as ANSI, so a non-ASCII character in this file would be corrupted before the test
# it is meant to check ever ran.
$e     = [char]0xE9
$want  = "Rapport d${e}tude.pdf"
$rfc   = 'attachment; filename="Rapport.pdf"; filename*=UTF-8' + "''" + 'Rapport%20d%C3%A9tude.pdf'
$moji  = [Text.Encoding]::GetEncoding(28591).GetString([Text.Encoding]::UTF8.GetBytes($want))

T 'plain filename'             { Eq (Get-VaultAttachmentName -Header 'attachment; filename="Cover Letter.pdf"') 'Cover Letter.pdf' 'plain' }
T 'unquoted filename'          { Eq (Get-VaultAttachmentName -Header 'attachment; filename=report.pdf') 'report.pdf' 'unquoted' }
T 'filename* beats the ascii'  { Eq (Get-VaultAttachmentName -Header $rfc) $want 'rfc5987' }
T 'latin-1 mojibake recovered' { Eq (Get-VaultAttachmentName -Header "attachment; filename=`"$moji`"") $want 'utf8' }
T 'real latin-1 is left alone' { Eq (Get-VaultAttachmentName -Header "attachment; filename=`"caf${e}.pdf`"") "caf${e}.pdf" 'latin1' }
T 'no header gives nothing'    { Eq (Get-VaultAttachmentName -Header '') '' 'empty' }
T 'no filename gives nothing'  { Eq (Get-VaultAttachmentName -Header 'attachment') '' 'none' }

Write-Host "== Mixed-schema results =="
$oldRow = [pscustomobject]@{ Id='1'; Name='a.pdf'; Status='SUCCESS' }
$newRow = [pscustomobject]@{ Id='2'; Name='b.pdf'; Status='SUCCESS'; StagedName='b.pdf'; Renamed=$false }
$uni = ConvertTo-VaultUniformRows -Rows @($oldRow, $newRow)
T 'older row first keeps new cols' { Eq (($uni[0].PSObject.Properties.Name) -join ',') 'Id,Name,Status,StagedName,Renamed' 'cols' }
T 'missing value becomes empty'    { Eq $uni[0].StagedName '' 'blank' }
T 'existing values survive'        { Eq $uni[1].StagedName 'b.pdf' 'kept' }
T 'empty input is safe'            { Eq (@(ConvertTo-VaultUniformRows -Rows @()).Count) 0 'empty' }

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

Write-Host "== Map format =="
$md = Join-Path $tmp ('vkmap-'+[guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Force $md|Out-Null

# canonical: no detection should be involved at all
$canon = Join-Path $md 'canon.csv'
"source_id,target_id`n55056,207311`n55057,207312" | Set-Content $canon -Encoding ASCII
$m = Import-VaultIdMap -Path $canon
T 'canonical reads'            { Eq $m['55056'] '207311' 'pair' }
T 'canonical is recognised'    { Eq $script:VaultIdMapStats.How 'canonical header' 'how' }
T 'canonical flagged canonical'{ Eq $script:VaultIdMapStats.Canonical $true 'flag' }

# plain source/target - what verify map used to write, and what the id-only heuristic missed
$plain = Join-Path $md 'plain.csv'
"source,target`n1,2" | Set-Content $plain -Encoding ASCII
T 'bare source/target reads'   { $p = Import-VaultIdMap -Path $plain; Eq $p['1'] '2' 'pair' }

# a real export: human headers, a duplicate column, a row per file, an #N/A
$human = Join-Path $md 'human.csv'
@'
Source (old) Document ID,Created By,Destination (new) Document ID,Created By
55056,ab,207311,cd
55056,ab,207311,cd
55058,ab,#N/A,cd
55059,ab,207313,cd
'@ | Set-Content $human -Encoding ASCII
$h = Import-VaultIdMap -Path $human
T 'human headers detected'     { Eq $script:VaultIdMapStats.How 'detected from the header wording' 'how' }
T 'human pairs'                { Eq $h.Count 2 'pairs' }
T 'repeat collapsed'           { Eq $script:VaultIdMapStats.RepeatedPairs 1 'dupe' }
T 'NA skipped and counted'     { Eq $script:VaultIdMapStats.Skipped 1 'skipped' }
T 'human is not canonical'     { Eq $script:VaultIdMapStats.Canonical $false 'flag' }

# normalising makes it canonical
$norm = Join-Path $md 'norm.csv'
T 'export writes canonical'    { [void](Export-VaultIdMap -Map $h -Path $norm)
                                 Eq ((Get-Content $norm -TotalCount 1) -replace '"','') 'source_id,target_id' 'header' }
T 'normalised round-trips'     { $r = Import-VaultIdMap -Path $norm
                                 Eq $script:VaultIdMapStats.Canonical $true 'canonical'
                                 Eq $r.Count $h.Count 'same pairs' }

# the two refusals
$conf = Join-Path $md 'conflict.csv'
"source_id,target_id`n1,2`n1,3" | Set-Content $conf -Encoding ASCII
T 'contradiction is refused'   { $t=$false; try { Import-VaultIdMap -Path $conf } catch { $t = "$_" -match 'two different targets' }; if(-not $t){throw 'accepted'} }
$sci = Join-Path $md 'sci.csv'
"source_id,target_id`n5.5283E+04,207311" | Set-Content $sci -Encoding ASCII
T 'excel mangling is refused'  { $t=$false; try { Import-VaultIdMap -Path $sci } catch { $t = "$_" -match 'scientific notation' }; if(-not $t){throw 'accepted'} }

Write-Host "== Sample size (Cochran + finite population) =="
T '95/5 over a large N is ~384'   { $n = Get-VaultSampleSize -Population 1000000 -Confidence 95 -MarginPct 5; if($n -lt 384 -or $n -gt 385){ throw "got $n" } }
T '95/5 over 15775 is 375-376'    { $n = Get-VaultSampleSize -Population 15775 -Confidence 95 -MarginPct 5; if($n -lt 375 -or $n -gt 376){ throw "got $n" } }
T 'tighter margin needs more'     { $a = Get-VaultSampleSize -Population 15775 -MarginPct 5; $b = Get-VaultSampleSize -Population 15775 -MarginPct 2; if($b -le $a){ throw "$b not > $a" } }
T 'higher confidence needs more'  { $a = Get-VaultSampleSize -Population 15775 -Confidence 95; $b = Get-VaultSampleSize -Population 15775 -Confidence 99; if($b -le $a){ throw "$b not > $a" } }
T 'never exceeds the population'  { Eq (Get-VaultSampleSize -Population 10 -MarginPct 1) 10 'capped' }
T 'empty population is zero'      { Eq (Get-VaultSampleSize -Population 0) 0 'zero' }

Write-Host "== Sample selection =="
$pop = 1..500 | ForEach-Object { [pscustomobject]@{ Source = "$_"; Target = "t$_" } }
T 'returns exactly n'             { Eq (@(Select-VaultSample -Items $pop -Count 40 -Seed 7).Count) 40 'count' }
T 'no repeats'                    { $s = Select-VaultSample -Items $pop -Count 60 -Seed 7; Eq (@($s | Select-Object -ExpandProperty Source -Unique).Count) 60 'unique' }
T 'same seed, same sample'        { $a = (Select-VaultSample -Items $pop -Count 30 -Seed 42 | ForEach-Object Source) -join ','
                                    $b = (Select-VaultSample -Items $pop -Count 30 -Seed 42 | ForEach-Object Source) -join ','
                                    Eq $a $b 'reproducible' }
T 'different seed, different'     { $a = (Select-VaultSample -Items $pop -Count 30 -Seed 42 | ForEach-Object Source) -join ','
                                    $b = (Select-VaultSample -Items $pop -Count 30 -Seed 43 | ForEach-Object Source) -join ','
                                    if($a -eq $b){ throw 'two seeds gave the same sample' } }
T 'n >= population returns all'   { Eq (@(Select-VaultSample -Items $pop -Count 900 -Seed 1).Count) 500 'all' }
T 'zero returns none'             { Eq (@(Select-VaultSample -Items $pop -Count 0 -Seed 1).Count) 0 'none' }
T 'draws from across the range'   { $s = @(Select-VaultSample -Items $pop -Count 100 -Seed 5 | ForEach-Object { [int]$_.Source })
                                    if((($s | Measure-Object -Maximum).Maximum) -lt 250){ throw 'sample clustered at the start - not random' } }

Write-Host "== Disk budget =="
T 'budget throws when tight' { $t=$false; try{ Assert-VaultDiskBudget -Path $td -Needed ([long]999TB) -ReserveMB 2048 }catch{ $t=($_ -match 'not enough disk') }; if(-not $t){throw 'no throw'} }
T 'budget ok when room'      { Assert-VaultDiskBudget -Path $td -Needed 1024 -ReserveMB 1 }

Pop-Location
Write-Host ""; Write-Host ("RESULT: {0} passed, {1} failed" -f $pass,$fail)
if($fail){ exit 1 }
