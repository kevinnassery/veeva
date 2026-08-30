# Is this document actually migrated?
#
# The per-workflow checks each answer their own question: documents verify proves a file
# reached File Staging, attachments verify proves the attachments match, roles verify
# proves what a run claimed it assigned. None of them answers the question someone
# actually asks at the end, which is about a DOCUMENT rather than about a step:
#
#   source document -> destination document, and everything that hangs off it
#
# So this checks a source/target PAIR across four dimensions - the document's own file,
# its attachments, its Sharing Settings, and that both ends exist at all - and gives one
# verdict per pair. It reads both vaults and writes to neither.
#
# It is deliberately independent of the other results files. A report assembled from what
# earlier runs RECORDED inherits their mistakes; this one asks the vaults.

# --------------------------------------------------------------------------------------
# How much to check
#
# Checking everything is the honest default and often the wrong economics: a DEEP census
# of 15,775 documents downloads both copies of each, which is twice what the migration
# itself moved. So the scope is chosen explicitly, and the choice is recorded in the log
# and the report - a sample nobody can reproduce is an anecdote.
# --------------------------------------------------------------------------------------

function Get-VaultSampleSize {
    # Cochran's formula with the finite population correction.
    #
    #   n0 = z^2 * p(1-p) / e^2          then    n = n0 / (1 + (n0 - 1) / N)
    #
    # p is fixed at 0.5 because that maximises the variance, which is the conservative
    # choice when you do not already know the failure rate - and if you knew it, you
    # would not be sampling. So the answer does not depend on a guess about how good the
    # migration is.
    #
    # 95% with a 5% margin over any large population lands near 384, which is why that
    # number turns up in every sampling table. The finite correction pulls it down for a
    # population this size.
    param(
        [Parameter(Mandatory)][int]$Population,
        [ValidateSet(90, 95, 99)][int]$Confidence = 95,
        [ValidateRange(0.1, 50)][double]$MarginPct = 5
    )
    if ($Population -le 0) { return 0 }

    $z = switch ($Confidence) { 90 { 1.645 } 95 { 1.96 } 99 { 2.576 } }
    $p = 0.5
    $e = $MarginPct / 100.0

    $n0 = ($z * $z * $p * (1 - $p)) / ($e * $e)
    $n  = $n0 / (1 + (($n0 - 1) / $Population))
    $n  = [int][math]::Ceiling($n)
    if ($n -gt $Population) { $n = $Population }
    return $n
}

function Select-VaultSample {
    # A reproducible random subset.
    #
    # Seeded on purpose. An auditor asking "which documents did you check, and would you
    # get the same ones again" needs an answer, and "random" is not one. The seed is
    # logged and recorded, so the same seed over the same population selects the same
    # documents - and a different seed is a genuinely independent second sample.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Items,
        [Parameter(Mandatory)][int]$Count,
        [int]$Seed = 0
    )
    if ($Count -ge $Items.Count) { return @($Items) }
    if ($Count -le 0) { return @() }

    $rng = if ($Seed -ne 0) { New-Object System.Random($Seed) } else { New-Object System.Random }

    # Fisher-Yates over a copy, taking the first $Count. Not "sort by a random key",
    # which is biased by the sort's tie handling, and not "pick until you have enough",
    # which repeats.
    $a = @($Items)
    $picked = New-Object System.Collections.ArrayList
    $n = $a.Count
    for ($i = 0; $i -lt $Count; $i++) {
        $j = $rng.Next($i, $n)
        $tmp = $a[$i]; $a[$i] = $a[$j]; $a[$j] = $tmp
        [void]$picked.Add($a[$i])
    }
    return @($picked)
}

