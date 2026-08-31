# Document Sharing Settings that a migration left empty.
#
# Documents created through the Vault UI get users and groups populated into their
# Sharing Settings automatically, from the lifecycle's role assignment rules and from the
# document type's "Default Settings for New Documents". Documents created through the API
# or Vault Loader do NOT - Veeva confirms this is by design. So a migrated document
# arrives with its roles empty, and something has to put them back.
#
# This is that something. For each document it reads the roles Vault reports, works out
# who the configuration says should be there, and assigns whoever is missing. It never
# removes anyone and never invents an assignment: everything it writes is something the
# configuration already names as a default.
#
# One vault, not two. This repairs the target of a migration rather than comparing two
# vaults, so it reads Context.VaultHost - the target - where the transfer reads both.
#
# Ported from veeva-roles.ps1, which carried its own copy of the logging, sessions,
# credentials, API layer and delimited-file reading. All of that is VaultKit's now, and
# the copies are gone rather than left to drift.

function ConvertTo-VaultNameKey {
    # A key that survives Vault handing back the NAME in one place and the LABEL in
    # another for the same thing.
    #
    # GET /objects/documents/{id} reports lifecycle__v as "General Lifecycle".
    # GET /configuration/role_assignment_rule reports it as "general_lifecycle__c".
    # Keyed literally those are two different lifecycles, so every rule lookup missed,
    # every role came back "no rule", and an assign run would have read every document in
    # the vault and written nothing - reporting success while doing so.
    #
    # Dropping the __c/__v/__sys suffix before folding makes both spellings converge, and
    # a label really is the name in title case in every case seen so far.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $v = $Value -replace '__(c|v|sys)$', ''
    return ($v -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}

function ConvertTo-VaultKey {
    # One spelling for every name comparison. The UI shows labels ("Label Authors"), the
    # API returns names ("label_authors__c"), and a person transcribing a screen will
    # produce either. Compare on a form that survives both.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return ($Value -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}


# ======================================================================================
#  Settings
# ======================================================================================

function Get-VaultDocumentsByQuery {
    # The documents to repair, enumerated from the vault instead of listed in a map.
    #
    # A map says exactly which documents a migration produced, and that is the safer
    # scope. A query is for when the migration WAS the vault, or when the job is "every
    # document of this subtype" - cases where maintaining a spreadsheet of ids would be
    # busywork. Only the WHERE clause is taken, so the query cannot quietly select
    # something other than document ids.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Where,
        # Stop paging once this many are in hand. 0 means every page. A survey needs
        # twenty-five documents, and paging a 500,000-document vault to the end to throw
        # away all but twenty-five is five hundred calls spent on nothing.
        [int]$Stop = 0
    )

    $w = $Where.Trim()
    $vql = if (-not $w)                  { 'SELECT id FROM documents' }
           elseif ($w -match '^\s*SELECT\s') { $w }
           else                          { "SELECT id FROM documents WHERE $w" }
    Write-VaultLog "Enumerating: $vql"

    $out  = New-Object System.Collections.ArrayList
    $seen = @{}
    $path  = '/query'
    $body  = "q=$([Uri]::EscapeDataString($vql))"
    $pages = 0

    while ($path -and $pages -lt 1000) {
        $pages++
        # Page 1 is a POST carrying the query; every page after it is a GET on the URL
        # Vault hands back, which already has the query baked in.
        $r = if ($pages -eq 1) {
                Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
                    -Path $path -Body $body -ContentType 'application/x-www-form-urlencoded'
             } else {
                Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path $path
             }

        foreach ($row in @(Get-VaultField $r 'data' @())) {
            $id = "$(Get-VaultField $row 'id' '')"
            if (-not $id -or $seen.ContainsKey($id)) { continue }
            $seen[$id] = $true
            [void]$out.Add([pscustomobject]@{ TargetId = $id; SourceId = '' })
        }
        if ($Stop -gt 0 -and $out.Count -ge $Stop) { break }
        $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    if ($out.Count -eq 0) { throw "The query matched no documents: $vql" }
    if ($Stop -gt 0 -and $out.Count -gt $Stop) { $out = @($out | Select-Object -First $Stop) }
    Write-VaultLog "$($out.Count) document(s) from the query" 'OK'
    return @($out)
}


# ======================================================================================
#  Users and groups, by name
#
#  The document roles API speaks in numeric ids. The Admin screen a defaults table is
#  transcribed from speaks in labels. Both directions are needed: names in, so the table
#  can be written by a person, and names out, so the plan can be read by one.
# ======================================================================================

$script:Directory = $null

function Get-VaultDirectory {
    # Every user and group in the vault, indexed by id and by every name it answers to.
    # Fetched once. A vault with tens of thousands of users makes this a handful of pages;
    # doing it per document instead would make it thousands of calls.
    param([Parameter(Mandatory)]$Context)
    if ($script:Directory) { return $script:Directory }

    $byId      = @{}
    $byName    = @{}
    $byMembers = @{}   # group id -> the user ids in it

    # Both listings come back wrapped - users: [ { user: {...} } ] - but not every Vault
    # release wraps them, so unwrap defensively rather than assuming either shape.
    function Add-Entry {
        param($Record, [string]$Wrapper, [string[]]$NameFields, [string]$Kind)
        $r = Get-VaultField $Record $Wrapper $null
        if ($null -eq $r) { $r = $Record }
        $id = "$(Get-VaultField $r 'id' '')"
        if (-not $id) { return }
        $names = @()
        foreach ($nf in $NameFields) {
            $v = "$(Get-VaultField $r $nf '')"
            if ($v) { $names += $v }
        }
        $display = if ($names.Count) { $names[0] } else { $id }
        $byId["$Kind`:$id"] = $display
        # Group membership, so a run can say whether the users it is about to assign
        # directly are simply the people already in the groups it is assigning.
        if ($Kind -eq 'group') {
            $byMembers[$id] = @(@(Get-VaultField $r 'members__v' @()) | ForEach-Object { "$_" })
        }
        # Indexed under BOTH foldings. A group arrives here as a label ("Business
        # Administrators") and is looked up by MDL as a name ("business_administrators__c");
        # keying only one way means the lookup misses and the group is silently dropped
        # from a role. That is the same failure the lifecycle join already had.
        foreach ($n in $names) {
            foreach ($k in @("$Kind`:$(ConvertTo-VaultKey $n)", "$Kind`:$(ConvertTo-VaultNameKey $n)")) {
                if (-not $byName.ContainsKey($k)) { $byName[$k] = $id }
            }
        }
    }

    # Groups come back whole - Retrieve All Groups documents no pagination parameters at
    # all - so one call is the whole set.
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path '/objects/groups'
    foreach ($rec in @(Get-VaultField $r 'groups' @())) {
        Add-Entry -Record $rec -Wrapper 'group' -NameFields @('label__v', 'name__v') -Kind 'group'
    }

    # Users page by limit and start, NOT by responseDetails.next_page - that field is a
    # VQL thing and this endpoint does not return it. Reading the page-1 response for a
    # next_page that is never there stops silently at the first 200 users, and a user the
    # directory has never heard of resolves to nothing, which quietly shrinks a role.
    #
    # 200 is the documented default. Anything from 500 up is rejected outright:
    # INVALID_DATA, "The 'limit' parameter must be < 500."
    $pageSize = 200
    $start    = 0
    $pages    = 0
    while ($pages -lt 2000) {
        $pages++
        $before = $byId.Count
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/objects/users?limit=$pageSize&start=$start"
        $batch = @(Get-VaultField $r 'users' @())
        foreach ($rec in $batch) {
            Add-Entry -Record $rec -Wrapper 'user' -NameFields @('user_name__v', 'user_email__v', 'name__v') -Kind 'user'
        }
        # Two independent stop conditions, because either alone can fail. A short page
        # means the end; no NEW entries means the endpoint ignored `start` and is handing
        # back page one for ever, which would otherwise spin until the page cap.
        if ($batch.Count -lt $pageSize) { break }
        if ($byId.Count -eq $before)    { break }
        $start += $pageSize
    }

    $users  = @($byId.Keys | Where-Object { $_ -like 'user:*' }).Count
    $groups = @($byId.Keys | Where-Object { $_ -like 'group:*' }).Count
    Write-VaultLog "Directory: $users user(s), $groups group(s)"
    $script:Directory = [pscustomobject]@{ ById = $byId; ByName = $byName; Members = $byMembers }
    return $script:Directory
}

# ======================================================================================
#  Document type default security
#
#  The "Default Settings for New Documents" box on Admin > Document Types > (subtype) >
#  Security. This is NOT the lifecycle's role assignment rules, and it is NOT in
#  defaultUsers/defaultGroups on the document roles endpoint - a real vault reported
#  nothing at all for editor__v while that screen listed three groups for it.
#
#  It IS in the MDL component for the doctype, as role_defaulting_editors / _viewers /
#  _consumers, each a list of "group:Group.name__c" or "user:username". Read once per
#  subtype rather than once per document, so it costs a handful of calls for a whole run.
# ======================================================================================

$script:DocTypeNames    = $null
$script:DocTypeDefaults = @{}

function Get-VaultDocTypeNameIndex {
    # label -> api name, for document types. A document reports LABELS ("Administrative
    # Information") while MDL is keyed by NAME, so one has to become the other before
    # anything can be looked up at all.
    param([Parameter(Mandatory)]$Context)
    if ($script:DocTypeNames) { return $script:DocTypeNames }

    $types = @{}
    $subs  = @{}
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path '/metadata/objects/documents/types'
    foreach ($ty in @(Get-VaultField $r 'types' @())) {
        $label = "$(Get-VaultField $ty 'label' '')"
        $url   = "$(Get-VaultField $ty 'value' '')"
        if (-not $label -or -not $url) { continue }
        $name = ($url -split '/')[-1]
        if ($name) { $types[(ConvertTo-VaultNameKey $label)] = $name }
    }
    $script:DocTypeNames = [pscustomobject]@{ Types = $types; Subtypes = $subs; Classifications = @{} }
    return $script:DocTypeNames
}

function Get-VaultSubtypeName {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$TypeName,
        [Parameter(Mandatory)][AllowEmptyString()][string]$SubtypeLabel
    )
    $idx = Get-VaultDocTypeNameIndex -Context $Context
    $key = "$TypeName|$(ConvertTo-VaultNameKey $SubtypeLabel)"
    if ($idx.Subtypes.ContainsKey($key)) { return $idx.Subtypes[$key] }
    try {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/metadata/objects/documents/types/$TypeName"
        foreach ($st in @(Get-VaultField $r 'subtypes' @())) {
            $label = "$(Get-VaultField $st 'label' '')"
            $url   = "$(Get-VaultField $st 'value' '')"
            if (-not $label -or -not $url) { continue }
            $nm = ($url -split '/')[-1]
            if ($nm) { $idx.Subtypes["$TypeName|$(ConvertTo-VaultNameKey $label)"] = $nm }
        }
    }
    catch { Write-VaultLog "  could not list the subtypes of ${TypeName}: $_" 'WARN' }
    if ($idx.Subtypes.ContainsKey($key)) { return $idx.Subtypes[$key] }
    return ''
}

function ConvertFrom-VaultMdlPrincipalList {
    # "group:Group.business_administrators__c" / "user:jane@example.com" -> ids.
    param(
        [Parameter(Mandatory)]$Directory,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Values
    )
    $users   = New-Object System.Collections.ArrayList
    $groups  = New-Object System.Collections.ArrayList
    $unknown = New-Object System.Collections.ArrayList
    foreach ($raw in $Values) {
        $v = "$raw".Trim().Trim("'", '"')
        if (-not $v) { continue }
        if ($v -match '^group:\s*(?:Group\.)?(.+)$') {
            $nm = $Matches[1].Trim()
            $id = Resolve-VaultNameToId -Directory $Directory -Kind 'group' -Name $nm
            if ($id) { [void]$groups.Add($id) } else { [void]$unknown.Add("group '$nm'") }
        }
        elseif ($v -match '^user:\s*(.+)$') {
            $nm = $Matches[1].Trim()
            $id = Resolve-VaultNameToId -Directory $Directory -Kind 'user' -Name $nm
            if ($id) { [void]$users.Add($id) } else { [void]$unknown.Add("user '$nm'") }
        }
    }
    return [pscustomobject]@{ Users = @($users); Groups = @($groups); Unknown = @($unknown) }
}

function Get-VaultMdlAttributeValue {
    # One multi-value attribute out of an MDL component response.
    #
    # Three shapes are accepted because this endpoint's is not documented in the mirror: a
    # JSON component carrying the attribute as a property, one carrying it in an
    # attributes list, and raw MDL source written as name('a', 'b'). Betting on one and
    # being wrong would apply no type defaults at all and say nothing - which is precisely
    # the failure this code exists to fix.
    param([Parameter(Mandatory)]$Response, [Parameter(Mandatory)][string]$Attribute)

    foreach ($holder in @($Response, (Get-VaultField $Response 'data' $null), (Get-VaultField $Response 'component' $null))) {
        if ($null -eq $holder) { continue }
        $v = Get-VaultField $holder $Attribute $null
        if ($null -ne $v) { return @($v) }
        foreach ($listName in @('attributes', 'properties')) {
            foreach ($a in @(Get-VaultField $holder $listName @())) {
                if ("$(Get-VaultField $a 'name' '')" -eq $Attribute) {
                    $av = Get-VaultField $a 'value' $null
                    if ($null -ne $av) { return @($av) }
                }
            }
        }
    }

    $raw = "$(Get-VaultField $Response 'raw' '')"
    if ($raw -and $raw -match ($Attribute + '\s*\(([^)]*)\)')) {
        return @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim("'", '"') } | Where-Object { $_ })
    }
    return @()
}

function Get-VaultClassificationName {
    # label -> api name for a classification, the THIRD level of the document type
    # hierarchy. Type, then subtype, then classification: a vault that uses all three
    # configures defaults at whichever level it chooses, and reading only two of them
    # means the most specific configuration - the one deliberately set closest to the
    # document - is the one missed.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$TypeName,
        [Parameter(Mandatory)][string]$SubtypeName,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ClassificationLabel
    )
    if (-not $ClassificationLabel) { return '' }
    $idx = Get-VaultDocTypeNameIndex -Context $Context
    $key = "$TypeName|$SubtypeName|$(ConvertTo-VaultNameKey $ClassificationLabel)"
    if ($idx.Classifications.ContainsKey($key)) { return $idx.Classifications[$key] }
    try {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/metadata/objects/documents/types/$TypeName/subtypes/$SubtypeName"
        foreach ($cl in @(Get-VaultField $r 'classifications' @())) {
            $label = "$(Get-VaultField $cl 'label' '')"
            $url   = "$(Get-VaultField $cl 'value' '')"
            if (-not $label -or -not $url) { continue }
            $nm = ($url -split '/')[-1]
            if ($nm) { $idx.Classifications["$TypeName|$SubtypeName|$(ConvertTo-VaultNameKey $label)"] = $nm }
        }
    }
    catch { Write-VaultLog "  could not list the classifications of $TypeName/${SubtypeName}: $_" 'WARN' }
    if ($idx.Classifications.ContainsKey($key)) { return $idx.Classifications[$key] }
    return ''
}

