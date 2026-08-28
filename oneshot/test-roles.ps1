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
$key   = "$(ConvertTo-NameKey 'general_lifecycle__c')|$(ConvertTo-NameKey 'editor__v')"
eq 'one lifecycle/role entry' $rules.Count 1
eq 'default users'            ($rules[$key].Users  -join ',') '99'
eq 'default groups only'      ($rules[$key].Groups -join ',') '11'
eq 'override kept apart'      $rules[$key].Overrides.Count 1
eq 'has a default row'        $rules[$key].HasDefault $true

Write-Host "`n== a document's lifecycle LABEL joins the rules' lifecycle NAME =="
# From a real run: GET /objects/documents/{id} reported lifecycle__v as "General
# Lifecycle" while /configuration/role_assignment_rule reported "general_lifecycle__c".
# Keyed literally, all 76 rules matched nothing, every role came back "no rule", and
# -DesiredFrom Lifecycle would have read the whole vault and assigned nobody.
eq 'label folds'            (ConvertTo-NameKey 'General Lifecycle')     'generallifecycle'
eq 'name folds the same'    (ConvertTo-NameKey 'general_lifecycle__c')  'generallifecycle'
eq 'role label folds'       (ConvertTo-NameKey 'Technical Editor')      'technicaleditor'
eq 'role name folds same'   (ConvertTo-NameKey 'technical_editor__c')   'technicaleditor'
eq 'only a trailing suffix' (ConvertTo-NameKey 'a__c_b__v')             'acb'

$byLabelLc = Get-DesiredForRole -From 'Lifecycle' `
    -RoleRecord ([pscustomobject]@{ name = 'editor__v'; label = 'Editors' }) `
    -Table $null -Rules $rules -Subtype '' `
    -DocumentInfo ([pscustomobject]@{ Lifecycle = 'General Lifecycle'; Conditions = @{}; Read = $true })
eq 'rule found via label'   $byLabelLc.Which 'DEFAULT'
eq 'and it carries people'  ($byLabelLc.Groups -join ',') '11'

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

Write-Host "`n== Get-Directory pages users by start, and never asks for a limit Vault refuses =="
# The live vault rejected limit=1000 with INVALID_DATA, "The 'limit' parameter must be
# < 500", and this endpoint has no responseDetails.next_page - it pages by limit/start.
# Reading it the VQL way stopped at the first 200 users in silence.
$script:dCalls = New-Object System.Collections.ArrayList
function Invoke-Api {
  param($VaultHost, $ApiVersion, $Method, $Path, $Body, $ContentType, $TimeoutSec, $MaxRetries)
  [void]$script:dCalls.Add($Path)
  if ($Path -like '/objects/groups*') {
    return ([pscustomobject]@{ responseStatus = 'SUCCESS'
      groups = @([pscustomobject]@{ group = [pscustomobject]@{ id = 11; name__v = 'biz_admin__c'; label__v = 'Business Administrators' } }) })
  }
  # 250 users: a full page of 200, then a short page of 50.
  $start = 0
  if ($Path -match 'start=(\d+)') { $start = [int]$Matches[1] }
  $n = if ($start -eq 0) { 200 } elseif ($start -eq 200) { 50 } else { 0 }
  $users = @(0..([math]::Max($n - 1, 0)) | Where-Object { $n -gt 0 } | ForEach-Object {
    $id = $start + $_ + 1
    [pscustomobject]@{ user = [pscustomobject]@{ id = $id; user_name__v = "u$id@x.com" } }
  })
  return ([pscustomobject]@{ responseStatus = 'SUCCESS'; users = $users })
}
$script:Directory = $null
$ctxD = [pscustomobject]@{ VaultHost = 'x.veevavault.com'; Api = 'v26.2' }
$built = Get-Directory -Context $ctxD

$userCalls = @($script:dCalls | Where-Object { $_ -like '/objects/users*' })
eq 'both user pages read'  $userCalls.Count 2
eq 'first page start=0'    ($userCalls[0] -match 'start=0') $true
eq 'second page start=200' ($userCalls[1] -match 'start=200') $true
eq 'limit under 500'       (@($userCalls | Where-Object { $_ -match 'limit=(\d+)' -and [int]$Matches[1] -ge 500 }).Count) 0
eq 'all 250 users kept'    (@($built.ById.Keys | Where-Object { $_ -like 'user:*' }).Count) 250
eq 'a page-2 user resolves' (Get-DisplayName -Directory $built -Kind 'user' -Id '250') 'u250@x.com'
eq 'groups need no paging' (@($script:dCalls | Where-Object { $_ -like '/objects/groups*' }).Count) 1
eq 'group label indexed'   (Resolve-NameToId -Directory $built -Kind 'group' -Name 'Business Administrators') '11'
eq 'group api name too'    (Resolve-NameToId -Directory $built -Kind 'group' -Name 'biz_admin__c') '11'