function Resolve-VaultVerifyScope {
    # Turn a mode into a list of pairs, and say out loud what it decided.
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Pairs,
        [Parameter(Mandatory)][ValidateSet('trial', 'sample', 'census')][string]$Mode,
        [int]$TrialSize = 25,
        [int]$Confidence = 95,
        [double]$MarginPct = 5,
        [int]$Seed = 0
    )
    $population = $Pairs.Count
    switch ($Mode) {
        'census' {
            Write-VaultLog "census: all $population document(s)" 'OK'
            return @($Pairs)
        }
        'trial' {
            $n = [math]::Min($TrialSize, $population)
            $chosen = Select-VaultSample -Items $Pairs -Count $n -Seed $Seed
            Write-VaultLog "trial: $n of $population document(s), chosen at random (seed $Seed)" 'WARN'
            Write-VaultLog 'A trial proves the check works. It says nothing about the migration.' 'WARN'
            return $chosen
        }
        'sample' {
            $n = Get-VaultSampleSize -Population $population -Confidence $Confidence -MarginPct $MarginPct
            $chosen = Select-VaultSample -Items $Pairs -Count $n -Seed $Seed
            Write-VaultLog "sample: $n of $population document(s) for $Confidence% confidence, +/-$MarginPct% margin (seed $Seed)" 'OK'
            Write-VaultLog 'Cochran with the finite population correction, p=0.5 - the conservative assumption.'
            return $chosen
        }
    }
}

# --------------------------------------------------------------------------------------
# What relates a source document to its target
#
# A hand-maintained CSV is the weakest anchor there is: it says what somebody INTENDED,
# it goes stale the moment anyone loads a document outside it, and it cannot tell you
# about a document it does not mention - which is exactly the document you would want to
# hear about.
#
# A field on the target document holding the source id is a far better one, because it is
# in the vault, it is what the load actually did, and it covers everything. Vault has no
# single blessed field for this, so which one carries it is a question about THIS
# migration - and the answer is discoverable rather than guessable.
# --------------------------------------------------------------------------------------