function Get-VaultDocTypeRoleDefault {
    # editor__v / viewer__v / consumer__v defaults for one subtype, from its MDL component.
    # Cached, so a run over 15,000 documents of six subtypes makes six of these calls.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$TypeLabel,
        [Parameter(Mandatory)][AllowEmptyString()][string]$SubtypeLabel,
        [Parameter(Mandatory)]$Directory,
        # The third level of the hierarchy. Empty on a vault that does not use them.
        [AllowEmptyString()][string]$ClassificationLabel = ''
    )
    $cacheKey = "$TypeLabel|$SubtypeLabel|$ClassificationLabel"
    if ($script:DocTypeDefaults.ContainsKey($cacheKey)) { return $script:DocTypeDefaults[$cacheKey] }

    $empty = @{}
    $script:DocTypeDefaults[$cacheKey] = $empty
    if (-not $TypeLabel) { return $empty }

    $idx     = Get-VaultDocTypeNameIndex -Context $Context
    $typeKey = ConvertTo-VaultNameKey $TypeLabel
    if (-not $idx.Types.ContainsKey($typeKey)) {
        Write-VaultLog "No document type called '$TypeLabel' - its type defaults cannot be read" 'WARN'
        return $empty
    }
    $typeName = $idx.Types[$typeKey]

    # Walk the hierarchy, most specific first. The component reference is explicit that
    # these attributes are inherited: "If none are specified, the default value is
    # inherited from parent or base." A subtype usually does NOT restate them, which is
    # why reading only the subtype found nothing while the Admin screen - which shows the
    # EFFECTIVE value - listed three groups.
    #
    # First level that defines a role wins for that role, which is what inheritance means.
    # Roles are filled independently: a subtype may override Editors while still
    # inheriting Viewers from its type.
    # Most specific first, and there are THREE levels, not two. Classification is where
    # a vault that uses it puts the configuration meant for these documents in
    # particular, so skipping it reads the general answer and calls it the specific one.
    $candidates = New-Object System.Collections.ArrayList
    $subName = ''
    if ($SubtypeLabel -and (ConvertTo-VaultNameKey $SubtypeLabel) -ne $typeKey) {
        $subName = Get-VaultSubtypeName -Context $Context -TypeName $typeName -SubtypeLabel $SubtypeLabel
    }
    if ($subName -and $ClassificationLabel) {
        $clsName = Get-VaultClassificationName -Context $Context -TypeName $typeName `
                       -SubtypeName $subName -ClassificationLabel $ClassificationLabel
        if ($clsName) { [void]$candidates.Add("Doctype.$typeName.$subName.$clsName") }
    }
    if ($subName) { [void]$candidates.Add("Doctype.$typeName.$subName") }
    [void]$candidates.Add("Doctype.$typeName")
    [void]$candidates.Add('Doctype.base_document__v')

    $out      = @{}
    $unknown  = New-Object System.Collections.ArrayList
    $sources  = New-Object System.Collections.ArrayList
    $lastResp = $null
    $lastName = ''
    $why      = ''

    foreach ($component in $candidates) {
        if ($out.Count -eq 3) { break }   # every role already answered by a nearer level

        # Two endpoints return this, and they are shaped differently on purpose:
        #
        #   GET /api/{version}/configuration/{Type}.{name}   JSON, versioned
        #   GET /api/mdl/components/{Type}.{name}            MDL source, NOT versioned
        #
        # The second has no version segment at all. Building it as /api/v26.2/mdl/... earns
        # a 404 MALFORMED_URL, which is how the first attempt at this failed.
        $r = $null
        foreach ($path in @("/configuration/$component", "/api/mdl/components/$component")) {
            try {
                $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                        -Path $path -MaxRetries 1
                break
            }
            catch { if (-not $why) { $why = "$_" } }
        }
        if ($null -eq $r) { continue }
        $lastResp = $r
        $lastName = $component

        foreach ($pair in @(
            @{ Role = 'editor__v';   Attr = 'role_defaulting_editors' },
            @{ Role = 'viewer__v';   Attr = 'role_defaulting_viewers' },
            @{ Role = 'consumer__v'; Attr = 'role_defaulting_consumers' }
        )) {
            if ($out.ContainsKey($pair.Role)) { continue }
            $vals = @(Get-VaultMdlAttributeValue -Response $r -Attribute $pair.Attr)
            if (-not $vals.Count) { continue }
            $res = ConvertFrom-VaultMdlPrincipalList -Directory $Directory -Values $vals
            foreach ($u in $res.Unknown) { [void]$unknown.Add($u) }
            if ($res.Users.Count -or $res.Groups.Count) {
                $out[$pair.Role] = [pscustomobject]@{ Users = $res.Users; Groups = $res.Groups }
                [void]$sources.Add("$($pair.Role) from $component")
            }
        }
    }

    if ($unknown.Count) {
        Write-VaultLog "Type defaults name $($unknown.Count) principal(s) matching nothing in this vault: $(($unknown | Select-Object -Unique | Select-Object -First 5) -join '; ')" 'WARN'
    }

    if ($out.Count) {
        Write-VaultLog "Type defaults for '$SubtypeLabel': $(($sources | Sort-Object) -join ', ')"
    }
    else {
        # Nothing found anywhere up the hierarchy. That is either a vault that really has
        # no type defaults, or a response shaped in a way this does not read - and those
        # two look identical from the outside, so print what actually came back rather
        # than leave someone to guess which it was.
        Write-VaultLog "No type defaults found for '$SubtypeLabel' at any level: $($candidates -join ', ')" 'WARN'
        if ($why) { Write-VaultLog "  last error: $why" 'WARN' }
        if ($lastResp) {
            $props = @()
            try { $props = @($lastResp.PSObject.Properties | ForEach-Object { $_.Name }) } catch { }
            Write-VaultLog "  $lastName returned: $($props -join ', ')" 'WARN'
            $raw = "$(Get-VaultField $lastResp 'raw' '')"
            if (-not $raw) { try { $raw = ($lastResp | ConvertTo-Json -Depth 4 -Compress) } catch { } }
            if ($raw.Length -gt 600) { $raw = $raw.Substring(0, 600) + ' ...' }
            Write-VaultLog "  $raw" 'WARN'
        }
    }

    $script:DocTypeDefaults[$cacheKey] = $out
    return $out
}

function Get-VaultRedundantUserCount {
    # How many of these users are already in at least one of these groups.
    #
    # Counted per USER, not per membership row. Counting per row reported 1,449 redundant
    # out of 1,430 total on a real run - a subset larger than the set it is part of -
    # because anyone in two of the groups was counted twice. A number that cannot be true
    # discredits the finding it exists to support.
    param(
        [Parameter(Mandatory)]$Directory,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Groups,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Users
    )
    if (-not $Users.Count -or -not $Groups.Count) { return 0 }
    $covered = @{}
    foreach ($g in $Groups) {
        if (-not $Directory.Members.ContainsKey("$g")) { continue }
        foreach ($m in $Directory.Members["$g"]) { $covered["$m"] = $true }
    }
    return @($Users | Where-Object { $covered.ContainsKey("$_") }).Count
}

function Get-VaultDisplayName {
    param([Parameter(Mandatory)]$Directory, [Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Id)
    $k = "$Kind`:$Id"
    if ($Directory.ById.ContainsKey($k)) { return $Directory.ById[$k] }
    return $Id
}

function Resolve-VaultNameToId {
    param([Parameter(Mandatory)]$Directory, [Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Name)
    $n = $Name.Trim()
    if (-not $n) { return '' }
    if ($n -match '^\d+$') { return $n }      # already an id
    foreach ($k in @("$Kind`:$(ConvertTo-VaultKey $n)", "$Kind`:$(ConvertTo-VaultNameKey $n)")) {
        if ($Directory.ByName.ContainsKey($k)) { return $Directory.ByName[$k] }
    }
    return ''
}


# ======================================================================================
#  The desired state
#
#  Two sources, one shape. Without -Defaults it is whatever Vault reports as the defaults
#  for that document, which is the better answer when it is right because Vault has
#  already evaluated the override conditions. With -Defaults it is a table transcribed
#  from Admin > Document Types > Security, which is the better answer when it is not.
# ======================================================================================

function Import-VaultDefaultsTable {
    # role,users,groups[,subtype] - names or ids, either spelling.
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Directory)

    $f = Import-VaultDelimitedFile -Path $Path
    $col = @{}
    foreach ($n in $f.Names) {
        switch (ConvertTo-VaultKey $n) {
            'role'    { $col['role'] = $n }
            'users'   { $col['users'] = $n }
            'user'    { $col['users'] = $n }
            'groups'  { $col['groups'] = $n }
            'group'   { $col['groups'] = $n }
            'subtype' { $col['subtype'] = $n }
        }
    }
    if (-not $col.ContainsKey('role')) {
        throw "The defaults table needs a 'role' column. $($f.Path) has: $($f.Names -join ', ')."
    }
    if (-not $col.ContainsKey('users') -and -not $col.ContainsKey('groups')) {
        throw "The defaults table needs a 'users' or a 'groups' column. $($f.Path) has: $($f.Names -join ', ')."
    }

    $table   = New-Object System.Collections.ArrayList
    $unknown = New-Object System.Collections.ArrayList

    foreach ($row in $f.Rows) {
        $roleName = "$(Get-VaultField $row $col['role'] '')".Trim()
        if (-not $roleName) { continue }

        $users  = New-Object System.Collections.ArrayList
        $groups = New-Object System.Collections.ArrayList
        foreach ($pair in @(@{ Kind = 'user'; Col = 'users'; Bag = $users },
                            @{ Kind = 'group'; Col = 'groups'; Bag = $groups })) {
            if (-not $col.ContainsKey($pair.Col)) { continue }
            $raw = "$(Get-VaultField $row $col[$pair.Col] '')"
            foreach ($piece in ($raw -split '[,;|]')) {
                $name = $piece.Trim().Trim('"', "'")
                if (-not $name) { continue }
                $id = Resolve-VaultNameToId -Directory $Directory -Kind $pair.Kind -Name $name
                if ($id) { [void]$pair.Bag.Add($id) }
                else     { [void]$unknown.Add("$($pair.Kind) '$name' (role $roleName)") }
            }
        }

        [void]$table.Add([pscustomobject]@{
            RoleKey = ConvertTo-VaultKey $roleName
            RoleRaw = $roleName
            Subtype = if ($col.ContainsKey('subtype')) { ConvertTo-VaultKey "$(Get-VaultField $row $col['subtype'] '')" } else { '' }
            Users   = @($users)
            Groups  = @($groups)
        })
    }

    if ($unknown.Count) {
        # Refuse. A name that resolved to nothing means a role silently gets fewer people
        # than the screen says it should, and the run still reports success - which is
        # exactly the failure this script exists to fix.
        $show = ($unknown | Select-Object -Unique | Select-Object -First 10) -join "`n    "
        throw @"
$($unknown.Count) name(s) in $($f.Path) match no user or group in this vault:

    $show

Check the spelling against Admin > Users & Groups. Ids are accepted too, if a name is
ambiguous.
"@
    }
    if ($table.Count -eq 0) { throw "No usable rows in $($f.Path)" }

    Write-VaultLog "$($table.Count) default rule(s) from $($f.Path)" 'OK'
    return @($table)
}

function Get-VaultDesiredForRole {
    # What this role should hold on this document, as two lists of ids, from whichever
    # source -DesiredFrom named. Every branch returns the same shape plus a Which/Message
    # pair saying where the answer came from, because that is what goes in the report and
    # it is the only way anyone can audit an assignment after the fact.
    param(
        [Parameter(Mandatory)][ValidateSet('Lifecycle', 'Document', 'Table')][string]$From,
        [Parameter(Mandatory)]$RoleRecord,
        [AllowNull()]$Table,
        [AllowNull()]$Rules,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Subtype,
        [AllowNull()]$DocumentInfo
    )
    $nameKey  = ConvertTo-VaultKey "$(Get-VaultField $RoleRecord 'name' '')"
    $labelKey = ConvertTo-VaultKey "$(Get-VaultField $RoleRecord 'label' '')"
    # The rules index is keyed name-tolerantly, so the lookup has to be too.
    $roleNameKey = ConvertTo-VaultNameKey "$(Get-VaultField $RoleRecord 'name' '')"

    switch ($From) {

        'Document' {
            # Whatever Vault itself calls the default for this document. Cheapest, and it
            # needs no rule interpretation at all - but see -Probe for whether it carries
            # the document type's default security as well as the lifecycle's rules.
            return [pscustomobject]@{
                Users   = @(@(Get-VaultField $RoleRecord 'defaultUsers'  @()) | ForEach-Object { "$_" })
                Groups  = @(@(Get-VaultField $RoleRecord 'defaultGroups' @()) | ForEach-Object { "$_" })
                Which   = 'DOCUMENT_DEFAULT'
                Message = ''
            }
        }

        'Lifecycle' {
            if ($null -eq $Rules -or $null -eq $DocumentInfo) {
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_RULES'
                                          Message = 'the lifecycle rules were not read' }
            }
            if (-not $DocumentInfo.Read) {
                # The document could not be read, so which override applies is unknown.
                # Falling back to the default rule here would be the dangerous kind of
                # guess: an override exists precisely because the default is wrong for
                # some documents, and this may be one of them.
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'DOCUMENT_UNREADABLE'
                                          Message = 'could not read the document, so no rule can be chosen for it' }
            }
            if (-not $DocumentInfo.Lifecycle) {
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_LIFECYCLE'
                                          Message = 'the document reports no lifecycle' }
            }
            $key = "$(ConvertTo-VaultNameKey $DocumentInfo.Lifecycle)|$roleNameKey"
            if (-not $Rules.ContainsKey($key)) {
                # Not an error. Most lifecycles configure rules for a few roles only, and
                # a role with no rule simply has no default - there is nothing to apply.
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_RULE_FOR_ROLE'; Message = '' }
            }
            return (Select-VaultRuleForDocument -Rule $Rules[$key] -Conditions $DocumentInfo.Conditions)
        }

        default {
            $users  = New-Object System.Collections.ArrayList
            $groups = New-Object System.Collections.ArrayList
            foreach ($rule in @($Table)) {
                if ($rule.RoleKey -ne $nameKey -and $rule.RoleKey -ne $labelKey) { continue }
                # A subtype-less rule applies everywhere; a subtype-bearing one only to its own.
                if ($rule.Subtype -and $rule.Subtype -ne $Subtype) { continue }
                foreach ($u in $rule.Users)  { [void]$users.Add($u) }
                foreach ($g in $rule.Groups) { [void]$groups.Add($g) }
            }
            return [pscustomobject]@{ Users = @($users); Groups = @($groups); Which = 'TABLE'; Message = '' }
        }
    }
}


# ======================================================================================
#  Results - rewritten after every batch, so an interrupted run leaves a usable file
# ======================================================================================