Write-Host "`n== a users endpoint that ignores start stops instead of spinning =="
$script:dCalls.Clear()
function Invoke-Api {
  param($VaultHost, $ApiVersion, $Method, $Path, $Body, $ContentType, $TimeoutSec, $MaxRetries)
  [void]$script:dCalls.Add($Path)
  if ($Path -like '/objects/groups*') { return ([pscustomobject]@{ responseStatus = 'SUCCESS'; groups = @() }) }
  # Always hands back the same full page, whatever start says.
  $users = @(1..200 | ForEach-Object { [pscustomobject]@{ user = [pscustomobject]@{ id = $_; user_name__v = "u$_@x.com" } } })
  return ([pscustomobject]@{ responseStatus = 'SUCCESS'; users = $users })
}
$script:Directory = $null
$built2 = Get-Directory -Context $ctxD
eq 'stops on no new entries' (@($script:dCalls | Where-Object { $_ -like '/objects/users*' }).Count) 2
eq 'kept the one page'       (@($built2.ById.Keys | Where-Object { $_ -like 'user:*' }).Count) 200
$script:Directory = $null

Write-Host "`n== group membership is captured, so redundant direct assignments can be counted =="
$script:dCalls = New-Object System.Collections.ArrayList
function Invoke-Api {
  param($VaultHost, $ApiVersion, $Method, $Path, $Body, $ContentType, $TimeoutSec, $MaxRetries)
  [void]$script:dCalls.Add($Path)
  if ($Path -like '/objects/groups*') {
    return ([pscustomobject]@{ responseStatus = 'SUCCESS'; groups = @(
      [pscustomobject]@{ group = [pscustomobject]@{ id = 11; label__v = 'Document Users'; members__v = @(101, 102, 103) } },
      [pscustomobject]@{ group = [pscustomobject]@{ id = 12; label__v = 'Empty Group' } }
    ) })
  }
  return ([pscustomobject]@{ responseStatus = 'SUCCESS'; users = @() })
}
$script:Directory = $null
$withMembers = Get-Directory -Context ([pscustomobject]@{ VaultHost = 'x'; Api = 'v26.2' })
eq 'members captured'      ($withMembers.Members['11'] -join ',') '101,102,103'
eq 'no members is empty'   ($withMembers.Members['12'] -join ',') ''
eq 'label still indexed'   (Resolve-NameToId -Directory $withMembers -Kind 'group' -Name 'Document Users') '11'
$script:Directory = $null