function Get-VaultDocumentFieldName {
    # Every document field this vault defines.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$VaultHost)
    $r = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $Context.Api -Method GET `
            -Path '/metadata/objects/documents/properties'
    $names = New-Object System.Collections.ArrayList
    foreach ($p in @(Get-VaultField $r 'properties' @())) {
        $n = "$(Get-VaultField $p 'name' '')"
        if ($n) { [void]$names.Add($n) }
    }
    return @($names)
}

function Invoke-VaultAnchorProbe {
    # Which field, if any, relates the two vaults - answered from the vaults.
    #
    # Read only. Reports every candidate field, how many documents carry a value, what
    # those values look like, and - when a map is available - how many of them actually
    # hit a source id the map knows. A field that is populated but whose values match
    # nothing is worse than no field at all, because it looks like an anchor.
    param([Parameter(Mandatory)]$Context, [int]$Limit = 500)
    $c = $Context

    Write-VaultLog "target vault: $($c.TargetHost)"
    $fields = Get-VaultDocumentFieldName -Context $c -VaultHost $c.TargetHost
    Write-VaultLog "$($fields.Count) document field(s) defined on the target"

    # Names a migration puts a legacy id in. Deliberately broad: a false candidate costs
    # one query and is reported as empty, where a missed one costs the whole approach.
    $pattern = 'external|legacy|migrat|source|origin|prior|previous|old_|_old|mnk|mallinckrodt|xref|cross_ref'
    $candidates = @($fields | Where-Object { $_ -match $pattern })

    # The document's own id space is worth checking too: some loads carry the source id
    # in a name or number field rather than a purpose-made one.
    foreach ($extra in @('external_id__v', 'document_number__v', 'name__v')) {
        if (($fields -contains $extra) -and ($candidates -notcontains $extra)) { $candidates += $extra }
    }

    if (-not $candidates.Count) {
        Write-VaultLog 'No field name suggests a legacy id. There may still be one under a name this does not match.' 'WARN'
        Write-VaultLog "Fields defined: $((@($fields | Sort-Object) -join ', '))"
        return 1
    }
    Write-VaultLog "$($candidates.Count) candidate field(s): $($candidates -join ', ')"

    # A map, if there is one, turns "populated" into "populated with something real".
    $known = @{}
    if ($c.Map -and $c.Map.Count) {
        foreach ($k in $c.Map.Keys) { $known["$k"] = $true }
        Write-VaultLog "$($known.Count) source id(s) from the map, to check candidate values against"
    }

    $rows = New-Object System.Collections.ArrayList
    foreach ($f in $candidates) {
        $populated = 0; $hits = 0; $samples = New-Object System.Collections.ArrayList
        try {
            $q = "SELECT id, $f FROM documents WHERE $f != '' MAXROWS $Limit"
            $docs = Get-VaultDocumentsByQuery -Context $c -Where $q -Stop $Limit
            foreach ($d in $docs) {
                $v = "$(Get-VaultField $d $f '')"
                if (-not $v) { continue }
                $populated++
                if ($known.Count -and $known.ContainsKey($v)) { $hits++ }
                if ($samples.Count -lt 3) { [void]$samples.Add($v) }
            }
        }
        catch {
            Write-VaultLog "  $f - not queryable: $_" 'WARN'
            continue
        }

        $verdict =
            if (-not $populated)                     { 'EMPTY' }
            elseif ($known.Count -and $hits -eq 0)   { 'POPULATED_BUT_UNRELATED' }
            elseif ($known.Count -and $hits -lt $populated) { 'PARTIAL' }
            elseif ($known.Count)                    { 'ANCHOR' }
            else                                     { 'POPULATED' }

        $level = switch ($verdict) { 'ANCHOR' { 'OK' } 'EMPTY' { 'INFO' } default { 'WARN' } }
        Write-VaultLog ("  {0,-28} {1,-24} {2} of {3} sampled carry a mapped source id  e.g. {4}" -f `
                        $f, $verdict, $hits, $populated, (($samples) -join ' ')) $level

        [void]$rows.Add([pscustomobject]@{
            Field = $f; Verdict = $verdict; Sampled = $populated
            MatchedMapSource = $hits; Examples = ($samples -join ' ')
        })
    }

    $report = Join-Path $c.Out 'anchor-candidates.csv'
    (ConvertTo-VaultUniformRows -Rows $rows) |
        Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    $best = @($rows | Where-Object { $_.Verdict -eq 'ANCHOR' })
    Write-VaultLog '----------------------------------------------------------------'
    if ($best.Count) {
        Write-VaultLog "Anchor: $($best[0].Field) - build the pair list from the vault with: verify map -Anchor $($best[0].Field)" 'OK'
    }
    else {
        Write-VaultLog 'No field relates the two vaults. The map is the only anchor there is, and it' 'WARN'
        Write-VaultLog 'cannot tell you about a document it does not mention.' 'WARN'
    }
    Write-VaultLog "Report: $report"
    return 0
}

function Invoke-VaultBuildPairMap {
    # Derive the source/target pairs from the target vault itself and write them out.
    #
    # The result is the same shape as the hand-maintained map, so everything downstream
    # takes it unchanged - but it is generated from what the load actually produced, and
    # a document loaded outside anyone's spreadsheet appears in it.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Anchor,
        [string]$OutFile = ''
    )
    $c = $Context
    $path = $OutFile
    if (-not $path) { $path = Join-Path $c.Out 'derived-map.csv' }

    Write-VaultLog "Reading $($c.TargetHost) for documents carrying $Anchor"
    $docs = Get-VaultDocumentsByQuery -Context $c -Where "SELECT id, $Anchor FROM documents WHERE $Anchor != ''"

    $rows = New-Object System.Collections.ArrayList
    $dupes = @{}
    foreach ($d in $docs) {
        $src = "$(Get-VaultField $d $Anchor '')"
        $tgt = "$(Get-VaultField $d 'id' '')"
        if (-not $src -or -not $tgt) { continue }
        if ($dupes.ContainsKey($src)) {
            # Two target documents claiming one source is a real finding: the load ran
            # twice, or two loads overlapped. Reported rather than silently deduped.
            $dupes[$src] += ",$tgt"
            continue
        }
        $dupes[$src] = $tgt
        [void]$rows.Add([pscustomobject]@{ source_id = $src; target_id = $tgt })
    }

    $repeated = @($dupes.Keys | Where-Object { $dupes[$_] -match ',' })
    if ($repeated.Count) {
        Write-VaultLog "$($repeated.Count) source id(s) claimed by more than one target document - the load may have run twice" 'ERROR'
        foreach ($k in ($repeated | Select-Object -First 5)) { Write-VaultLog "  $k -> $($dupes[$k])" 'ERROR' }
    }

    $rows | Export-Csv -LiteralPath $path -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    Write-VaultLog "$($rows.Count) pair(s) written to $path" 'OK'
    Write-VaultLog 'Point [attachments] map or [roles] map at it to use it as the spine.'
    return $(if ($repeated.Count) { 1 } else { 0 })
}