function Get-VaultDocumentRole {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$DocId
    )
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path "/objects/documents/$DocId/roles"
    return @(Get-VaultField $r 'documentRoles' @())
}

# The fields an override rule can be conditioned on. Read from every document so an
# override can be matched against it; eTMF adds the two study fields, and a vault without
# them simply reports nothing there.
$script:ConditionFields = @('product__v', 'country__v', 'study__v', 'study_country__v')

function Get-VaultDocumentInfo {
    # Type, subtype, lifecycle, and the fields an override rule can turn on. One extra
    # read per document - unavoidable in Lifecycle mode, since the rule that applies is a
    # property of the document, not of the map.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$DocId)
    try {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/objects/documents/$DocId"
        $d = Get-VaultField $r 'document' $null
        $type    = "$(Get-VaultField $d 'type__v' '')"
        $subtype = "$(Get-VaultField $d 'subtype__v' '')"
        # The third level. A vault that does not use classifications reports nothing
        # here and everything below behaves exactly as it did.
        $classification = "$(Get-VaultField $d 'classification__v' '')"
        # A type with no subtypes configured reports none. Falling back to the type keeps
        # every document in exactly one bucket, which is what the grouping needs.
        if (-not $subtype) { $subtype = $type }

        # Every one of these is multi-value in some vaults and single in others, so read
        # them all as lists. Matching a scalar against a list works either way; the
        # reverse does not.
        $cond = @{}
        foreach ($f in $script:ConditionFields) {
            $cond[$f] = @(@(Get-VaultField $d $f @()) | ForEach-Object { "$_" } | Where-Object { $_ })
        }

        return [pscustomobject]@{
            Type       = $type
            Subtype    = $subtype
            Classification = $classification
            Lifecycle  = "$(Get-VaultField $d 'lifecycle__v' '')"
            Conditions = $cond
            Read       = $true
        }
    }
    catch {
        Write-VaultLog "  could not read document ${DocId}: $_" 'WARN'
        $cond = @{}
        foreach ($f in $script:ConditionFields) { $cond[$f] = @() }
        return [pscustomobject]@{ Type = ''; Subtype = ''; Lifecycle = ''; Conditions = $cond; Read = $false }
    }
}

function Get-VaultRoleAssignmentRule {
    # GET /configuration/role_assignment_rule - every lifecycle role's default and
    # override rules, in one call. Indexed by lifecycle and role.
    #
    # This endpoint speaks in NAMES (ally@veepharm.com, global_products_team__c) while the
    # document roles endpoint speaks in ids, so everything is resolved to ids here and the
    # two become comparable. That comparison is the whole point of the probe.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Directory)

    $byKey = @{}
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path '/configuration/role_assignment_rule'

    $unresolved = New-Object System.Collections.ArrayList

    foreach ($rule in @(Get-VaultField $r 'data' @())) {
        $lc   = "$(Get-VaultField $rule 'lifecycle__v' '')"
        $role = "$(Get-VaultField $rule 'role__v' '')"
        if (-not $lc -or -not $role) { continue }

        # A row carrying product/country/study is an OVERRIDE row; one carrying none is
        # the default. They must never be merged: an override REPLACES the default when
        # its condition is met, so adding them together would invent a rule Vault does not
        # have and hand people access the configuration never granted.
        $conds = @{}
        foreach ($f in $script:ConditionFields) {
            $v = "$(Get-VaultField $rule $f '')"
            if ($v) { $conds[$f] = $v }
        }

        # allowed_default_* is what Vault ASSIGNS automatically. allowed_* is the wider
        # set a person MAY be added to later, by hand. Only the first is a default, and
        # applying the second would put everyone who could ever be on the document onto
        # every document.
        $users  = New-Object System.Collections.ArrayList
        $groups = New-Object System.Collections.ArrayList
        foreach ($pair in @(@{ Field = 'allowed_default_users__v';  Kind = 'user';  Bag = $users },
                            @{ Field = 'allowed_default_groups__v'; Kind = 'group'; Bag = $groups })) {
            foreach ($n in @(Get-VaultField $rule $pair.Field @())) {
                $name = "$n"
                if (-not $name) { continue }
                $id = Resolve-VaultNameToId -Directory $Directory -Kind $pair.Kind -Name $name
                if ($id) { [void]$pair.Bag.Add($id) }
                else     { [void]$unresolved.Add("$($pair.Kind) '$name' ($lc / $role)") }
            }
        }

        $key = "$(ConvertTo-VaultNameKey $lc)|$(ConvertTo-VaultNameKey $role)"
        if (-not $byKey.ContainsKey($key)) {
            $byKey[$key] = [pscustomobject]@{
                Lifecycle = $lc; Role = $role
                Users = @(); Groups = @(); HasDefault = $false
                Overrides = (New-Object System.Collections.ArrayList)
            }
        }
        if ($conds.Count) {
            [void]$byKey[$key].Overrides.Add([pscustomobject]@{
                Conditions = $conds; Users = @($users); Groups = @($groups)
            })
        }
        else {
            $byKey[$key].Users      = @($users)
            $byKey[$key].Groups     = @($groups)
            $byKey[$key].HasDefault = $true
        }
    }

    if ($unresolved.Count) {
        # Not fatal - a rule may name a user who has since been deactivated, and that must
        # not stop the other rules being applied. But it is said out loud, because the
        # alternative is a role quietly getting fewer people than the configuration says.
        $show = ($unresolved | Select-Object -Unique | Select-Object -First 5) -join '; '
        Write-VaultLog "$($unresolved.Count) name(s) in the rules match no active user or group and are skipped: $show" 'WARN'
    }

    $overrides = (@($byKey.Values) | ForEach-Object { $_.Overrides.Count } | Measure-Object -Sum).Sum
    Write-VaultLog "$($byKey.Count) lifecycle/role rule(s) from /configuration/role_assignment_rule, $overrides override row(s)" 'OK'
    return $byKey
}

function Select-VaultRuleForDocument {
    # Which row of a lifecycle role's rules applies to THIS document.
    #
    # An override applies when the document carries every value the override names. More
    # than one can match - a product-only rule and a product-and-country rule - and Vault
    # takes the more specific. A tie between two equally specific overrides is not
    # something this can resolve, so it refuses rather than picking one: guessing here
    # means granting access to the wrong people.
    param([Parameter(Mandatory)]$Rule, [Parameter(Mandatory)][hashtable]$Conditions)

    $best = $null; $bestScore = -1; $tied = $false
    foreach ($ov in $Rule.Overrides) {
        $matched = $true
        foreach ($f in $ov.Conditions.Keys) {
            $have = @()
            if ($Conditions.ContainsKey($f)) { $have = @($Conditions[$f]) }
            if ($have -notcontains $ov.Conditions[$f]) { $matched = $false; break }
        }
        if (-not $matched) { continue }
        $score = $ov.Conditions.Count
        if ($score -gt $bestScore) { $best = $ov; $bestScore = $score; $tied = $false }
        elseif ($score -eq $bestScore) { $tied = $true }
    }

    if ($tied) {
        return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'AMBIGUOUS_OVERRIDE'
                                  Message = 'two override rules match this document equally well - Vault must be asked which wins' }
    }
    if ($best) {
        return [pscustomobject]@{ Users = @($best.Users); Groups = @($best.Groups); Which = 'OVERRIDE'
                                  Message = (($best.Conditions.Keys | Sort-Object | ForEach-Object { "$_=$($best.Conditions[$_])" }) -join ', ') }
    }
    if (-not $Rule.HasDefault) {
        return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_DEFAULT_RULE'
                                  Message = 'the role has override rules but no default, and none of the overrides match' }
    }
    return [pscustomobject]@{ Users = @($Rule.Users); Groups = @($Rule.Groups); Which = 'DEFAULT'; Message = '' }
}

function ConvertTo-VaultCsvField {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return '"' + ($Value -replace '"', '""') + '"'
}