Write-Host "`n== document type default security is read out of the MDL component =="
# Admin > Document Types > (subtype) > Security > "Default Settings for New Documents"
# is role_defaulting_editors / _viewers / _consumers on the Doctype MDL component. A real
# vault reported NOTHING for editor__v on the roles endpoint while that screen listed
# three groups, so this is the only source that has them.
$mdlDir = [pscustomobject]@{
  ById = @{}; Members = @{}
  ByName = @{
    'group:businessadministrators' = '11'; 'group:labelauthors'    = '12'
    'group:labeleditors'           = '13'; 'group:regulatoryusers' = '14'
    'group:submissionmanagers'     = '15'; 'group:documentusers'   = '16'
    'user:janeexamplecom'          = '99'
  }
}
$mdlText = [pscustomobject]@{ raw = @"
Doctype base_document__v.administrative_information__c (
  label('Administrative Information'),
  role_defaulting_editors('group:Group.business_administrators__c', 'group:Group.label_authors__c', 'group:Group.label_editors__c'),
  role_defaulting_viewers('group:Group.regulatory_users__c', 'group:Group.submission_managers__c'),
  role_defaulting_consumers('group:Group.document_users__c', 'user:jane@example.com')
);
"@ }
eq 'editors from MDL text'  ((Get-MdlAttributeValue -Response $mdlText -Attribute 'role_defaulting_editors') -join '|') 'group:Group.business_administrators__c|group:Group.label_authors__c|group:Group.label_editors__c'
eq 'absent attribute empty' (@(Get-MdlAttributeValue -Response $mdlText -Attribute 'role_defaulting_nobody').Count) 0

$mdlJson = [pscustomobject]@{ data = [pscustomobject]@{
    role_defaulting_viewers = @('group:Group.regulatory_users__c', 'group:Group.submission_managers__c') } }
eq 'same value from JSON'   ((Get-MdlAttributeValue -Response $mdlJson -Attribute 'role_defaulting_viewers') -join '|') 'group:Group.regulatory_users__c|group:Group.submission_managers__c'

$mdlAttrs = [pscustomobject]@{ data = [pscustomobject]@{ attributes = @(
    [pscustomobject]@{ name = 'role_defaulting_consumers'; value = @('group:Group.document_users__c') }) } }
eq 'and from an attribute list' ((Get-MdlAttributeValue -Response $mdlAttrs -Attribute 'role_defaulting_consumers') -join '|') 'group:Group.document_users__c'

$parsed = ConvertFrom-MdlPrincipalList -Directory $mdlDir -Values @(
  'group:Group.business_administrators__c', 'group:Group.label_authors__c',
  'user:jane@example.com', 'group:Group.no_such_group__c')
eq 'groups resolved'        ($parsed.Groups -join ',') '11,12'
eq 'users resolved'         ($parsed.Users  -join ',') '99'
eq 'unknown named, not silent' ($parsed.Unknown.Count) 1
eq 'the Group. prefix is optional' ((ConvertFrom-MdlPrincipalList -Directory $mdlDir -Values @('group:document_users__c')).Groups -join ',') '16'

Write-Host "`n== a user in two assigned groups is counted once, not twice =="
# A real run reported "1449 of those 1430 user assignment(s) are already members of a
# group" - a subset bigger than its superset, because membership rows were counted rather
# than people. The count can never exceed the number of users offered.
$memDir = [pscustomobject]@{
  ById = @{}; ByName = @{}
  Members = @{ '11' = @('101', '102'); '12' = @('102', '103'); '13' = @() }
}
eq 'in both groups, counted once' (Get-RedundantUserCount -Directory $memDir -Groups @('11','12') -Users @('101','102','103')) 3
eq 'never exceeds the user count' (Get-RedundantUserCount -Directory $memDir -Groups @('11','12') -Users @('102')) 1
eq 'uncovered user not counted'   (Get-RedundantUserCount -Directory $memDir -Groups @('11')      -Users @('103')) 0
eq 'no groups, nothing covered'   (Get-RedundantUserCount -Directory $memDir -Groups @()          -Users @('101')) 0
eq 'no users, nothing covered'    (Get-RedundantUserCount -Directory $memDir -Groups @('11')      -Users @()) 0
eq 'unknown group is not fatal'   (Get-RedundantUserCount -Directory $memDir -Groups @('99')      -Users @('101')) 0
eq 'int ids match string ids'     (Get-RedundantUserCount -Directory $memDir -Groups @(11)        -Users @(101)) 1

Write-Host "`n== the cached vault host is offered back, newest session first =="
$script:SessionPath = Join-Path $tmp '.vault-session.json'
eq 'no file, no default' (Get-CachedVaultHost) ''

Set-Content -LiteralPath $script:SessionPath -Encoding UTF8 -Value (@{
  'old.veevavault.com' = @{ sessionId = 'a'; obtained = '2026-08-01T00:00:00Z' }
  'sb-endo-endo-rim-sbx.veevavault.com' = @{ sessionId = 'b'; obtained = '2026-08-28T12:45:00Z' }
  'nosession.veevavault.com' = @{ obtained = '2026-08-29T00:00:00Z' }
} | ConvertTo-Json -Depth 5)
eq 'newest with a session wins' (Get-CachedVaultHost) 'sb-endo-endo-rim-sbx.veevavault.com'

Set-Content -LiteralPath $script:SessionPath -Value 'not json at all' -Encoding UTF8
eq 'garbage file is not fatal' (Get-CachedVaultHost) ''
Remove-Item -LiteralPath $script:SessionPath -Force
$script:SessionPath = ''

Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Host ''
Write-Host "$pass passed, $fail failed" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
if ($fail) { exit 1 }