# --------------------------------------------------------------------------------------
# The four dimensions
# --------------------------------------------------------------------------------------

function Test-VaultMigratedDocument {
    # One source/target pair, end to end. Returns the row; decides nothing about scope.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$TargetId,
        [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
        [AllowNull()]$Rules,
        [AllowNull()]$Directory
    )
    $c = $Context
    $row = [ordered]@{
        SourceDocId = $SourceId; TargetDocId = $TargetId
        SourceName = ''; TargetName = ''; Title = ''
        SourceBytes = 0; TargetBytes = 0; SourceMd5 = ''; TargetMd5 = ''
        FileStatus = 'NOT_CHECKED'
        SourceAttachments = 0; TargetAttachments = 0
        AttachmentsMatched = 0; AttachmentsMissing = 0; AttachmentsDiffering = 0; AttachmentsExtra = 0
        AttachmentStatus = 'NOT_CHECKED'
        RolesTotal = 0; RolesWithPeople = 0; GroupsMissing = 0; UsersMissing = 0
        RoleStatus = 'NOT_CHECKED'
        Method = $Depth; Status = ''; Message = ''
        CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
    }
    $notes  = New-Object System.Collections.ArrayList
    $srcTmp = $null; $tgtTmp = $null; $work = ''

    # ---- 1 and 2: the documents themselves, and their files ----
    $srcDoc = $null; $tgtDoc = $null
    try {
        $r = Invoke-VaultApi -VaultHost $c.SourceHost -ApiVersion $c.Api -Method GET -Path "/objects/documents/$SourceId"
        $srcDoc = Get-VaultField $r 'document' $null
    } catch { [void]$notes.Add("source: $_") }
    try {
        $r = Invoke-VaultApi -VaultHost $c.TargetHost -ApiVersion $c.Api -Method GET -Path "/objects/documents/$TargetId"
        $tgtDoc = Get-VaultField $r 'document' $null
    } catch { [void]$notes.Add("target: $_") }

    if ($srcDoc) {
        $row.SourceName  = "$(Get-VaultField $srcDoc 'filename__v' '')"
        $row.Title       = "$(Get-VaultField $srcDoc 'name__v' '')"
        $row.SourceBytes = [long]"$(Get-VaultField $srcDoc 'size__v' 0)"
    }
    if ($tgtDoc) {
        $row.TargetName  = "$(Get-VaultField $tgtDoc 'filename__v' '')"
        $row.TargetBytes = [long]"$(Get-VaultField $tgtDoc 'size__v' 0)"
    }

    if     (-not $srcDoc) { $row.FileStatus = 'MISSING_ON_SOURCE' }
    elseif (-not $tgtDoc) { $row.FileStatus = 'MISSING_ON_TARGET' }
    elseif ($row.TargetBytes -le 0 -and $row.SourceBytes -gt 0) {
        # The target document exists but carries no file. For this migration that is the
        # expected state until the Loader has consumed File Staging - so it is reported
        # as its own answer rather than as a mismatch, which would read as corruption.
        $row.FileStatus = 'NO_FILE_ON_TARGET'
        [void]$notes.Add('target document has no source file yet')
    }
    elseif ($Depth -eq 'FAST') {
        $row.FileStatus = if ($row.SourceBytes -eq $row.TargetBytes) { 'MATCH' } else { 'MISMATCH' }
    }
    else {
        try {
            Assert-VaultDiskBudget -Path $c.Scratch -Needed ($row.SourceBytes * 2) -ReserveMB $c.ReserveMB
            $work   = New-VaultScratch -Root $c.Scratch -Name "$SourceId-$TargetId"
            $srcTmp = Save-VaultFile -VaultHost $c.SourceHost -ApiVersion $c.Api `
                          -Path "/objects/documents/$SourceId/file" -Destination $work -FileName 'source.bin'
            $tgtTmp = Save-VaultFile -VaultHost $c.TargetHost -ApiVersion $c.Api `
                          -Path "/objects/documents/$TargetId/file" -Destination $work -FileName 'target.bin'
            $row.SourceMd5   = (Get-FileHash -LiteralPath $srcTmp.Path -Algorithm MD5).Hash
            $row.TargetMd5   = (Get-FileHash -LiteralPath $tgtTmp.Path -Algorithm MD5).Hash
            $row.SourceBytes = $srcTmp.Size
            $row.TargetBytes = $tgtTmp.Size
            $row.FileStatus  = if ($row.SourceMd5 -ieq $row.TargetMd5) { 'MATCH' } else { 'MISMATCH' }
        }
        catch {
            $row.FileStatus = 'ERROR'
            [void]$notes.Add("file: $_")
        }
        finally {
            Remove-VaultScratchFile -File $srcTmp -Scratch $c.Scratch
            Remove-VaultScratchFile -File $tgtTmp -Scratch $c.Scratch
            if ($work) { Remove-VaultScratchDir -Path $work }
        }
    }

    # ---- 3: attachments ----
    # By name and MD5 out of the listings. Vault reports both, so nothing is downloaded
    # to answer this - which is why the attachment dimension is nearly free even on a
    # census.
    if ($srcDoc -and $tgtDoc) {
        try {
            $sAtt = @(Get-VaultDocumentAttachment -VaultHost $c.SourceHost -ApiVersion $c.Api -DocId $SourceId)
            $tAtt = @(Get-VaultDocumentAttachment -VaultHost $c.TargetHost -ApiVersion $c.Api -DocId $TargetId)
            $row.SourceAttachments = $sAtt.Count
            $row.TargetAttachments = $tAtt.Count

            $byName = @{}
            foreach ($t in $tAtt) { $byName["$($t.Name)".ToLowerInvariant()] = $t }
            $seen = @{}
            foreach ($s in $sAtt) {
                $k = "$($s.Name)".ToLowerInvariant()
                $seen[$k] = $true
                if (-not $byName.ContainsKey($k)) { $row.AttachmentsMissing++; continue }
                $t = $byName[$k]
                if ($s.Checksum -and $t.Checksum) {
                    if ($s.Checksum -ieq $t.Checksum) { $row.AttachmentsMatched++ } else { $row.AttachmentsDiffering++ }
                }
                elseif ($s.Size -eq $t.Size) { $row.AttachmentsMatched++ }
                else { $row.AttachmentsDiffering++ }
            }
            foreach ($t in $tAtt) { if (-not $seen.ContainsKey("$($t.Name)".ToLowerInvariant())) { $row.AttachmentsExtra++ } }

            $row.AttachmentStatus =
                if     (-not $sAtt.Count -and -not $tAtt.Count) { 'NONE' }
                elseif ($row.AttachmentsMissing -or $row.AttachmentsDiffering) { 'INCOMPLETE' }
                elseif ($row.AttachmentsExtra) { 'EXTRA_ON_TARGET' }
                else { 'MATCH' }
        }
        catch {
            $row.AttachmentStatus = 'ERROR'
            [void]$notes.Add("attachments: $_")
        }
    }

    # ---- 4: permissions ----
    if ($tgtDoc) {
        try {
            $roles = @(Get-VaultDocumentRole -Context $c -DocId $TargetId)
            $row.RolesTotal = $roles.Count
            foreach ($r in $roles) {
                $u = @(Get-VaultField $r 'users' @()).Count
                $g = @(Get-VaultField $r 'groups' @()).Count
                if ($u -or $g) { $row.RolesWithPeople++ }
            }

            if ($Rules -and $Rules.Count -and $Directory) {
                # What the configuration says should be there, against what is. This is
                # the same question `roles assign` answers - asked here of the vault
                # rather than of a run's own record of what it did.
                $info    = Get-VaultDocumentInfo -Context $c -DocId $TargetId
                $subtype = Get-VaultSubtypeName -Context $c -DocumentInfo $info
                foreach ($r in $roles) {
                    $want = Get-VaultDesiredForRole -From 'Lifecycle' -RoleRecord $r -Table $null `
                                -Rules $Rules -Subtype $subtype -DocumentInfo $info
                    $haveU = @(Get-VaultField $r 'users' @())
                    $haveG = @(Get-VaultField $r 'groups' @())
                    foreach ($g in @($want.Groups)) { if ($haveG -notcontains $g) { $row.GroupsMissing++ } }
                    foreach ($u in @($want.Users))  { if ($haveU -notcontains $u) { $row.UsersMissing++ } }
                }
            }

            $row.RoleStatus =
                if     (-not $row.RolesTotal)                        { 'NO_ROLES' }
                elseif ($row.GroupsMissing -or $row.UsersMissing)    { 'INCOMPLETE' }
                elseif (-not $row.RolesWithPeople)                   { 'EMPTY' }
                else                                                 { 'POPULATED' }
        }
        catch {
            $row.RoleStatus = 'ERROR'
            [void]$notes.Add("roles: $_")
        }
    }

    # ---- the verdict ----
    # VERIFIED means every dimension that could be checked passed. A dimension that could
    # not be checked never counts as a pass - the whole point is that this row can be
    # handed to somebody as evidence, and evidence that quietly treats "unknown" as "fine"
    # is worse than none.
    $fileOk   = $row.FileStatus -eq 'MATCH'
    $attOk    = $row.AttachmentStatus -in @('MATCH', 'NONE')
    $roleOk   = $row.RoleStatus -eq 'POPULATED'
    $anyError = ($row.FileStatus -eq 'ERROR') -or ($row.AttachmentStatus -eq 'ERROR') -or ($row.RoleStatus -eq 'ERROR')

    $row.Status =
        if     ($anyError)                    { 'ERROR' }
        elseif ($fileOk -and $attOk -and $roleOk) { 'VERIFIED' }
        elseif ($row.FileStatus -in @('MISSING_ON_SOURCE', 'MISSING_ON_TARGET', 'MISMATCH')) { 'FAILED' }
        else                                  { 'PARTIAL' }

    $row.Message = ($notes -join ' | ')
    return [pscustomobject]$row
}

# --------------------------------------------------------------------------------------
# The run
# --------------------------------------------------------------------------------------

function Invoke-VaultMigrationVerify {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][ValidateSet('trial', 'sample', 'census')][string]$Mode,
        [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
        [int]$TrialSize = 25,
        [ValidateSet(90, 95, 99)][int]$Confidence = 95,
        [double]$MarginPct = 5,
        [int]$Seed = 0,
        [switch]$WithRoleRules,
        [int]$Limit = 0
    )
    $c = $Context
    if (-not $c.Map -or -not $c.Map.Count) {
        throw 'No map. The pairs come from [verify] map - the source and target id columns of the migration.'
    }

    $pairs = @($c.Map.Keys | ForEach-Object { [pscustomobject]@{ Source = "$_"; Target = "$($c.Map[$_])" } })
    if ($Limit -gt 0 -and $pairs.Count -gt $Limit) { $pairs = @($pairs | Select-Object -First $Limit) }

    Write-VaultLog "$($c.SourceHost)  vs  $($c.TargetHost)"
    Write-VaultLog "$($pairs.Count) mapped pair(s) in the population"

    $chosen = Resolve-VaultVerifyScope -Pairs $pairs -Mode $Mode -TrialSize $TrialSize `
                  -Confidence $Confidence -MarginPct $MarginPct -Seed $Seed

    if ($c.Workers -gt 1 -and $chosen.Count -gt 1) {
        if ($Depth -eq 'DEEP') {
            Write-VaultLog "DEEP across $($c.Workers) worker(s) holds up to $($c.Workers * 2) files on disk at once" 'WARN'
        }
        # The scope was chosen HERE. Each worker censuses its own shard, so the sample is
        # drawn once rather than eight times - eight independent samples of one population
        # is not a sample of it.
        return Invoke-VaultShardedRun -Context $c -Pending $chosen -Workers $c.Workers `
                   -Command @('verify', 'census') -LogPattern "verify-$Mode-*.log" `
                   -ResultsName 'migration-validate-results.csv' -KeyColumn 'SourceDocId' `
                   -SuccessStatus 'VERIFIED' -Verb 'Verified' -ShardKind 'map' `
                   -ExtraArgs @('-Depth', $Depth)
    }

    $rules = $null; $dir = $null
    if ($WithRoleRules) {
        # One read for the whole run, not one per document.
        Write-VaultLog 'Reading the lifecycle role assignment rules, to check roles against configuration'
        $dir   = Get-VaultDirectory -Context $c
        $rules = Get-VaultRoleAssignmentRule -Context $c -Directory $dir
        if (-not $rules.Count) { Write-VaultLog 'No role assignment rules readable - roles will be reported as present or empty only.' 'WARN' }
    }

    $results = New-VaultResults -Path (Join-Path $c.Out 'migration-validate-results.csv') `
                   -KeyColumn 'SourceDocId' -DoneStatuses @() -Existing $c.Existing

    $stat = @{ Verified = 0; Failed = 0; Partial = 0; Errors = 0 }
    $i = 0
    foreach ($pair in $chosen) {
        $i++
        $prefix = "[$i/$($chosen.Count)] $($pair.Source) -> $($pair.Target)"
        $row = Test-VaultMigratedDocument -Context $c -SourceId $pair.Source -TargetId $pair.Target `
                   -Depth $Depth -Rules $rules -Directory $dir
        switch ($row.Status) {
            'VERIFIED' { $stat.Verified++; Write-VaultLog "$prefix - VERIFIED" 'OK' }
            'FAILED'   { $stat.Failed++;   Write-VaultLog "$prefix - FAILED file=$($row.FileStatus) $($row.Message)" 'ERROR' }
            'ERROR'    { $stat.Errors++;   Write-VaultLog "$prefix - ERROR $($row.Message)" 'ERROR' }
            default    { $stat.Partial++;  Write-VaultLog "$prefix - PARTIAL file=$($row.FileStatus) att=$($row.AttachmentStatus) roles=$($row.RoleStatus)" 'WARN' }
        }
        Add-VaultResult -Results $results -Row $row
    }

    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "$($chosen.Count) of $($pairs.Count) document(s) checked ($Mode, $Depth)"
    Write-VaultLog ("  VERIFIED  {0}" -f $stat.Verified) 'OK'
    if ($stat.Failed)  { Write-VaultLog ("  FAILED    {0}" -f $stat.Failed) 'ERROR' }
    if ($stat.Partial) { Write-VaultLog ("  PARTIAL   {0}  - some dimension is not done yet, or could not be checked" -f $stat.Partial) 'WARN' }
    if ($stat.Errors)  { Write-VaultLog ("  ERROR     {0}" -f $stat.Errors) 'ERROR' }

    if ($Mode -ne 'census') {
        # Said every time. A sample says something about the population only as a
        # sample - reading "0 failed" off 376 documents as "15,775 documents are fine"
        # is the mistake this line exists to prevent.
        $pct = if ($pairs.Count) { 100.0 * $chosen.Count / $pairs.Count } else { 0 }
        Write-VaultLog ("This is a {0} of {1:N1}% of the population. It does not certify the {2} document(s) not checked." -f $Mode, $pct, ($pairs.Count - $chosen.Count)) 'WARN'
    }
    Write-VaultLog "Results: $($results.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $results.Path
    if ($snap) { Write-VaultLog "This run : $snap" }
    return ($stat.Failed + $stat.Errors)
}