function Send-VaultRoleBatch {
    # POST /objects/documents/roles/batch, as CSV.
    #
    # Batched by which COLUMNS a document needs, not just by count. The endpoint takes one
    # header for the whole batch, so mixing documents that need different roles would mean
    # blank cells - and nothing in Vault's documentation says what a blank cell in a
    # role column does. Grouping by shape removes the question rather than betting on it.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Items,
        [Parameter(Mandatory)][string[]]$Columns
    )
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine((@('id') + $Columns | ForEach-Object { ConvertTo-VaultCsvField $_ }) -join ',')
    foreach ($it in $Items) {
        $cells = @(ConvertTo-VaultCsvField $it.DocId)
        foreach ($cn in $Columns) { $cells += ConvertTo-VaultCsvField ($it.Cells[$cn] -join ',') }
        [void]$sb.AppendLine($cells -join ',')
    }

    # Sent as bytes with the charset stated. Windows PowerShell 5.1 will encode a string
    # body as ISO-8859-1 when the content type names no charset, which is the wrong answer
    # for a file the API requires to be UTF-8.
    $bytes = [Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
            -Path '/objects/documents/roles/batch' -Body $bytes -ContentType 'text/csv; charset=UTF-8'

    $byDoc = @{}
    foreach ($entry in @(Get-VaultField $r 'data' @())) {
        $id = "$(Get-VaultField $entry 'id' '')"
        if (-not $id) { continue }
        $ok = ((Get-VaultField $entry 'responseStatus' '') -eq 'SUCCESS')
        $msg = ''
        if (-not $ok) {
            $errs = @(Get-VaultField $entry 'errors' @())
            $msg = (($errs | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join '; ')
            if (-not $msg) { $msg = 'Vault reported FAILURE with no message' }
        }
        $byDoc[$id] = [pscustomobject]@{ Ok = $ok; Message = $msg }
    }
    return $byDoc
}
function Invoke-VaultRolesSurvey {
    # What is actually in scope, exactly, in about five seconds.
    #
    # This exists because the alternative was sampling: probing 300 documents at two reads
    # each to GUESS at the subtype list, when one paginated query returns every document's
    # type and subtype at 1,000 a page. Sixteen calls instead of six hundred, and the
    # answer is exact rather than "the subtypes that happened to be in the sample".
    #
    # No document is read individually and nothing is written.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][AllowEmptyString()][string]$Where)

    $c = $Context
    $w = $Where.Trim()
    $vql = if (-not $w) { 'SELECT id, type__v, subtype__v, lifecycle__v FROM documents' }
           else         { "SELECT id, type__v, subtype__v, lifecycle__v FROM documents WHERE $w" }
    Write-VaultLog "Surveying: $vql"

    $tally = @{}
    $total = 0
    $path  = '/query'
    $body  = "q=$([Uri]::EscapeDataString($vql))"
    $pages = 0

    while ($path -and $pages -lt 2000) {
        $pages++
        $r = if ($pages -eq 1) {
                Invoke-VaultApi -VaultHost $c.VaultHost -ApiVersion $c.Api -Method POST `
                    -Path $path -Body $body -ContentType 'application/x-www-form-urlencoded'
             } else {
                Invoke-VaultApi -VaultHost $c.VaultHost -ApiVersion $c.Api -Method GET -Path $path
             }
        foreach ($row in @(Get-VaultField $r 'data' @())) {
            $total++
            $ty  = "$(Get-VaultField $row 'type__v' '(no type)')"
            $sub = "$(Get-VaultField $row 'subtype__v' '')"
            if (-not $sub) { $sub = $ty }
            $lc  = "$(Get-VaultField $row 'lifecycle__v' '(no lifecycle)')"
            $k = "$ty|$sub"
            if (-not $tally.ContainsKey($k)) {
                $tally[$k] = [pscustomobject]@{
                    Type = $ty; Subtype = $sub; Count = 0
                    Lifecycles = (New-Object System.Collections.ArrayList)
                }
            }
            $tally[$k].Count++
            if ($tally[$k].Lifecycles -notcontains $lc) { [void]$tally[$k].Lifecycles.Add($lc) }
        }
        $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$total document(s) in scope, $($tally.Count) type/subtype combination(s), read in $pages page(s)"
    Write-VaultLog ''
    foreach ($k in ($tally.Keys | Sort-Object { -$tally[$_].Count })) {
        $e = $tally[$k]
        Write-VaultLog ("  {0,7:N0}  {1}" -f $e.Count, $(if ($e.Subtype -eq $e.Type) { $e.Type } else { "$($e.Type) / $($e.Subtype)" }))
        Write-VaultLog ("           lifecycle: {0}" -f (($e.Lifecycles | Sort-Object) -join ', '))
    }
    Write-VaultLog ''
    # Type defaults are cached per type and subtype, so this count IS the number of extra
    # calls the assign run makes for them - not one per document.
    Write-VaultLog "An assign run over this scope reads $total document(s) and resolves type defaults $($tally.Count) time(s)."
    $mins = [math]::Round((($total + $tally.Count * 3) * 0.3) / 60, 0)
    Write-VaultLog "At the rate this vault has been answering, that is roughly $mins minute(s)."
    return 0
}

function Invoke-VaultRolesProbe {
    # Read-only. Answers the questions that have to be answered before anything is
    # written, and answers them from the vault rather than from an assumption:
    #
    #   1. Which document types and subtypes does the map actually span?
    #   2. Within a subtype, do all documents report the same defaults? If they do, the
    #      subtype has one rule and a defaults table can be written for it. If they do
    #      not, something is conditional and a flat table would be wrong.
    #   3. Does defaultUsers/defaultGroups carry MORE than the lifecycle's role assignment
    #      rules? If it does, it is also carrying the document type's default security,
    #      and -Defaults is unnecessary. If it matches the lifecycle rules exactly, then
    #      the type defaults are NOT in there and -Defaults is the only way to apply them.
    #
    # It writes the discovered subtype/role/groups table out as a starter defaults file,
    # so the answer to (2) can be checked against the Admin screen side by side.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][array]$Documents, [int]$Limit = 0)

    $c   = $Context
    $dir = Get-VaultDirectory -Context $c

    $rules = @{}
    try { $rules = Get-VaultRoleAssignmentRule -Context $c -Directory $dir }
    catch { Write-VaultLog "Could not read the lifecycle role assignment rules: $_" 'WARN' }

    # Everything handed in, unless -Limit says otherwise. The scope was decided before
    # this function was called; it does not get to second-guess it.
    $docs = $Documents
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - surveying the first $Limit of $($docs.Count) document(s)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-VaultLog "$($docs.Count) document(s) to survey - two reads each"

    # subtypeKey -> role name -> what was seen
    $seen    = [ordered]@{}
    $rows    = New-Object System.Collections.ArrayList
    $errors  = 0
    $lifecyclesSeen = @{}
    $beyond  = 0    # roles whose document defaults exceed the lifecycle rule
    $equal   = 0    # roles whose document defaults match the lifecycle rule exactly
    $i = 0

    foreach ($doc in $docs) {
        $i++
        $docId = $doc.TargetId
        $info  = Get-VaultDocumentInfo -Context $c -DocId $docId
        if (-not $info.Subtype) { $errors++; continue }

        try { $roles = @(Get-VaultDocumentRole -Context $c -DocId $docId) }
        catch { Write-VaultLog "[$i/$($docs.Count)] doc $docId - ERROR reading roles: $_" 'ERROR'; $errors++; continue }

        if ($info.Lifecycle) { $lifecyclesSeen[$info.Lifecycle] = $true }
        $sk = ConvertTo-VaultKey $info.Subtype
        if (-not $seen.Contains($sk)) {
            $seen[$sk] = [pscustomobject]@{
                Subtype = $info.Subtype; Type = $info.Type
                Lifecycles = New-Object System.Collections.ArrayList
                Docs = 0
                Roles = [ordered]@{}
            }
        }
        $bucket = $seen[$sk]
        $bucket.Docs++
        if ($info.Lifecycle -and $bucket.Lifecycles -notcontains $info.Lifecycle) { [void]$bucket.Lifecycles.Add($info.Lifecycle) }

        foreach ($r in $roles) {
            $name  = "$(Get-VaultField $r 'name' '')"
            $label = "$(Get-VaultField $r 'label' $name)"
            if (-not $name) { continue }

            $defUsers  = @(@(Get-VaultField $r 'defaultUsers'  @()) | ForEach-Object { "$_" })
            $defGroups = @(@(Get-VaultField $r 'defaultGroups' @()) | ForEach-Object { "$_" })
            $asgUsers  = @(@(Get-VaultField $r 'assignedUsers' @()) | ForEach-Object { "$_" })
            $asgGroups = @(@(Get-VaultField $r 'assignedGroups' @()) | ForEach-Object { "$_" })

            # What the lifecycle's own default rule says, for the same role.
            # The rule that actually applies to THIS document - the matching override if
            # one matches, the default otherwise. Comparing against the default row alone
            # would report a false "beyond the rule" on every document an override covers.
            $ruleUsers = @(); $ruleGroups = @(); $overrides = 0; $haveRule = $false
            $which = ''
            $rk = "$(ConvertTo-VaultNameKey $info.Lifecycle)|$(ConvertTo-VaultNameKey $name)"
            if ($rules.ContainsKey($rk)) {
                $haveRule  = $true
                $overrides = $rules[$rk].Overrides.Count
                $applied   = Select-VaultRuleForDocument -Rule $rules[$rk] -Conditions $info.Conditions
                $ruleUsers  = @($applied.Users)
                $ruleGroups = @($applied.Groups)
                $which      = $applied.Which
            }

            $extraUsers  = @($defUsers  | Where-Object { $ruleUsers  -notcontains $_ })
            $extraGroups = @($defGroups | Where-Object { $ruleGroups -notcontains $_ })
            $verdict = 'NO_RULE'
            if ($haveRule) {
                if ($extraUsers.Count -or $extraGroups.Count) { $verdict = 'BEYOND_LIFECYCLE_RULE'; $beyond++ }
                else { $verdict = 'MATCHES_LIFECYCLE_RULE'; $equal++ }
            }

            $sig = ((@($defUsers | Sort-Object) -join ',') + '/' + (@($defGroups | Sort-Object) -join ','))
            if (-not $bucket.Roles.Contains($name)) {
                $bucket.Roles[$name] = [pscustomobject]@{
                    Label = $label
                    Users = $defUsers; Groups = $defGroups
                    Signature = $sig; Consistent = $true
                }
            }
            elseif ($bucket.Roles[$name].Signature -ne $sig) { $bucket.Roles[$name].Consistent = $false }

            [void]$rows.Add([pscustomobject][ordered]@{
                DocId = $docId; SourceDocId = $doc.SourceId
                Type = $info.Type; Subtype = $info.Subtype; Lifecycle = $info.Lifecycle
                Role = $name; RoleLabel = $label
                AssignedUsers  = ($asgUsers  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                AssignedGroups = ($asgGroups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                DefaultUsers   = ($defUsers  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                DefaultGroups  = ($defGroups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                LifecycleRuleUsers  = ($ruleUsers  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                LifecycleRuleGroups = ($ruleGroups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                OverrideRules = $overrides
                RuleApplied = $which
                Verdict = $verdict
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            })
        }
    }

    $reportPath = Join-Path $c.Out 'probe-report.csv'
    $rows | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    # The discovered table, in the shape -Defaults reads. Written whether or not the
    # defaults look trustworthy: it is a starting point to check against the screen, not
    # an answer to run unread.
    $defaultsPath = Join-Path $c.Out 'discovered-defaults.csv'
    $out = New-Object System.Collections.ArrayList
    foreach ($sk in $seen.Keys) {
        $b = $seen[$sk]
        foreach ($roleName in $b.Roles.Keys) {
            $r = $b.Roles[$roleName]
            if (-not $r.Users.Count -and -not $r.Groups.Count) { continue }
            [void]$out.Add([pscustomobject][ordered]@{
                subtype = $b.Subtype
                role    = $roleName
                users   = ($r.Users  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join ','
                groups  = ($r.Groups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join ','
            })
        }
    }
    if ($out.Count) { $out | Export-Csv -LiteralPath $defaultsPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false }

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($docs.Count) document(s) surveyed, $($seen.Count) subtype(s)"
    foreach ($sk in $seen.Keys) {
        $b = $seen[$sk]
        Write-VaultLog ''
        Write-VaultLog ("  {0}   ({1} document(s), lifecycle {2})" -f $b.Subtype, $b.Docs,
                   $(if ($b.Lifecycles.Count) { $b.Lifecycles -join ' / ' } else { '?' }))
        foreach ($roleName in $b.Roles.Keys) {
            $r = $b.Roles[$roleName]
            $bits = @()
            if ($r.Users.Count)  { $bits += 'users '  + (($r.Users  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join ', ') }
            if ($r.Groups.Count) { $bits += 'groups ' + (($r.Groups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join ', ') }
            $what = if ($bits.Count) { $bits -join ' + ' } else { 'no defaults reported' }
            $note = if (-not $r.Consistent) { '   *** documents in this subtype disagree - a flat table would be wrong ***' } else { '' }
            Write-VaultLog ("    {0,-24} {1}{2}" -f $roleName, $what, $note) $(if ($r.Consistent) { 'INFO' } else { 'WARN' })
        }
    }

    Write-VaultLog ''
    Write-VaultLog '----------------------------------------------------------------'
    if (-not $rules.Count) {
        Write-VaultLog 'The lifecycle role assignment rules could not be read, so no verdict on where the defaults come from.' 'WARN'
        Write-VaultLog 'Compare discovered-defaults.csv against Admin > Document Types > Security by hand.' 'WARN'
    }
    elseif ($beyond -gt 0) {
        Write-VaultLog "$beyond role(s) report defaults BEYOND the lifecycle's own rule." 'OK'
        Write-VaultLog 'So defaultUsers/defaultGroups carries more than the lifecycle rules - very likely the'
        Write-VaultLog 'document type default security too. Running without -Defaults should be right; confirm'
        Write-VaultLog 'on a few rows of probe-report.csv, then use -Plan.'
    }
    elseif ($equal -gt 0) {
        Write-VaultLog "Every role's defaults match its lifecycle rule exactly ($equal role(s) compared)." 'WARN'
        Write-VaultLog 'That is the signature of defaultUsers/defaultGroups carrying ONLY the lifecycle rules.'
        Write-VaultLog 'If the Admin screen shows groups that are not in probe-report.csv, they will NOT be'
        Write-VaultLog 'applied without -Defaults. Transcribe the screen, or start from discovered-defaults.csv.' 'WARN'
    }
    else {
        # Rules were read and documents were read, and not one pair joined. Saying nothing
        # here once let a probe look like a clean run while the entire rule lookup was
        # missing - and -DesiredFrom Lifecycle would then have assigned nobody, quietly,
        # after reading every document in the vault.
        Write-VaultLog 'NOT ONE role matched a lifecycle rule, though both were read.' 'ERROR'
        Write-VaultLog "  lifecycles on the documents:  $(($lifecyclesSeen.Keys | Sort-Object) -join ', ')" 'ERROR'
        Write-VaultLog "  lifecycles in the rules:      $((@($rules.Values | ForEach-Object { $_.Lifecycle }) | Select-Object -Unique | Sort-Object) -join ', ')" 'ERROR'
        Write-VaultLog '-DesiredFrom Lifecycle would assign NOTHING. Do not run it until these join.' 'ERROR'
    }
    if ($errors) { Write-VaultLog "$errors document(s) could not be read - the figures above are incomplete" 'ERROR' }
    Write-VaultLog ''
    Write-VaultLog "Report:            $reportPath"
    if ($out.Count) { Write-VaultLog "Starter defaults:  $defaultsPath" }
    return $errors
}

function Invoke-VaultRolesAssign {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Documents,
        [Parameter(Mandatory)][ValidateSet('Lifecycle', 'Document', 'Table')][string]$From,
        [AllowNull()]$Table,
        [AllowNull()]$Rules,
        # Declared, not inherited. These were script-scope parameters of a single-file
        # script; as a module function reaching for them would bind to whatever the
        # dispatcher happened to have in scope, which is how a switch belonging to one
        # command silently changes another.
        [ValidateSet('Both', 'Groups', 'Users')][string]$Assign = 'Both',
        [switch]$WithTypeDefaults,
        [switch]$Plan,
        [string[]]$Role = @(),
        [string[]]$ExcludeRole = @(),
        [int]$BatchSize = 200,
        [int]$Test = 0,
        [int]$Limit = 0,
        # Skip documents an earlier run already finished, instead of reading all of them
        # again. Off by default: reading current state is the safer thing to do, and the
        # only reason it is safe to stop doing it is that roles verify reads the vault
        # afterwards and says whether the claim was true.
        [switch]$Resume
    )

    $c   = $Context
    $dir = Get-VaultDirectory -Context $c

    # Lifecycle mode has to read each document: the rule that applies depends on the
    # document's own lifecycle and on the product/country/study an override turns on. A
    # subtype-keyed table needs the same read. Nothing else does, so nothing else pays.
    $needSubtype = ($From -eq 'Table') -and ($null -ne $Table) -and (@($Table | Where-Object { $_.Subtype }).Count -gt 0)
    $needInfo    = ($From -eq 'Lifecycle') -or $needSubtype -or $WithTypeDefaults

    $docs = $Documents
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - examining the first $Limit of $($docs.Count) document(s)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-VaultLog "$($docs.Count) document(s) in scope"
    if ($Resume) {
        # Said BEFORE the read, not after. The results file runs to tens of megabytes,
        # and loading it is a silent half minute - during which the only thing on screen
        # was a count of everything in scope, which is indistinguishable from a run that
        # ignored -Resume. Somebody watching that will kill it, and be right to.
        Write-VaultLog '-Resume: reading what earlier runs finished. A large results file takes a moment.' 'WARN'
    }

    # Prior rows are loaded either way - from the CSV and from the journal of a run that
    # was killed - because they are carried through into the results file. Whether they
    # SKIP anything is what -Resume decides.
    $res = New-VaultResults -Path (Join-Path $c.Out 'role-results.csv') `
               -KeyColumn 'Key' -DoneStatuses @() -Existing $c.Existing

    if ($Resume) {
        # A document counts as finished only if every row it has says the work is done.
        #
        # WOULD_ASSIGN is the trap. A plan run writes those rows to this same file, and
        # they mean the opposite of done - they are precisely the documents that need
        # assigning. Treating a row's mere existence as completion would skip every
        # document anybody had ever planned.
        #
        # ERROR and UNRESOLVED are not done either. Those are the ones most worth
        # retrying, so a resume that skipped them would quietly abandon exactly the
        # documents that failed.
        $finished = @{}
        foreach ($k in $res.Prior.Keys) {
            $row = $res.Prior[$k]
            $docId = "$(Get-VaultField $row 'DocId' '')"
            if (-not $docId) { continue }
            $st = "$(Get-VaultField $row 'Status' '')"
            if (-not $finished.ContainsKey($docId)) { $finished[$docId] = $true }
            if ($st -notin @('ASSIGNED', 'IN_STEP')) { $finished[$docId] = $false }
        }
        $doneIds = @{}
        foreach ($d in $finished.Keys) { if ($finished[$d]) { $doneIds[$d] = $true } }

        $before = $docs.Count
        $docs = @($docs | Where-Object { -not $doneIds.ContainsKey("$($_.TargetId)") })
        $skipped = $before - $docs.Count
        Write-VaultLog "-Resume: $($res.Prior.Count) row(s) read, covering $($finished.Count) document(s)"
        if ($skipped) {
            Write-VaultLog "-Resume: $skipped finished already - not read again. $($docs.Count) left to do." 'OK'
            Write-VaultLog 'roles verify is what confirms the skipped ones.' 'WARN'
        }
        else {
            Write-VaultLog '-Resume: none of them count as finished, so all of them are still to do.' 'WARN'
            Write-VaultLog 'A document counts only when every row says ASSIGNED or IN_STEP - a WOULD_ASSIGN row from a plan run does not.' 'WARN'
        }
    }
    Write-VaultLog "$($docs.Count) document(s) to examine"

    $stat = @{ Docs = 0; InStep = 0; NeedWork = 0; Changed = 0; Users = 0; Groups = 0
               Errors = 0; NoRoles = 0; RedundantUsers = 0 }
    $pending = New-Object System.Collections.ArrayList   # documents waiting for a batch
    $i = 0
    $stopped = $false

    function Submit-Pending {
        # Send everything queued, grouped by column shape, and record a row per document
        # and role. Called when a group fills up and once at the end.
        if (-not $pending.Count) { return }

        $groups = @{}
        foreach ($it in $pending) {
            $sig = ($it.Cells.Keys | Sort-Object) -join '|'
            if (-not $groups.ContainsKey($sig)) { $groups[$sig] = New-Object System.Collections.ArrayList }
            [void]$groups[$sig].Add($it)
        }

        Write-VaultLog "Writing $($pending.Count) document(s) to Vault"
        foreach ($sig in $groups.Keys) {
            $items   = @($groups[$sig])
            $columns = @($sig -split '\|')
            for ($off = 0; $off -lt $items.Count; $off += $BatchSize) {
                $slice = @($items[$off..([math]::Min($off + $BatchSize - 1, $items.Count - 1))])
                $byDoc = @{}
                $failAll = ''
                try {
                    $byDoc = Send-VaultRoleBatch -Context $c -Items $slice -Columns $columns
                }
                catch {
                    $failAll = "$_"
                    Write-VaultLog "Batch of $($slice.Count) document(s) failed: $_" 'ERROR'
                }

                foreach ($it in $slice) {
                    $ok = $false; $msg = $failAll
                    if (-not $failAll) {
                        if ($byDoc.ContainsKey($it.DocId)) { $ok = $byDoc[$it.DocId].Ok; $msg = $byDoc[$it.DocId].Message }
                        else { $msg = 'Vault returned no result for this document' }
                    }
                    if ($ok) {
                        $stat.Changed++
                        Write-VaultLog "  doc $($it.DocId) - assigned $($it.Summary)" 'OK'
                    }
                    else {
                        $stat.Errors++
                        Write-VaultLog "  doc $($it.DocId) - FAILED: $msg" 'ERROR'
                    }
                    foreach ($row in $it.Rows) {
                        $row.Status  = if ($ok) { 'ASSIGNED' } else { 'ERROR' }
                        $row.Message = $msg
                        [void]$res.Rows.Add($row)
                    }
                }
                Save-VaultResults -Results $res
            }
        }
        $pending.Clear()
    }

    :documents foreach ($doc in $docs) {
        $i++
        $docId  = $doc.TargetId
        $prefix = "[$i/$($docs.Count)] doc $docId"
        $stat.Docs++

        try { $roles = Get-VaultDocumentRole -Context $c -DocId $docId }
        catch {
            Write-VaultLog "$prefix - ERROR reading roles: $_" 'ERROR'
            $stat.Errors++
            # Same column set as every other row. Export-Csv takes its header from the
            # first object it sees, so a row of a different shape silently drops columns
            # from the whole file.
            [void]$res.Rows.Add([pscustomobject][ordered]@{
                Key = "$docId`:-"; DocId = $docId; SourceDocId = $doc.SourceId
                Lifecycle = ''; Type = ''; Subtype = ''; Role = ''; RoleLabel = ''
                RuleApplied = ''; RuleDetail = ''
                AssignedUsers = ''; AssignedGroups = ''; MissingUsers = ''; MissingGroups = ''
                Status = 'ERROR'; Message = "$_"; CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            })
            if (($i % $BatchSize) -eq 0) { Save-VaultResults -Results $res }
            continue
        }
        if (-not $roles.Count) {
            $stat.NoRoles++
            Write-VaultLog "$prefix - no roles reported" 'WARN'
            continue
        }

        $info    = if ($needInfo) { Get-VaultDocumentInfo -Context $c -DocId $docId } else { $null }
        $subtype = if ($needSubtype) { ConvertTo-VaultKey $info.Subtype } else { '' }

        $cells   = [ordered]@{}
        $rows    = New-Object System.Collections.ArrayList
        $summary = New-Object System.Collections.ArrayList
        $docNeedsWork = $false

        foreach ($r in $roles) {
            $name  = "$(Get-VaultField $r 'name' '')"
            $label = "$(Get-VaultField $r 'label' $name)"
            if (-not $name) { continue }

            $nk = ConvertTo-VaultKey $name; $lk = ConvertTo-VaultKey $label
            if ($Role.Count) {
                $wanted = @($Role | ForEach-Object { ConvertTo-VaultKey $_ })
                if ($wanted -notcontains $nk -and $wanted -notcontains $lk) { continue }
            }
            if ($ExcludeRole.Count) {
                $skip = @($ExcludeRole | ForEach-Object { ConvertTo-VaultKey $_ })
                if ($skip -contains $nk -or $skip -contains $lk) { continue }
            }

            $assignedUsers  = @(@(Get-VaultField $r 'assignedUsers'  @()) | ForEach-Object { "$_" })
            $assignedGroups = @(@(Get-VaultField $r 'assignedGroups' @()) | ForEach-Object { "$_" })
            $want = Get-VaultDesiredForRole -From $From -RoleRecord $r -Table $Table -Rules $Rules `
                        -Subtype $subtype -DocumentInfo $info

            # Document type default security is a SECOND source, not an alternative one.
            # The lifecycle rules and the type's "Default Settings for New Documents" are
            # two different screens, both of which the UI applies when it creates a
            # document - so repairing only one of them leaves the job half done.
            if ($WithTypeDefaults -and $info) {
                $td = Get-VaultDocTypeRoleDefault -Context $c -TypeLabel $info.Type `
                          -SubtypeLabel $info.Subtype -Directory $dir `
                          -ClassificationLabel $info.Classification
                if ($td.ContainsKey($name)) {
                    $want = [pscustomobject]@{
                        Users   = @(@($want.Users)  + @($td[$name].Users)  | Select-Object -Unique)
                        Groups  = @(@($want.Groups) + @($td[$name].Groups) | Select-Object -Unique)
                        Which   = $(if ($want.Which -in @('NO_RULE_FOR_ROLE', 'NO_RULES', '')) { 'TYPE_DEFAULT' }
                                    else { "$($want.Which)+TYPE_DEFAULT" })
                        Message = $want.Message
                    }
                }
            }

            $missingUsers  = @($want.Users  | Where-Object { $assignedUsers  -notcontains $_ } | Select-Object -Unique)
            $missingGroups = @($want.Groups | Where-Object { $assignedGroups -notcontains $_ } | Select-Object -Unique)

            # How many of those direct user assignments are just the membership of the
            # groups going on at the same time. A direct assignment outlives the group -
            # take someone out of the group and they keep the access - so writing hundreds
            # of thousands of them by accident is a mess that is hard to unpick later.
            $stat.RedundantUsers += (Get-VaultRedundantUserCount -Directory $dir -Groups $want.Groups -Users $missingUsers)

            if ($Assign -eq 'Groups') { $missingUsers  = @() }
            if ($Assign -eq 'Users')  { $missingGroups = @() }

            $row = [pscustomobject][ordered]@{
                Key = "$docId`:$name"; DocId = $docId; SourceDocId = $doc.SourceId
                # The facts this row's decision rested on. Recorded so veeva-validate.ps1
                # can confirm the premises later without re-running the reasoning.
                Lifecycle = $(if ($info) { $info.Lifecycle } else { '' })
                Type      = $(if ($info) { $info.Type }      else { '' })
                Subtype   = $(if ($info) { $info.Subtype }   else { '' })
                Role = $name; RoleLabel = $label
                RuleApplied = $want.Which; RuleDetail = $want.Message
                AssignedUsers  = ($assignedUsers  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                AssignedGroups = ($assignedGroups | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                MissingUsers   = ($missingUsers   | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                MissingGroups  = ($missingGroups  | ForEach-Object { Get-VaultDisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                Status = ''; Message = ''
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            }

            # A role whose rule could not be chosen is NOT the same as a role with nothing
            # to do, and must not be reported as in step. Nothing is written for it, and
            # it is counted as an error so the run's exit code is non-zero and the summary
            # says the figures are incomplete.
            if ($want.Which -in @('AMBIGUOUS_OVERRIDE', 'DOCUMENT_UNREADABLE', 'NO_LIFECYCLE', 'NO_DEFAULT_RULE')) {
                $row.Status  = 'UNRESOLVED'
                $row.Message = $want.Message
                $stat.Errors++
                Write-VaultLog "$prefix  $name  - $($want.Which): $($want.Message)" 'ERROR'
                [void]$res.Rows.Add($row)
                continue
            }

            if (-not $missingUsers.Count -and -not $missingGroups.Count) {
                $row.Status = 'IN_STEP'
                [void]$res.Rows.Add($row)
                continue
            }

            $docNeedsWork = $true
            $stat.Users  += $missingUsers.Count
            $stat.Groups += $missingGroups.Count

            $parts = @()
            if ($missingUsers.Count)  { $parts += "users $($row.MissingUsers)" }
            if ($missingGroups.Count) { $parts += "groups $($row.MissingGroups)" }
            [void]$summary.Add("$label ($($parts -join ', '))")
            # "needs", not "+". This line is printed when the gap is WORKED OUT, and the
            # write happens on the next batch flush - up to BatchSize documents later. A
            # line reading like an action, an hour before Vault has seen it, sent someone
            # to check a document in the UI and find nothing there. The confirmation is
            # the separate "assigned" line from Submit-Pending.
            Write-VaultLog "$prefix  $name  needs $($parts -join ' + ')"

            if ($missingUsers.Count)  { $cells["$name.users"]  = $missingUsers }
            if ($missingGroups.Count) { $cells["$name.groups"] = $missingGroups }

            $row.Status = if ($Plan) { 'WOULD_ASSIGN' } elseif ($c.WhatIf) { 'WHATIF' } else { 'PENDING' }
            [void]$rows.Add($row)
        }

        if (-not $docNeedsWork) {
            $stat.InStep++
        # Saved on a cadence, never per document. Save-VaultResults rewrites the WHOLE file,
        # so a save per document is quadratic: a verification pass, where every document
        # is in step, would rewrite a 110,000-row file 15,752 times. The point of saving
        # often is that an interrupted run leaves a usable file, and one save per batch
        # keeps that while costing a bounded amount.
            if (($i % $BatchSize) -eq 0) { Save-VaultResults -Results $res }
            continue
        }
        $stat.NeedWork++

        if ($Plan -or $c.WhatIf) {
            foreach ($row in $rows) { [void]$res.Rows.Add($row) }
            if (($i % $BatchSize) -eq 0) { Save-VaultResults -Results $res }
        }
        else {
            [void]$pending.Add([pscustomobject]@{
                DocId = $docId; Cells = $cells; Rows = @($rows); Summary = ($summary -join '; ')
            })
            if ($pending.Count -ge $BatchSize) { Submit-Pending }
        }

        if ($Test -gt 0) {
            $done = if ($Plan -or $c.WhatIf) { $stat.NeedWork } else { $stat.Changed + $pending.Count }
            if ($done -ge $Test) {
                Write-VaultLog "TEST: $done document(s) after examining $i - stopping" 'OK'
                $stopped = $true
                break documents
            }
        }
    }

    Submit-Pending
    Save-VaultResults -Results $res

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog ("examined {0}   already in step {1}   needing work {2}   no roles {3}" -f `
               $stat.Docs, $stat.InStep, $stat.NeedWork, $stat.NoRoles)
    if ($Plan -or $c.WhatIf) {
        $what = if ($Plan) { 'PLAN' } else { 'WhatIf' }
        Write-VaultLog "$what only - nothing was assigned. $($stat.Users) user and $($stat.Groups) group assignment(s) would be." 'OK'
        if ($stat.RedundantUsers -gt 0 -and $Assign -ne 'Groups') {
            Write-VaultLog ''
            Write-VaultLog "$($stat.RedundantUsers) of those $($stat.Users) user assignment(s) are people who are ALREADY" 'WARN'
            Write-VaultLog 'members of a group being assigned on the same document. Assigning them directly as' 'WARN'
            Write-VaultLog 'well outlives the group - take someone out of the group later and they keep the' 'WARN'
            Write-VaultLog 'access, because the direct assignment is still there. -Assign Groups writes only the' 'WARN'
            Write-VaultLog 'groups and leaves membership to do its job.' 'WARN'
        }
        # Errors are reported in every mode. A plan that could not read half the documents
        # is not a plan, and saying only "0 would be assigned" reads as good news rather
        # than as a run that never got off the ground.
        if ($stat.Errors) { Write-VaultLog "$($stat.Errors) document(s) could not be read - the figures above are incomplete" 'ERROR' }
    }
    else {
        Write-VaultLog ("Assigned on {0} document(s): {1} user and {2} group assignment(s). {3} failed." -f `
                   $stat.Changed, $stat.Users, $stat.Groups, $stat.Errors) $(if ($stat.Errors) { 'WARN' } else { 'OK' })
    }
    if ($stopped) { Write-VaultLog "TEST run - stopped after $i of $($docs.Count) document(s). NOT the whole set." 'WARN' }
    Write-VaultLog "Results: $($res.Path)"
    return $stat.Errors
}

function Get-VaultFoldedName {
    # Written independently of veeva-roles.ps1's ConvertTo-NameKey, and tested against the
    # same cases, because a shared folding bug would silently make both tools agree on the
    # wrong answer. Same contract: drop a trailing __c/__v/__sys, keep letters and digits,
    # lower case.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $s = $Value.Trim()
    foreach ($suffix in @('__c', '__v', '__sys')) {
        if ($s.EndsWith($suffix)) { $s = $s.Substring(0, $s.Length - $suffix.Length); break }
    }
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        if ([char]::IsLetterOrDigit($ch)) { [void]$sb.Append([char]::ToLowerInvariant($ch)) }
    }
    return $sb.ToString()
}




#
#  Built here rather than shared, and only groups are needed - this checks group
#  assignments, which is what -Assign Groups writes.
# ======================================================================================

function Get-VaultGroupIndex {
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion)
    $byName = @{}
    $byId   = @{}
    $r = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path '/objects/groups'
    foreach ($rec in @(Get-VaultField $r 'groups' @())) {
        $g = Get-VaultField $rec 'group' $null
        if ($null -eq $g) { $g = $rec }
        $id = "$(Get-VaultField $g 'id' '')"
        if (-not $id) { continue }
        foreach ($f in @('label__v', 'name__v')) {
            $n = "$(Get-VaultField $g $f '')"
            if (-not $n) { continue }
            $k = Get-VaultFoldedName $n
            if ($k -and -not $byName.ContainsKey($k)) { $byName[$k] = $id }
            if (-not $byId.ContainsKey($id)) { $byId[$id] = $n }
        }
    }
    Write-VaultLog "$($byId.Count) group(s) in this vault"
    return [pscustomobject]@{ ByName = $byName; ById = $byId }
}


# ======================================================================================
#  Current state, read through doc_role__sys
# ======================================================================================

function Get-VaultCurrentGroups {
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][array]$DocIds,
        # One document at a time instead of the bulk read, for a vault where the bulk
        # query is unavailable or disagrees with itself.
        [switch]$Slow
    )

    $byKey = @{}
    $bulk  = -not $Slow

    if ($bulk) {
        $chunk = 200
        for ($off = 0; $off -lt $DocIds.Count; $off += $chunk) {
            $slice = @($DocIds[$off..([math]::Min($off + $chunk - 1, $DocIds.Count - 1))])
            $vql = "SELECT document_id, role_name__sys, group__sys FROM doc_role__sys WHERE document_id CONTAINS ($($slice -join ','))"
            $path = '/query'
            $body = "q=$([Uri]::EscapeDataString($vql))"
            $pages = 0
            try {
                while ($path -and $pages -lt 500) {
                    $pages++
                    $r = if ($pages -eq 1) {
                            Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method POST -Path $path -Body $body `
                                -ContentType 'application/x-www-form-urlencoded' -MaxRetries 1
                         } else {
                            Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path $path -MaxRetries 1
                         }
                    foreach ($row in @(Get-VaultField $r 'data' @())) {
                        $d = "$(Get-VaultField $row 'document_id' '')"
                        $n = "$(Get-VaultField $row 'role_name__sys' '')"
                        $g = "$(Get-VaultField $row 'group__sys' '')"
                        if (-not $d -or -not $n -or -not $g) { continue }
                        $k = "$d|$(Get-VaultFoldedName $n)"
                        if (-not $byKey.ContainsKey($k)) { $byKey[$k] = @{} }
                        $byKey[$k][$g] = $true
                    }
                    $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
                }
            }
            catch {
                Write-VaultLog "doc_role__sys will not take that query, falling back to one read per document: $_" 'WARN'
                $bulk = $false
                break
            }
            Write-VaultLog "  read $([math]::Min($off + $chunk, $DocIds.Count)) of $($DocIds.Count)"
        }
    }

    if ($bulk) { return [pscustomobject]@{ ByKey = $byKey; Method = 'doc_role__sys (bulk)' } }

    # Fallback. Still not the same call the assign run made for its comparison - it reads
    # the roles endpoint, which is at least a different query - but the point of the bulk
    # path is that it is a genuinely separate route, so a fallback is worth saying out loud.
    $byKey = @{}
    $i = 0
    foreach ($docId in $DocIds) {
        $i++
        if (($i % 500) -eq 0) { Write-VaultLog "  read $i of $($DocIds.Count)" }
        try {
            $r = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path "/objects/documents/$docId/roles"
            foreach ($role in @(Get-VaultField $r 'documentRoles' @())) {
                $n = "$(Get-VaultField $role 'name' '')"
                if (-not $n) { continue }
                $k = "$docId|$(Get-VaultFoldedName $n)"
                if (-not $byKey.ContainsKey($k)) { $byKey[$k] = @{} }
                foreach ($g in @(Get-VaultField $role 'assignedGroups' @())) { $byKey[$k]["$g"] = $true }
            }
        }
        catch { Write-VaultLog "  could not read document ${docId}: $_" 'ERROR' }
    }
    return [pscustomobject]@{ ByKey = $byKey; Method = 'one read per document' }
}


function Get-VaultCurrentFacts {
    # type, subtype and lifecycle for a set of documents, in bulk.
    #
    # These are the INPUTS the run's decision rested on: the lifecycle picks the rule, the
    # type and subtype pick the MDL component. Confirming them checks the premises without
    # re-running the reasoning - which is the line this tool tries to hold. Re-deriving
    # what SHOULD be on a document would just be the same logic agreeing with itself.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion, [Parameter(Mandatory)][array]$DocIds)

    $byId  = @{}
    $chunk = 200
    for ($off = 0; $off -lt $DocIds.Count; $off += $chunk) {
        $slice = @($DocIds[$off..([math]::Min($off + $chunk - 1, $DocIds.Count - 1))])
        $vql = "SELECT id, type__v, subtype__v, lifecycle__v FROM documents WHERE id CONTAINS ($($slice -join ','))"
        $path = '/query'
        $body = "q=$([Uri]::EscapeDataString($vql))"
        $pages = 0
        try {
            while ($path -and $pages -lt 500) {
                $pages++
                $r = if ($pages -eq 1) {
                        Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method POST -Path $path -Body $body `
                            -ContentType 'application/x-www-form-urlencoded' -MaxRetries 1
                     } else {
                        Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path $path -MaxRetries 1
                     }
                foreach ($row in @(Get-VaultField $r 'data' @())) {
                    $id = "$(Get-VaultField $row 'id' '')"
                    if (-not $id) { continue }
                    $sub = "$(Get-VaultField $row 'subtype__v' '')"
                    $ty  = "$(Get-VaultField $row 'type__v' '')"
                    if (-not $sub) { $sub = $ty }
                    $byId[$id] = [pscustomobject]@{ Type = $ty; Subtype = $sub; Lifecycle = "$(Get-VaultField $row 'lifecycle__v' '')" }
                }
                $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
            }
        }
        catch {
            Write-VaultLog "Could not read document facts, so type and lifecycle go unchecked: $_" 'WARN'
            return @{}
        }
    }
    return $byId
}
# --------------------------------------------------------------------------------------
# The validator
#
# Proves that what a run RECORDED as assigned is actually on the documents. It does not
# work out what ought to be there - re-deriving that would be the same logic agreeing
# with itself, which proves nothing. It reads the claims out of the results file and
# checks them against the vault, along with the facts the run's decision rested on.
#
# A separate command, run when someone chooses to. Vault ignores group ids it cannot
# grant and still answers SUCCESS, so a run can report an assignment it did not make -
# which is exactly the failure this exists to find, and re-running the assign will not
# fix it.
# --------------------------------------------------------------------------------------

function Invoke-VaultRolesVerify {
    param(
        [Parameter(Mandatory)]$Context,
        [string]$ResultsFile = '',
        [switch]$Slow,
        [int]$Limit = 0,
        # The documents that were SUPPOSED to be done. Without it this reports how many
        # of its own claims held up, which is true and is not the question anyone is
        # asking - "14,928 confirmed" against an unstated denominator is a number, not
        # evidence.
        [string]$ExpectIds = ''
    )
    $c = $Context

    $path = $ResultsFile
    if (-not $path) { $path = Join-Path $c.Out 'role-results.csv' }
    if (-not (Test-Path -LiteralPath $path)) {
        throw "No results file at $path. This checks what a run RECORDED; without one there is nothing to check."
    }
    Write-VaultLog "  results  $path"

    $rows = @(Import-Csv -LiteralPath $path)
    $statuses = @{}
    $claims = New-Object System.Collections.ArrayList
    foreach ($row in $rows) {
        $st = "$(Get-VaultField $row 'Status' '')"
        if ($st) { $statuses[$st] = 1 + $(if ($statuses.ContainsKey($st)) { $statuses[$st] } else { 0 }) }
        if ($st -ne 'ASSIGNED') { continue }
        $groups = "$(Get-VaultField $row 'MissingGroups' '')"
        if (-not $groups) { continue }
        [void]$claims.Add([pscustomobject]@{
            DocId     = "$(Get-VaultField $row 'DocId' '')"
            Role      = "$(Get-VaultField $row 'Role' '')"
            Lifecycle = "$(Get-VaultField $row 'Lifecycle' '')"
            Type      = "$(Get-VaultField $row 'Type' '')"
            Subtype   = "$(Get-VaultField $row 'Subtype' '')"
            Groups    = @($groups -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        })
    }
    Write-VaultLog "$($rows.Count) row(s): $((($statuses.Keys | Sort-Object) | ForEach-Object { "$_=$($statuses[$_])" }) -join ', ')"

    if (-not $claims.Count) {
        Write-VaultLog 'No ASSIGNED rows carrying groups. Nothing was claimed, so there is nothing to prove.' 'WARN'
        return 0
    }

    $docIds = @($claims | ForEach-Object { $_.DocId } | Select-Object -Unique)

    # Trimmed by DOCUMENT, then the claims are filtered to match - not the other way
    # round. Cutting the claim list first would leave a document half-checked, and a
    # document that is partly verified is the one thing worse than one that is not.
    if ($Limit -gt 0 -and $docIds.Count -gt $Limit) {
        Write-VaultLog "-n $Limit - checking the first $Limit of $($docIds.Count) document(s)" 'WARN'
        $docIds = @($docIds | Select-Object -First $Limit)
        $keep   = @{}
        foreach ($d in $docIds) { $keep[$d] = $true }
        $claims = @($claims | Where-Object { $keep.ContainsKey($_.DocId) })
    }

    Write-VaultLog "$($claims.Count) claim(s) over $($docIds.Count) document(s)"

    $groups  = Get-VaultGroupIndex -VaultHost $c.VaultHost -ApiVersion $c.Api
    $current = Get-VaultCurrentGroups -VaultHost $c.VaultHost -ApiVersion $c.Api -DocIds $docIds -Slow:$Slow
    $facts   = Get-VaultCurrentFacts  -VaultHost $c.VaultHost -ApiVersion $c.Api -DocIds $docIds

    # One row per DOCUMENT, not per claim. A claim-level file for this scope runs to
    # hundreds of thousands of rows that nobody can scan; a document is the thing you
    # filter to a work list and then go and open in the UI. The detail is not lost - the
    # groups that failed are named in the row.
    $byDoc = @{}
    foreach ($claim in $claims) {
        if (-not $byDoc.ContainsKey($claim.DocId)) { $byDoc[$claim.DocId] = New-Object System.Collections.ArrayList }
        [void]$byDoc[$claim.DocId].Add($claim)
    }

    $out  = New-Object System.Collections.ArrayList
    $stat = @{ Documents = 0; Clean = 0; Missing = 0; Unresolved = 0
               LifecycleMismatch = 0; TypeMismatch = 0; NotChecked = 0
               ClaimsConfirmed = 0; ClaimsMissing = 0 }

    foreach ($docId in ($byDoc.Keys | Sort-Object)) {
        $stat.Documents++
        $docClaims = @($byDoc[$docId])

        $confirmed = 0
        $missing   = New-Object System.Collections.ArrayList
        $unres     = New-Object System.Collections.ArrayList
        $roles     = New-Object System.Collections.ArrayList

        foreach ($claim in $docClaims) {
            if ($roles -notcontains $claim.Role) { [void]$roles.Add($claim.Role) }
            $k    = "$docId|$(Get-VaultFoldedName $claim.Role)"
            $have = if ($current.ByKey.ContainsKey($k)) { $current.ByKey[$k] } else { @{} }
            foreach ($gName in $claim.Groups) {
                $gid = ''
                $fk  = Get-VaultFoldedName $gName
                if ($groups.ByName.ContainsKey($fk)) { $gid = $groups.ByName[$fk] }
                elseif ($gName -match '^\d+$')       { $gid = $gName }

                if (-not $gid)                   { [void]$unres.Add("$($claim.Role): $gName") }
                elseif ($have.ContainsKey($gid)) { $confirmed++ }
                else                             { [void]$missing.Add("$($claim.Role): $gName") }
            }
        }
        $stat.ClaimsConfirmed += $confirmed
        $stat.ClaimsMissing   += $missing.Count
        if ($unres.Count) { $stat.Unresolved++ }

        # The dimensions the run's decision rested on. Blank where the run did not record
        # them - older results files carry no Type or Subtype - which is reported as
        # NOT_RECORDED rather than quietly passing.
        $recLc  = "$($docClaims[0].Lifecycle)"
        $recTy  = "$($docClaims[0].Type)"
        $recSub = "$($docClaims[0].Subtype)"
        $now    = if ($facts.ContainsKey($docId)) { $facts[$docId] } else { $null }

        function Compare-Dimension {
            param([string]$Recorded, $Now, [string]$Field)
            if (-not $Recorded)  { return 'NOT_RECORDED' }
            if ($null -eq $Now)  { return 'NOT_CHECKED' }
            $current = "$(Get-VaultField $Now $Field '')"
            if (-not $current)   { return 'NOT_CHECKED' }
            if ((Get-VaultFoldedName $Recorded) -eq (Get-VaultFoldedName $current)) { return 'CONFIRMED' }
            return 'CHANGED'
        }

        $lcState  = Compare-Dimension -Recorded $recLc  -Now $now -Field 'Lifecycle'
        $tyState  = Compare-Dimension -Recorded $recTy  -Now $now -Field 'Type'
        $subState = Compare-Dimension -Recorded $recSub -Now $now -Field 'Subtype'

        if ($lcState -eq 'CHANGED') { $stat.LifecycleMismatch++ }
        if ($tyState -eq 'CHANGED' -or $subState -eq 'CHANGED') { $stat.TypeMismatch++ }
        if ($lcState -eq 'NOT_CHECKED') { $stat.NotChecked++ }

        $status =
            if ($missing.Count)                                  { $stat.Missing++; 'GROUPS_MISSING' }
            elseif ($lcState -eq 'CHANGED' -or $tyState -eq 'CHANGED' -or $subState -eq 'CHANGED') { 'DIMENSION_CHANGED' }
            elseif ($unres.Count)                                { 'NAMES_UNRESOLVED' }
            else                                                 { $stat.Clean++; 'CONFIRMED' }

        if ($status -ne 'CONFIRMED') {
            $why = if ($missing.Count) { ($missing | Select-Object -First 4) -join '; ' }
                   elseif ($unres.Count) { ($unres | Select-Object -First 4) -join '; ' }
                   else { "lifecycle $lcState, type $tyState, subtype $subState" }
            Write-VaultLog "  doc $docId - $status : $why" $(if ($status -eq 'GROUPS_MISSING') { 'ERROR' } else { 'WARN' })
        }

        [void]$out.Add([pscustomobject][ordered]@{
            DocId = $docId
            Status = $status
            RolesChecked = $roles.Count
            GroupsClaimed = $confirmed + $missing.Count + $unres.Count
            GroupsConfirmed = $confirmed
            GroupsMissing = $missing.Count
            MissingDetail = ($missing -join '; ')
            UnresolvedDetail = ($unres -join '; ')
            LifecycleRecorded = $recLc
            LifecycleNow = $(if ($now) { $now.Lifecycle } else { '' })
            LifecycleCheck = $lcState
            TypeRecorded = $recTy
            TypeNow = $(if ($now) { $now.Type } else { '' })
            TypeCheck = $tyState
            SubtypeRecorded = $recSub
            SubtypeNow = $(if ($now) { $now.Subtype } else { '' })
            SubtypeCheck = $subState
            CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
        })
    }

    $report = Join-Path $c.Out 'role-validate-results.csv'
    $out | Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($stat.Documents) document(s) checked, assignments read by $($current.Method)"
    Write-VaultLog ("  CONFIRMED           {0}" -f $stat.Clean) 'OK'
    if ($stat.Missing) {
        Write-VaultLog ("  GROUPS_MISSING      {0}  ({1} group assignment(s))" -f $stat.Missing, $stat.ClaimsMissing) 'ERROR'
        Write-VaultLog '  The run recorded these as assigned and the vault does not have them. Vault' 'ERROR'
        Write-VaultLog '  ignores ids it cannot grant and still reports SUCCESS, so re-running will not' 'ERROR'
        Write-VaultLog '  fix it. Check whether the account may grant those groups.' 'ERROR'
    }
    if ($stat.LifecycleMismatch) {
        Write-VaultLog ("  lifecycle changed   {0}  - not what the run saw, so its rule choice no longer holds" -f $stat.LifecycleMismatch) 'WARN'
    }
    if ($stat.TypeMismatch) {
        Write-VaultLog ("  type/subtype changed {0} - the run picked its type defaults from a different one" -f $stat.TypeMismatch) 'WARN'
    }
    if ($stat.Unresolved) {
        Write-VaultLog ("  NAMES_UNRESOLVED    {0}  - recorded under a name no group here answers to" -f $stat.Unresolved) 'WARN'
    }
    if ($stat.NotChecked) {
        Write-VaultLog ("  dimensions unchecked {0} - the document facts could not be read" -f $stat.NotChecked) 'WARN'
    }
    Write-VaultLog ("  {0} group assignment(s) confirmed in total" -f $stat.ClaimsConfirmed)
    if ($out.Count -and -not $out[0].TypeRecorded) {
        Write-VaultLog 'Type and subtype were NOT_RECORDED - this results file predates the run recording them.' 'WARN'
    }
    if (-not $stat.Missing -and -not $stat.Unresolved -and -not $stat.LifecycleMismatch -and -not $stat.TypeMismatch) {
        Write-VaultLog 'Every group the run recorded as assigned is on its document, on the facts it decided from.' 'OK'
    }
    Write-VaultLog "Report: $report"

    Write-VaultLog "Report: $report"

    # Every expected document in exactly one bucket, and the buckets that should be
    # empty named even when they are. Three different things were invisible in a bare
    # confirmed count: a document already correct and so never claimed, one that failed,
    # and one that was never processed at all. The first is fine and the other two are
    # not, and they looked identical.
    $unprocessed = 0
    if ($ExpectIds) {
        $expected = @(Import-VaultIdList -Path $ExpectIds)

        # What the results file knows about each expected document, whether or not this
        # verify had a claim to check.
        $seen   = @{}
        $failed = @{}
        foreach ($row in $rows) {
            $d = "$(Get-VaultField $row 'DocId' '')"
            if (-not $d) { continue }
            $seen[$d] = $true
            if ("$(Get-VaultField $row 'Status' '')" -in @('ERROR', 'UNRESOLVED')) { $failed[$d] = $true }
        }
        $claimed = @{}
        foreach ($cl in $claims) { $claimed["$($cl.DocId)"] = $true }

        $bChecked = @($expected | Where-Object { $claimed.ContainsKey("$_") }).Count
        $bFailed  = @($expected | Where-Object { $failed.ContainsKey("$_") -and -not $claimed.ContainsKey("$_") }).Count
        $bQuiet   = @($expected | Where-Object { $seen.ContainsKey("$_") -and -not $claimed.ContainsKey("$_") -and -not $failed.ContainsKey("$_") }).Count
        $missingIds = @($expected | Where-Object { -not $seen.ContainsKey("$_") })
        $unprocessed = $missingIds.Count

        Write-VaultLog '----------------------------------------------------------------'
        Write-VaultLog ("expected                      {0,7}   from $ExpectIds" -f $expected.Count)
        Write-VaultLog ("checked and CONFIRMED         {0,7}" -f ($bChecked - $stat.Missing - $stat.Unresolved)) 'OK'
        if ($stat.Missing -or $stat.Unresolved) {
            Write-VaultLog ("checked and NOT confirmed     {0,7}   the vault does not have them" -f ($stat.Missing + $stat.Unresolved)) 'ERROR'
        }
        Write-VaultLog ("in results, nothing claimed   {0,7}   already correct - nothing to verify" -f $bQuiet)
        if ($bFailed) { Write-VaultLog ("in results, failed            {0,7}   ERROR or UNRESOLVED" -f $bFailed) 'ERROR' }
        if ($unprocessed) {
            Write-VaultLog ("no record at all              {0,7}   NEVER PROCESSED" -f $unprocessed) 'ERROR'
            foreach ($line in (Format-VaultIdRows -Ids $missingIds)) { Write-VaultLog "  $line" 'ERROR' }
        }
        else {
            Write-VaultLog ("no record at all              {0,7}" -f 0) 'OK'
        }

        if (-not $unprocessed -and -not $bFailed -and -not $stat.Missing -and -not $stat.Unresolved) {
            Write-VaultLog 'Every expected document is accounted for, and everything claimed is on its document.' 'OK'
        }
    }
    else {
        Write-VaultLog 'No -ExpectIds given, so this says how many of its own claims held up and nothing about coverage.' 'WARN'
    }

    return ($stat.Missing + $unprocessed)
}

# --------------------------------------------------------------------------------------
# Scoping a permission sync
#
# A run that grants people access should never be able to reach further than it was told
# to. So the sync names WHOSE documents and HOW RECENT, both, every time - and the two
# together are a far tighter bound than either alone: one operator's work, in one window.
# --------------------------------------------------------------------------------------

function Get-VaultCreatedByScope {
    # The documents a named user created within the last N hours.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$CreatedBy,
        [Parameter(Mandatory)][int]$WithinHours,
        # Only needed to turn a NAME into an id. A numeric id needs nothing, and the
        # directory is every user and group in the vault - pages of calls against the
        # same burst allowance the run needs, spent on a lookup that was already done.
        [AllowNull()]$Directory,
        # Confirmed against endo-rim with `verify fields`, not taken from documentation:
        # document_creation_date__v is a DateTime and queryable, which is what makes an
        # hours-wide window expressible at all. created_date__v - which this used at
        # first - is a field on OBJECTS and does not exist on documents, and the vault
        # said so: "Unknown field 'created_date__v' in 'where clause'".
        [string]$DateField = 'document_creation_date__v',
        # An ObjectReference, which VQL compares by id.
        [string]$CreatorField = 'created_by__v'
    )
    # created_by__v holds a user ID, not a name - so a name has to be resolved, and a
    # name that resolves to nothing must stop the run. Falling back to "everyone" here
    # would turn the narrowest possible scope into the widest.
    if ($CreatedBy -match '^(?i)me$') {
        # The account doing the repair is usually the account that created the documents,
        # because both are the migration's own service user. Asking Vault who that is
        # costs one call and removes the step where somebody types the wrong id - which
        # would not fail, it would quietly repair somebody else's documents.
        $me = Get-VaultWhoAmI -VaultHost $Context.VaultHost -ApiVersion $Context.Api
        if (-not $me -or -not $me.UserId) {
            throw 'Could not ask the vault who this session belongs to, so -CreatedBy me cannot be resolved. Pass the numeric user id.'
        }
        $uid = $me.UserId
        $who = "$($me.User) (this session)"
    }
    elseif ($CreatedBy -match '^\d+$') {
        $uid = $CreatedBy
        $who = "user id $uid"
    }
    elseif (-not $Directory) {
        throw "'$CreatedBy' is not a user id or 'me', so it has to be looked up - and no directory was read. Pass the numeric id, or 'me' for this session's own user."
    }
    else {
        $uid = Resolve-VaultNameToId -Directory $Directory -Kind 'user' -Name $CreatedBy
        if (-not $uid) {
            throw "No user in this vault answers to '$CreatedBy'. created_by__v holds a user id, so the name has to resolve to one - check the spelling, or pass the id."
        }
        $who = Get-VaultDisplayName -Directory $Directory -Kind 'user' -Id $uid
    }

    # Hours before NOW, in UTC, because that is what Vault stores and compares against.
    # Both are logged: an operator reads the local time, and the query uses the other.
    $cutUtc   = (Get-Date).ToUniversalTime().AddHours(-1 * $WithinHours)
    $iso      = $cutUtc.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    $cutLocal = $cutUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')

    Write-VaultLog "Scope: documents created by $who (id $uid)"
    Write-VaultLog "       in the last $WithinHours hour(s) - since $cutLocal local / $iso"
    Write-VaultLog "       matching on $CreatorField and $DateField"

    $vql = "SELECT id FROM documents WHERE $CreatorField = $uid AND $DateField > '$iso'"
    $docs = @(Get-VaultDocumentsByQuery -Context $Context -Where $vql)
    Write-VaultLog "$($docs.Count) document(s) match both conditions" 'OK'

    # A window wider than intended is the way this scope goes wrong, and it goes wrong
    # quietly - the run simply touches more than anyone meant. Said out loud rather than
    # left to be noticed in the results.
    if ($docs.Count -gt 5000) {
        Write-VaultLog "That is a lot for a $WithinHours hour window. Check the hours before letting this write." 'WARN'
    }
    return $docs
}

function Write-VaultScopeManifest {
    # Exactly which documents a scope resolved to, on screen and on disk.
    #
    # A count is not a check. "412 documents matched" is equally consistent with the
    # right filter and with a wrong one, and the only way to tell is to look at the ids -
    # so the ids are written every time, before anything is read or changed, and a sample
    # goes to the log where somebody will actually see it.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Documents,
        [Parameter(Mandatory)][string]$Path,
        [int]$Show = 20
    )
    $rows = New-Object System.Collections.ArrayList
    foreach ($d in $Documents) {
        [void]$rows.Add([pscustomobject]@{
            TargetId = "$(Get-VaultField $d 'TargetId' '')"
            SourceId = "$(Get-VaultField $d 'SourceId' '')"
        })
    }
    $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    # The scope itself IS sampled on screen - fifteen thousand ids scrolling past tells
    # nobody anything, and every one of them is in the file. The DIFFERENCES are the ones
    # printed in full, because those are what somebody has to act on.
    $ids = @($rows | ForEach-Object { $_.TargetId })
    Write-VaultLog "Target ids in scope ($($ids.Count)):"
    foreach ($line in (Format-VaultIdRows -Ids @($ids | Select-Object -First $Show))) { Write-VaultLog "  $line" }
    if ($ids.Count -gt $Show) { Write-VaultLog "  ... and $($ids.Count - $Show) more - all of them are in the file below" }
    Write-VaultLog "Scope written to $Path" 'OK'
    return $Path
}

function Format-VaultIdRows {
    # Ids in readable rows rather than one enormous line or one line each.
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$Ids, [int]$PerRow = 10)
    $out = New-Object System.Collections.ArrayList
    $all = @($Ids)
    for ($i = 0; $i -lt $all.Count; $i += $PerRow) {
        [void]$out.Add(($all[$i..([math]::Min($i + $PerRow - 1, $all.Count - 1))] -join ' '))
    }
    return @($out)
}

function Compare-VaultScopeToList {
    # Does the query return exactly the documents somebody expected?
    #
    # A count agreeing proves nothing: 412 from the query and 412 in the list can still
    # be 412 DIFFERENT documents. This compares the sets, and reports both directions,
    # because they mean opposite things - an id in the list the query missed says the
    # filter is too narrow, and one the query found that is not in the list says it is
    # too wide. Either is worth knowing before anything is granted.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Documents,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$OutPath,
        [int]$Show = 20
    )
    # One id per line, and tolerant of a header, blanks, quotes and repeats - the same
    # reader the document workflows use, so a list that works there works here.
    $expected = @(Import-VaultIdList -Path $Path)

    $got = @{}; $src = @{}
    foreach ($d in $Documents) {
        $t = "$(Get-VaultField $d 'TargetId' '')"; if ($t) { $got[$t] = $true }
        $s = "$(Get-VaultField $d 'SourceId' '')"; if ($s) { $src[$s] = $true }
    }
    $want = @{}
    foreach ($e in $expected) { $want["$e"] = $true }

    $matched = @($expected | Where-Object { $got.ContainsKey("$_") })
    $missing = @($expected | Where-Object { -not $got.ContainsKey("$_") })
    $extra   = @($got.Keys | Where-Object { -not $want.ContainsKey("$_") })

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "Reconciling the query against $($expected.Count) expected id(s)"
    Write-VaultLog ("  in both              {0}" -f $matched.Count) $(if ($matched.Count) { 'OK' } else { 'WARN' })
    # Every one of them on screen, not a sample. A file is where you go afterwards; the
    # question in front of somebody watching a run is "which documents", and answering it
    # with the first ten and a count makes them go and open a file to find out.
    if ($missing.Count) {
        Write-VaultLog ("  expected, not found  {0}  - the filter is narrower than the list" -f $missing.Count) 'ERROR'
        foreach ($line in (Format-VaultIdRows -Ids $missing)) { Write-VaultLog "    $line" 'ERROR' }
    }
    if ($extra.Count) {
        Write-VaultLog ("  found, not expected  {0}  - the filter is wider than the list" -f $extra.Count) 'ERROR'
        foreach ($line in (Format-VaultIdRows -Ids $extra)) { Write-VaultLog "    $line" 'ERROR' }
    }

    # The mistake this catches before it wastes anyone's afternoon: a list of SOURCE ids
    # compared against target ids matches nothing at all, which reads as a catastrophically
    # wrong filter rather than as the wrong column.
    if (-not $matched.Count -and $expected.Count -and $src.Count) {
        $asSource = @($expected | Where-Object { $src.ContainsKey("$_") }).Count
        if ($asSource) {
            Write-VaultLog "$asSource of them match the SOURCE ids instead. That list looks like source document ids, not target." 'WARN'
        }
    }

    # Only the differences. A file holding fifteen thousand rows that agree, with the
    # eleven that do not somewhere among them, is a file nobody reads - and the rows that
    # agree are already recorded in the scope manifest. This one is the work list.
    $rows = New-Object System.Collections.ArrayList
    foreach ($e in $missing) {
        [void]$rows.Add([pscustomobject]@{ Id = "$e"; Verdict = 'EXPECTED_NOT_FOUND'
                                           Means = 'in the list, not returned by the filter' })
    }
    foreach ($g in $extra) {
        [void]$rows.Add([pscustomobject]@{ Id = "$g"; Verdict = 'FOUND_NOT_EXPECTED'
                                           Means = 'returned by the filter, not in the list' })
    }
    if ($rows.Count) {
        (ConvertTo-VaultUniformRows -Rows $rows) |
            Export-Csv -LiteralPath $OutPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false
        Write-VaultLog "$($rows.Count) difference(s) written to $OutPath - that file is the work list" 'ERROR'
    }
    else {
        # Written even when empty: "we reconciled and found nothing" is a result worth
        # having on disk, and an absent file cannot be told from a check nobody ran.
        'Id,Verdict,Means' | Set-Content -LiteralPath $OutPath -Encoding UTF8 -WhatIf:$false
        Write-VaultLog "No differences. Empty reconciliation written to $OutPath"
    }

    if (-not $missing.Count -and -not $extra.Count) {
        Write-VaultLog 'The query returns exactly the expected documents.' 'OK'
    }
    return ($missing.Count + $extra.Count)
}

