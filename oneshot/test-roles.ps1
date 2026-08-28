# Exercise the parts of veeva-roles.ps1 that do not need a vault.
# Loads only the function definitions (everything above the "Run" banner).

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Both boundaries are found by pattern, never by line number: this file would otherwise
# start silently testing the wrong half of the script the first time a comment was added
# to the header.
$src   = Join-Path $PSScriptRoot 'veeva-roles.ps1'
$lines = Get-Content -LiteralPath $src
$start = ($lines | Select-String -Pattern '^#  Small things everything else uses$' | Select-Object -First 1).LineNumber
$cut   = ($lines | Select-String -Pattern '^#  Run$' | Select-Object -First 1).LineNumber
if (-not $start -or -not $cut) { throw 'Could not find the section banners in veeva-roles.ps1' }
$body  = ($lines[($start)..($cut - 3)]) -join "`n"
Invoke-Expression $body

$Fresh = $false
$pass = 0; $fail = 0
function ok  { param($m) Write-Host "  PASS  $m" -ForegroundColor Green; $script:pass++ }
function bad { param($m) Write-Host "  FAIL  $m" -ForegroundColor Red;   $script:fail++ }
function eq  { param($m, $a, $b) if ("$a" -eq "$b") { ok $m } else { bad "$m  (got '$a', want '$b')" } }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("roles-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

Write-Host "`n== ConvertTo-Key folds labels and API names onto one spelling =="
eq 'label -> key'  (ConvertTo-Key 'Business Administrators') 'businessadministrators'
eq 'name  -> key'  (ConvertTo-Key 'label_authors__c')        'labelauthorsc'
eq 'role label'    (ConvertTo-Key 'Editors')                 'editors'
eq 'empty'         (ConvertTo-Key '')                        ''

Write-Host "`n== Import-TargetIds: BOM, tabs, duplicate headers, #N/A, repeats =="
$mapPath = Join-Path $tmp 'map.csv'
$rows = @(
  "Source (old) Document ID`tCreated By`tCreated By`tNew Document ID",
  "1001`ta`tb`t5001",
  "1001`ta`tb`t5001",          # repeated row per file - expected
  "1002`ta`tb`t#N/A",          # failed lookup - skipped and named
  "1003`ta`tb`t5003",
  "1004`ta`tb`t5001"           # two sources, same target - deduped to one document
)
[IO.File]::WriteAllText($mapPath, ($rows -join "`r`n"), (New-Object Text.UTF8Encoding $true))
$docs = Import-TargetIds -Path $mapPath
eq 'documents found'  $docs.Count 2
eq 'first target'     $docs[0].TargetId '5001'
eq 'source carried'   $docs[0].SourceId '1001'
eq 'targets'          (($docs | ForEach-Object { $_.TargetId }) -join ',') '5001,5003'

Write-Host "`n== Import-TargetIds refuses ids Excel has already destroyed =="
$sci = Join-Path $tmp 'sci.csv'
Set-Content -LiteralPath $sci -Value @('old id,new id', '1001,5.5283E+04') -Encoding UTF8
try { [void](Import-TargetIds -Path $sci); bad 'scientific notation not refused' }
catch { if ("$_" -match 'scientific notation') { ok 'scientific notation refused' } else { bad "wrong error: $_" } }

Write-Host "`n== Import-DefaultsTable resolves the labels from the Admin screen =="
$dir = [pscustomobject]@{
  ById = @{
    'group:11' = 'Business Administrators'; 'group:12' = 'Label Authors'
    'group:13' = 'Label Editors';           'group:14' = 'Regulatory Users'
    'group:15' = 'Submission Managers';     'group:16' = 'Document Users'
    'user:99'  = 'ally@veepharm.com'
  }
  ByName = @{
    'group:businessadministrators' = '11'; 'group:labelauthors'      = '12'
    'group:labeleditors'           = '13'; 'group:regulatoryusers'   = '14'
    'group:submissionmanagers'     = '15'; 'group:documentusers'     = '16'
    'group:labelauthorsc'          = '12'
    'user:allyveepharmcom'         = '99'
  }
}
$defPath = Join-Path $tmp 'defaults.csv'
Set-Content -LiteralPath $defPath -Encoding UTF8 -Value @(
  'role,groups',
  'editor__v,"Business Administrators,Label Authors,Label Editors"',
  'viewer__v,"Regulatory Users,Submission Managers"',
  'consumer__v,"Document Users"'
)
$table = Import-DefaultsTable -Path $defPath -Directory $dir
eq 'rules parsed'      $table.Count 3
eq 'editor groups'     (($table | Where-Object { $_.RoleKey -eq 'editorv' }).Groups -join ',') '11,12,13'
eq 'viewer groups'     (($table | Where-Object { $_.RoleKey -eq 'viewerv' }).Groups -join ',') '14,15'
eq 'no subtype set'    (($table | Where-Object { $_.RoleKey -eq 'editorv' }).Subtype) ''

Write-Host "`n== a name that matches nothing stops the run rather than silently shrinking a role =="
$badDef = Join-Path $tmp 'bad-defaults.csv'
Set-Content -LiteralPath $badDef -Encoding UTF8 -Value @('role,groups', 'editor__v,"Buisness Administrators"')
try { [void](Import-DefaultsTable -Path $badDef -Directory $dir); bad 'unknown group not refused' }
catch { if ("$_" -match 'match no user or group') { ok 'unknown group refused, and named' } else { bad "wrong error: $_" } }

Write-Host "`n== Get-DesiredForRole: Vault's own defaults, and the table =="
$roleRec = [pscustomobject]@{
  name = 'editor__v'; label = 'Editors'
  assignedUsers = @(); assignedGroups = @(11)
  defaultUsers = @(99); defaultGroups = @(11, 12)
}
$fromVault = Get-DesiredForRole -From 'Document' -RoleRecord $roleRec -Table $null -Rules $null -Subtype '' -DocumentInfo $null
eq 'vault users'   ($fromVault.Users  -join ',') '99'
eq 'vault groups'  ($fromVault.Groups -join ',') '11,12'

$fromTable = Get-DesiredForRole -From 'Table' -RoleRecord $roleRec -Table $table -Rules $null -Subtype '' -DocumentInfo $null
eq 'table groups'  ($fromTable.Groups -join ',') '11,12,13'
eq 'table users'   ($fromTable.Users  -join ',') ''

# matched by UI label, not just API name
$byLabel = Get-DesiredForRole -From 'Table' -RoleRecord ([pscustomobject]@{ name = 'x__c'; label = 'Editor__v' }) -Table $table -Rules $null -Subtype '' -DocumentInfo $null
eq 'matched on label' ($byLabel.Groups -join ',') '11,12,13'

Write-Host "`n== a subtype-bearing rule only applies to its own subtype =="
$subDef = Join-Path $tmp 'sub-defaults.csv'
Set-Content -LiteralPath $subDef -Encoding UTF8 -Value @(
  'subtype,role,groups',
  'Administrative Information,editor__v,"Business Administrators"',
  'Labeling,editor__v,"Label Editors"'
)
$subTable = Import-DefaultsTable -Path $subDef -Directory $dir
$a = Get-DesiredForRole -From 'Table' -RoleRecord $roleRec -Table $subTable -Rules $null -DocumentInfo $null -Subtype (ConvertTo-Key 'Administrative Information')
$b = Get-DesiredForRole -From 'Table' -RoleRecord $roleRec -Table $subTable -Rules $null -DocumentInfo $null -Subtype (ConvertTo-Key 'Labeling')
eq 'admin subtype'    ($a.Groups -join ',') '11'
eq 'labeling subtype' ($b.Groups -join ',') '13'

Write-Host "`n== Get-RoleAssignmentRule keeps the override rule out of the default rule =="
function Invoke-Api {
  param($VaultHost, $ApiVersion, $Method, $Path, $Body, $ContentType, $TimeoutSec, $MaxRetries)
  return ([pscustomobject]@{
    responseStatus = 'SUCCESS'
    data = @(
      # the default rule
      [pscustomobject]@{
        lifecycle__v = 'general_lifecycle__c'; role__v = 'editor__v'
        allowed_default_users__v  = @('ally@veepharm.com')
        allowed_default_groups__v = @('Business Administrators')
      },
      # an override rule for the same role - must NOT be merged into the default
      [pscustomobject]@{
        lifecycle__v = 'general_lifecycle__c'; role__v = 'editor__v'
        'product__v' = '0PR0011001'; 'country__v' = '0CR0022002'
        allowed_default_users__v  = @()
        allowed_default_groups__v = @('Label Editors')
      }
    )
  })
}
$ctxR  = [pscustomobject]@{ VaultHost = 'x.veevavault.com'; Api = 'v26.2' }
$rules = Get-RoleAssignmentRule -Context $ctxR -Directory $dir
$key   = "$(ConvertTo-Key 'general_lifecycle__c')|$(ConvertTo-Key 'editor__v')"
eq 'one lifecycle/role entry' $rules.Count 1
eq 'default users'            ($rules[$key].Users  -join ',') '99'
eq 'default groups only'      ($rules[$key].Groups -join ',') '11'
eq 'override kept apart'      $rules[$key].Overrides.Count 1
eq 'has a default row'        $rules[$key].HasDefault $true

Write-Host "`n== Select-RuleForDocument picks the override only when the document matches =="
$noMatch = Select-RuleForDocument -Rule $rules[$key] -Conditions @{ product__v = @('0PR9999999'); country__v = @() }
eq 'falls back to default'   ($noMatch.Groups -join ',') '11'
eq 'says which'              $noMatch.Which 'DEFAULT'

$match = Select-RuleForDocument -Rule $rules[$key] -Conditions @{ product__v = @('0PR0011001'); country__v = @('0CR0022002') }
eq 'override wins'           ($match.Groups -join ',') '13'
eq 'says which'              $match.Which 'OVERRIDE'
eq 'names the condition'     ($match.Message -match 'product__v=0PR0011001') $true

# a partial match must NOT fire: the override names product AND country
$partial = Select-RuleForDocument -Rule $rules[$key] -Conditions @{ product__v = @('0PR0011001'); country__v = @() }
eq 'partial match ignored'   ($partial.Groups -join ',') '11'

Write-Host "`n== the more specific override wins, and a genuine tie is refused =="
$twoOv = [pscustomobject]@{
  Lifecycle = 'l'; Role = 'r'; Users = @(); Groups = @('11'); HasDefault = $true
  Overrides = @(
    [pscustomobject]@{ Conditions = @{ product__v = 'P1' };                     Users = @(); Groups = @('12') },
    [pscustomobject]@{ Conditions = @{ product__v = 'P1'; country__v = 'C1' };  Users = @(); Groups = @('13') }
  )
}
$spec = Select-RuleForDocument -Rule $twoOv -Conditions @{ product__v = @('P1'); country__v = @('C1') }
eq 'two conditions beat one' ($spec.Groups -join ',') '13'

$tie = [pscustomobject]@{
  Lifecycle = 'l'; Role = 'r'; Users = @(); Groups = @('11'); HasDefault = $true
  Overrides = @(
    [pscustomobject]@{ Conditions = @{ product__v = 'P1' }; Users = @(); Groups = @('12') },
    [pscustomobject]@{ Conditions = @{ country__v = 'C1' }; Users = @(); Groups = @('13') }
  )
}
$tied = Select-RuleForDocument -Rule $tie -Conditions @{ product__v = @('P1'); country__v = @('C1') }
eq 'tie refused'             $tied.Which 'AMBIGUOUS_OVERRIDE'
eq 'tie assigns nobody'      ($tied.Groups -join ',') ''

Write-Host "`n== an unreadable document resolves to nobody, never to the default =="
$roleRec2 = [pscustomobject]@{ name = 'editor__v'; label = 'Editors' }
$unread = Get-DesiredForRole -From 'Lifecycle' -RoleRecord $roleRec2 -Table $null -Rules $rules -Subtype '' `
            -DocumentInfo ([pscustomobject]@{ Lifecycle = ''; Conditions = @{}; Read = $false })
eq 'unreadable -> nobody'    ($unread.Groups -join ',') ''
eq 'unreadable -> flagged'   $unread.Which 'DOCUMENT_UNREADABLE'

$noRule = Get-DesiredForRole -From 'Lifecycle' -RoleRecord ([pscustomobject]@{ name = 'nosuch__c'; label = 'X' }) `
            -Table $null -Rules $rules -Subtype '' `
            -DocumentInfo ([pscustomobject]@{ Lifecycle = 'general_lifecycle__c'; Conditions = @{}; Read = $true })
eq 'role with no rule is quiet' $noRule.Which 'NO_RULE_FOR_ROLE'

Write-Host "`n== the batch CSV Vault receives =="
$captured = $null
function Invoke-Api {
  param($VaultHost, $ApiVersion, $Method, $Path, $Body, $ContentType, $TimeoutSec, $MaxRetries)
  $script:captured = [pscustomobject]@{
    Path = $Path; ContentType = $ContentType
    Csv  = [Text.Encoding]::UTF8.GetString($Body)
  }
  return ([pscustomobject]@{
    responseStatus = 'SUCCESS'
    data = @(
      [pscustomobject]@{ responseStatus = 'SUCCESS'; id = 771 },
      [pscustomobject]@{ responseStatus = 'FAILURE'; id = 772
                         errors = @([pscustomobject]@{ type = 'INVALID_DATA'; message = 'nope' }) }
    )
  })
}
$ctx = [pscustomobject]@{ VaultHost = 'x.veevavault.com'; Api = 'v26.2' }
$items = @(
  [pscustomobject]@{ DocId = '771'; Cells = [ordered]@{ 'editor__v.groups' = @('11','12'); 'viewer__v.groups' = @('14') } },
  [pscustomobject]@{ DocId = '772'; Cells = [ordered]@{ 'editor__v.groups' = @('13');      'viewer__v.groups' = @('15') } }
)
$byDoc = Send-RoleBatch -Context $ctx -Items $items -Columns @('editor__v.groups', 'viewer__v.groups')

eq 'endpoint'      $captured.Path '/objects/documents/roles/batch'
eq 'content type'  $captured.ContentType 'text/csv; charset=UTF-8'
$csvLines = @($captured.Csv -split "`r?`n" | Where-Object { $_ })
eq 'header'        $csvLines[0] '"id","editor__v.groups","viewer__v.groups"'
eq 'row 771'       $csvLines[1] '"771","11,12","14"'
eq 'row 772'       $csvLines[2] '"772","13","15"'
eq 'success read'  $byDoc['771'].Ok $true
eq 'failure read'  $byDoc['772'].Ok $false
eq 'failure msg'   $byDoc['772'].Message 'INVALID_DATA: nope'

Write-Host "`n== a comma inside a value stays inside its cell =="
$csvField = ConvertTo-CsvField 'a,b"c'
eq 'quoted and doubled' $csvField '"a,b""c"'

Write-Host "`n== Get-DocumentsByQuery pages, dedupes, and only ever selects ids =="
$script:qCalls = New-Object System.Collections.ArrayList
function Invoke-Api {
  param($VaultHost, $ApiVersion, $Method, $Path, $Body, $ContentType, $TimeoutSec, $MaxRetries)
  [void]$script:qCalls.Add([pscustomobject]@{ Method = $Method; Path = $Path; Body = $Body })
  if ($script:qCalls.Count -eq 1) {
    return ([pscustomobject]@{
      responseStatus = 'SUCCESS'
      data = @([pscustomobject]@{ id = 771 }, [pscustomobject]@{ id = 772 })
      responseDetails = [pscustomobject]@{ next_page = '/api/v26.2/query/abc?offset=2' }
    })
  }
  return ([pscustomobject]@{
    responseStatus = 'SUCCESS'
    # 772 repeated across the page boundary - it must not become two documents
    data = @([pscustomobject]@{ id = 772 }, [pscustomobject]@{ id = 773 })
    responseDetails = [pscustomobject]@{}
  })
}
$ctxQ = [pscustomobject]@{ VaultHost = 'x.veevavault.com'; Api = 'v26.2' }
$found = Get-DocumentsByQuery -Context $ctxQ -Where "type__v = 'Administrative Information'"
eq 'paged and deduped'  (($found | ForEach-Object { $_.TargetId }) -join ',') '771,772,773'
eq 'no source id'       $found[0].SourceId ''
eq 'first call posts'   $script:qCalls[0].Method 'POST'
eq 'wrapped as SELECT'  ($script:qCalls[0].Body -match 'SELECT%20id%20FROM%20documents%20WHERE') $true
eq 'second call gets'   $script:qCalls[1].Method 'GET'
eq 'follows next_page'  $script:qCalls[1].Path '/api/v26.2/query/abc?offset=2'

$script:qCalls.Clear()
[void](Get-DocumentsByQuery -Context $ctxQ -Where "SELECT id FROM documents WHERE id > 5")
eq 'a full SELECT is left alone' ($script:qCalls[0].Body -match '^q=SELECT%20id%20FROM%20documents%20WHERE%20id%20%3E%205$') $true

Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Host ''
Write-Host "$pass passed, $fail failed" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
if ($fail) { exit 1 }