function Select-VaultScopeIntersection {
    # Where a map is also configured, take only what is in BOTH.
    #
    # The map says what the migration produced; the query says what this person made
    # recently. A document in one and not the other is not something to guess about, and
    # the intersection is the only reading that cannot reach further than either.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Documents,
        [Parameter(Mandatory)]$Map
    )
    # target id -> source id, so the intersection can carry the source through.
    $known = @{}
    foreach ($k in $Map.Keys) { $known["$($Map[$k])"] = "$k" }

    # TargetId, not id: the query hands back {TargetId, SourceId}, which is the shape the
    # rest of the roles flow reads. Matching on 'id' found nothing and quietly assigned
    # nothing - an empty intersection looks exactly like "there was no work to do".
    $keep = New-Object System.Collections.ArrayList
    foreach ($d in $Documents) {
        $id = "$(Get-VaultField $d 'TargetId' '')"
        if (-not $id -or -not $known.ContainsKey($id)) { continue }
        # The map knows which source document this came from; the query does not. Filling
        # it in here means the results file can say what a repaired document used to be.
        [void]$keep.Add([pscustomobject]@{ TargetId = $id; SourceId = "$($known[$id])" })
    }
    $dropped = $Documents.Count - $keep.Count
    Write-VaultLog "$($Documents.Count) from the query, $($known.Count) in the map, $($keep.Count) in both"
    if ($dropped) {
        Write-VaultLog "$dropped document(s) matched the user and window but are not in the map - not touched" 'WARN'
    }
    return @($keep)
}

# --------------------------------------------------------------------------------------
# Proving where the defaults come from
#
# `probe` observes that defaultUsers/defaultGroups holds MORE than the lifecycle rules
# and infers the surplus is the document type's default security. That is a reasonable
# inference and it is still an inference - and it decides which source a run that grants
# people access should take its answer from.
#
# This settles it by arithmetic instead. For each role on each document it reads all
# three independently and asks whether they reconcile:
#
#     D  what Vault reports as the default for this document and role
#     L  what the lifecycle's role assignment rule says
#     T  what the document type's default security says, read from MDL
#
# If D = L union T, then -DesiredFrom Document is exactly lifecycle plus type defaults
# and the question is answered. If D holds names neither source accounts for, something
# else is contributing and nobody should be granting access on the strength of a guess
# about what.
# --------------------------------------------------------------------------------------

function Invoke-VaultRolesExplain {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Documents,
        [Parameter(Mandatory)]$Rules,
        [Parameter(Mandatory)]$Directory,
        [int]$Limit = 25
    )
    $c = $Context
    $docs = @($Documents)
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - explaining the first $Limit of $($docs.Count) document(s)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-VaultLog "Decomposing the reported defaults on $($docs.Count) document(s)"

    $rows = New-Object System.Collections.ArrayList
    $stat = @{ Roles = 0; Explained = 0; Expanded = 0; ExpandedUsers = 0; Surplus = 0
               Absent = 0; Both = 0; NoDefaults = 0; TypeAdded = 0; LifecycleOnly = 0 }
    $i = 0
    foreach ($doc in $docs) {
        $i++
        $docId = $doc.TargetId
        $info  = Get-VaultDocumentInfo -Context $c -DocId $docId
        if (-not $info.Read) { Write-VaultLog "[$i] $docId - could not read the document, skipped" 'WARN'; continue }
        $td = Get-VaultDocTypeRoleDefault -Context $c -TypeLabel $info.Type -SubtypeLabel $info.Subtype `
                  -Directory $Directory -ClassificationLabel $info.Classification

        foreach ($r in @(Get-VaultDocumentRole -Context $c -DocId $docId)) {
            $name = "$(Get-VaultField $r 'name' '')"
            if (-not $name) { continue }
            $stat.Roles++

            $D = Get-VaultDesiredForRole -From 'Document' -RoleRecord $r -Table $null -Rules $null `
                     -Subtype $info.Subtype -DocumentInfo $info
            $L = Get-VaultDesiredForRole -From 'Lifecycle' -RoleRecord $r -Table $null -Rules $Rules `
                     -Subtype $info.Subtype -DocumentInfo $info
            $tU = @(); $tG = @()
            if ($td.ContainsKey($name)) { $tU = @($td[$name].Users); $tG = @($td[$name].Groups) }

            $dSet = @(@($D.Users | ForEach-Object { "u:$_" }) + @($D.Groups | ForEach-Object { "g:$_" }))
            $lSet = @(@($L.Users | ForEach-Object { "u:$_" }) + @($L.Groups | ForEach-Object { "g:$_" }))
            $tSet = @(@($tU        | ForEach-Object { "u:$_" }) + @($tG        | ForEach-Object { "g:$_" }))
            $union = @(@($lSet + $tSet) | Select-Object -Unique)

            $surplus = @($dSet | Where-Object { $union -notcontains $_ })
            $absent  = @($union | Where-Object { $dSet -notcontains $_ })

            # Most of the "surplus" is not a third contributor: it is the SAME
            # contributor, resolved. A lifecycle rule assigns a group; Vault reports
            # defaultUsers as that group's expanded membership, so one configured group
            # comes back as one group plus twenty-five individual users.
            #
            # That distinction decides the whole job. Assigning the group is what the
            # configuration says; assigning the expansion writes direct user assignments
            # that OUTLIVE the group - remove someone from the group afterwards and they
            # keep the access - which is a mess to unpick across fifteen thousand
            # documents.
            $wantGroups = @($union | Where-Object { $_ -like 'g:*' } | ForEach-Object { $_.Substring(2) })
            $surplusUsers = @($surplus | Where-Object { $_ -like 'u:*' } | ForEach-Object { $_.Substring(2) })
            $byMembership = Get-VaultRedundantUserCount -Directory $Directory -Groups $wantGroups -Users $surplusUsers
            $trueSurplus  = @($surplus | Where-Object { $_ -like 'g:*' }).Count + ($surplusUsers.Count - $byMembership)
            # What the type defaults contribute that the lifecycle rule does not - the
            # quantity `probe` saw as a surplus, now attributed rather than inferred.
            $tOnly   = @($tSet | Where-Object { $lSet -notcontains $_ })

            $verdict =
                if (-not $dSet.Count -and -not $union.Count)      { $stat.NoDefaults++;  'NO_DEFAULTS' }
                elseif ($trueSurplus -gt 0 -and $absent.Count)    { $stat.Both++;        'BOTH_WAYS' }
                elseif ($trueSurplus -gt 0)                       { $stat.Surplus++;     'UNEXPLAINED_SURPLUS' }
                elseif ($absent.Count)                            { $stat.Absent++;      'CONFIG_NOT_IN_DEFAULTS' }
                elseif ($byMembership -gt 0)                      { $stat.Expanded++;    'EXPLAINED_GROUP_EXPANSION' }
                else                                              { $stat.Explained++;   'EXPLAINED' }
            $stat.ExpandedUsers += $byMembership
            if ($tOnly.Count) { $stat.TypeAdded++ } elseif ($lSet.Count) { $stat.LifecycleOnly++ }

            [void]$rows.Add([pscustomobject]@{
                DocId = $docId; Type = $info.Type; Subtype = $info.Subtype; Lifecycle = $info.Lifecycle
                Role = $name
                ReportedDefaults = $dSet.Count; FromLifecycle = $lSet.Count; FromTypeDefaults = $tSet.Count
                TypeAddsBeyondLifecycle = $tOnly.Count
                SurplusTotal = $surplus.Count; SurplusIsGroupMembership = $byMembership
                UnexplainedSurplus = $trueSurplus; ConfigNotInDefaults = $absent.Count
                Verdict = $verdict
                SurplusNames = (($surplus | Select-Object -First 8) -join '; ')
                AbsentNames  = (($absent  | Select-Object -First 8) -join '; ')
            })
        }
    }

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($stat.Roles) role(s) examined across $($docs.Count) document(s)"
    Write-VaultLog ("  EXPLAINED               {0}  - reported defaults are exactly lifecycle + type defaults" -f $stat.Explained) 'OK'
    Write-VaultLog ("  EXPLAINED_GROUP_EXPANSION {0} - and the rest is the membership of those groups, resolved" -f $stat.Expanded) 'OK'
    Write-VaultLog ("  NO_DEFAULTS             {0}  - nothing reported and nothing configured" -f $stat.NoDefaults)
    if ($stat.Surplus) { Write-VaultLog ("  UNEXPLAINED_SURPLUS     {0}  - reported defaults hold names NEITHER source accounts for" -f $stat.Surplus) 'ERROR' }
    if ($stat.Absent)  { Write-VaultLog ("  CONFIG_NOT_IN_DEFAULTS  {0}  - configured but not reported as a default" -f $stat.Absent) 'WARN' }
    if ($stat.Both)    { Write-VaultLog ("  BOTH_WAYS               {0}" -f $stat.Both) 'ERROR' }
    Write-VaultLog ("  type defaults add something beyond the lifecycle rule on {0} role(s)" -f $stat.TypeAdded)

    $decided = $stat.Explained + $stat.Expanded + $stat.NoDefaults
    if ($stat.Roles -and $decided -eq $stat.Roles) {
        Write-VaultLog 'PROVEN: every reported default is accounted for by the lifecycle rules plus the type defaults.' 'OK'
        if ($stat.Expanded) {
            Write-VaultLog ("{0} user(s) appear in the reported defaults only as the membership of a group that is already there." -f $stat.ExpandedUsers) 'WARN'
            Write-VaultLog 'So -DesiredFrom Document would assign every one of them DIRECTLY, in addition to the group.' 'WARN'
            Write-VaultLog 'A direct assignment outlives the group. Use -DesiredFrom Lifecycle, which assigns the group.' 'WARN'
        }
        else {
            Write-VaultLog '-DesiredFrom Document is therefore exactly those two sources.' 'OK'
        }
    }
    elseif ($stat.Surplus -or $stat.Both) {
        Write-VaultLog 'NOT PROVEN: some reported defaults come from somewhere neither source explains.' 'ERROR'
        Write-VaultLog 'Look at SurplusNames in the report before granting anything on -DesiredFrom Document.' 'ERROR'
    }
    else {
        Write-VaultLog 'Reported defaults are a SUBSET of what the two sources configure - see ConfigNotInDefaults.' 'WARN'
        Write-VaultLog 'Document mode would then assign less than Lifecycle + -WithTypeDefaults would.' 'WARN'
    }

    $report = Join-Path $c.Out 'roles-explain.csv'
    (ConvertTo-VaultUniformRows -Rows $rows) |
        Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Write-VaultLog "Report: $report"
    return ($stat.Surplus + $stat.Both)
}

function Invoke-VaultDocTypeMdlDump {
    # Every attribute of a document type's MDL component, not the three we parse.
    #
    # Get-VaultDocTypeRoleDefault reads role_defaulting_editors, _viewers and _consumers
    # and nothing else, so a document type that defaults a CUSTOM role would be invisible
    # to it - and -WithTypeDefaults would silently apply less than the type configures.
    # That is a claim about the component's shape, and the component can be asked.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$TypeLabel,
        [AllowEmptyString()][string]$SubtypeLabel = '',
        [AllowEmptyString()][string]$ClassificationLabel = ''
    )
    $c = $Context
    $idx = Get-VaultDocTypeNameIndex -Context $c
    $typeKey = ConvertTo-VaultNameKey $TypeLabel

    if (-not $idx.Types.ContainsKey($typeKey)) {
        # What the Library shows, and therefore what anyone has to hand, is the SUBTYPE
        # label - "Study Protocol" is a subtype of "Clinical". Insisting on the type name
        # would mean knowing the hierarchy before being allowed to ask about it.
        # EVERY type is searched, not the first that matches. Hashtable order is not
        # meaningful, so stopping at the first hit picks an arbitrary parent when two
        # types both have a subtype of that label - and then reads the wrong component
        # and reports on it as if it were the right one.
        $hits = New-Object System.Collections.ArrayList
        foreach ($tk in @($idx.Types.Keys)) {
            $tn = $idx.Types[$tk]
            $sn = Get-VaultSubtypeName -Context $c -TypeName $tn -SubtypeLabel $TypeLabel
            if ($sn) { [void]$hits.Add($tn) }
        }
        if ($hits.Count -gt 1) {
            throw ("'$TypeLabel' is a subtype of more than one type: " + ($hits -join ', ') +
                   ". Name which one with -Type <type> -Subtype '$TypeLabel'.")
        }
        if ($hits.Count -eq 1) {
            Write-VaultLog "'$TypeLabel' is a subtype of $($hits[0]) - reading that type and this subtype." 'WARN'
            $typeName = $hits[0]
            $SubtypeLabel = $TypeLabel
        }
        elseif ($hits.Count -eq 0) {
            # Name them. "Run roles survey" is an instruction to go and find out
            # something this already knows.
            $labels = @($idx.Types.Keys | ForEach-Object { $idx.Types[$_] } | Sort-Object)
            throw ("No document type or subtype called '$TypeLabel'. This vault's types are:`n    " + ($labels -join "`n    "))
        }
    }
    else { $typeName = $idx.Types[$typeKey] }

    $candidates = New-Object System.Collections.ArrayList
    if ($SubtypeLabel -and (ConvertTo-VaultNameKey $SubtypeLabel) -ne $typeKey) {
        $subName = Get-VaultSubtypeName -Context $c -TypeName $typeName -SubtypeLabel $SubtypeLabel
        if ($subName) { [void]$candidates.Add("Doctype.$typeName.$subName") }
    }
    [void]$candidates.Add("Doctype.$typeName")
    [void]$candidates.Add('Doctype.base_document__v')

    if ($SubtypeLabel -and $ClassificationLabel) {
        $sn = Get-VaultSubtypeName -Context $c -TypeName $typeName -SubtypeLabel $SubtypeLabel
        if ($sn) {
            $cn = Get-VaultClassificationName -Context $c -TypeName $typeName -SubtypeName $sn `
                      -ClassificationLabel $ClassificationLabel
            if ($cn) { $candidates.Insert(0, "Doctype.$typeName.$sn.$cn") }
            else { Write-VaultLog "No classification called '$ClassificationLabel' under $typeName/$sn" 'WARN' }
        }
    }

    $rows = New-Object System.Collections.ArrayList
    foreach ($component in $candidates) {
        Write-VaultLog '----------------------------------------------------------------'
        Write-VaultLog "$component"
        $r = $null
        foreach ($path in @("/configuration/$component", "/api/mdl/components/$component")) {
            try { $r = Invoke-VaultApi -VaultHost $c.VaultHost -ApiVersion $c.Api -Method GET -Path $path -MaxRetries 1; break }
            catch { }
        }
        if ($null -eq $r) { Write-VaultLog '  could not be read' 'WARN'; continue }

        $data = Get-VaultField $r 'data' $null
        if (-not $data) { $data = $r }

        $props = @()
        try { $props = @($data.PSObject.Properties) } catch { }
        if (-not $props.Count) {
            $raw = "$(Get-VaultField $r 'raw' '')"
            Write-VaultLog "  not JSON - raw MDL, $($raw.Length) character(s). Saved to the file below."
            [void]$rows.Add([pscustomobject]@{ Component = $component; Attribute = '(raw)'; Kind = 'text'; Count = $raw.Length; Value = $raw })
            continue
        }

        foreach ($p in ($props | Sort-Object Name)) {
            $v = $p.Value
            $kind = 'scalar'; $count = 1; $shown = "$v"
            if ($v -is [Array]) { $kind = 'array'; $count = $v.Count; $shown = (@($v | Select-Object -First 6) -join '; ') }
            elseif ($null -eq $v) { $shown = '' }
            if ($shown.Length -gt 160) { $shown = $shown.Substring(0, 160) + ' ...' }

            # Anything that looks like it defaults a principal into a role. This is the
            # question: are there more of these than the three we parse?
            $interesting = ($p.Name -match 'role|default|permission|shar')
            $line = ("  {0,-38} {1,-7} {2,4}  {3}" -f $p.Name, $kind, $count, $shown)
            if ($interesting) { Write-VaultLog $line 'OK' } else { Write-VaultLog $line }

            [void]$rows.Add([pscustomobject]@{
                Component = $component; Attribute = $p.Name; Kind = $kind; Count = $count; Value = $shown
            })
        }
    }

    $known = @('role_defaulting_editors', 'role_defaulting_viewers', 'role_defaulting_consumers')
    $defaulting = @($rows | Where-Object { $_.Attribute -like 'role_defaulting*' })
    $unparsed   = @($defaulting | Where-Object { $known -notcontains $_.Attribute })

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($defaulting.Count) role_defaulting_* attribute(s) across the components read"
    if ($unparsed.Count) {
        Write-VaultLog "$($unparsed.Count) of them are NOT read by -WithTypeDefaults:" 'ERROR'
        foreach ($u in $unparsed) { Write-VaultLog "  $($u.Component)  $($u.Attribute)  = $($u.Value)" 'ERROR' }
        Write-VaultLog 'Type defaults for those roles are configured and would not be applied.' 'ERROR'
    }
    else {
        Write-VaultLog 'Only editors, viewers and consumers - which is exactly what -WithTypeDefaults reads.' 'OK'
        Write-VaultLog 'So a document type cannot default a custom role, and nothing is being missed.' 'OK'
    }

    $out = Join-Path $c.Out 'doctype-mdl.csv'
    (ConvertTo-VaultUniformRows -Rows $rows) |
        Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Write-VaultLog "Every attribute written to $out"
    return $unparsed.Count
}
