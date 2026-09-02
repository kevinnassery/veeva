# RIM Submissions Archive: import dossiers that are already on File Staging.
#
# Nothing is moved, downloaded or uploaded. Each dossier is imported from where it
# already sits, so the whole workflow touches one vault - the target - and never puts a
# byte on the workstation beyond its own log and results file.
#
# Lifted from legacy/submissions-import/Import-VaultSubmissions.ps1, which carried its
# own config file, its own auth, its own session handling and its own logging. All four
# are now the kit's: [vault] target for the host, `vault login` and .vault-session.json
# for the session, Invoke-VaultApi for retry and throttling, Write-VaultLog for output.
# The standalone script kept a SessionId you pasted into config.ini by hand; there is no
# equivalent here on purpose, because a session that can only be refreshed by editing a
# file is a run that dies at the first expiry.

function Get-VaultSubmissionDossier {
    # The dossiers under one application folder: one child per submission.
    #
    # Not Get-VaultStagingItems, which is right next door and does almost this - it keeps
    # only kind 'file', because the document transfer stages files. A submission dossier
    # is usually a FOLDER (0000, 0001, ...) and sometimes an archive, so filtering to
    # files would return nothing at all on a normal Submissions Archive layout.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Path,
        [string[]]$ArchiveSuffix = @('.zip', '.tar.gz', '.tgz')
    )
    $out     = New-Object System.Collections.ArrayList
    $skipped = New-Object System.Collections.ArrayList
    $next = "/services/file_staging/items/$(ConvertTo-VaultStagingPath $Path)?recursive=false&limit=500"
    while ($next) {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path $next
        foreach ($d in @(Get-VaultField $r 'data' @())) {
            $name = "$(Get-VaultField $d 'name' '')"
            if (-not $name) { continue }
            # VFMTemp is Vault's OWN scratch folder and it sits right beside the
            # dossiers. It is a folder, so every rule below would take it for a
            # submission, fail to resolve a submission__v called VFMTemp, and write an
            # ERROR row on every run in every vault that has one. Dotted names go the
            # same way for the same reason.
            if ($name -ieq 'VFMTemp' -or $name.StartsWith('.')) { continue }
            $kind = "$(Get-VaultField $d 'kind' 'file')"
            if ($kind -ne 'folder') {
                $isArchive = $false
                foreach ($s in $ArchiveSuffix) { if ($name.ToLowerInvariant().EndsWith($s)) { $isArchive = $true; break } }
                # export_results.csv and any other loose file beside the dossiers is
                # not a submission. Named rather than skipped in silence: a folder full
                # of loose files is a path pointed one level too deep, and
                # export_results.csv specifically is the mapping sheet Bulk Submission
                # Export leaves behind - worth knowing is there.
                if (-not $isArchive) { [void]$skipped.Add($name); continue }
            }
            # The base name is the submission number: the folder name as-is, or the
            # archive name with its suffix removed. It is what the VQL lookup keys on.
            $base = $name
            if ($kind -ne 'folder') { $base = $name -replace '\.tar\.gz$|\.tgz$|\.zip$', '' }
            [void]$out.Add([pscustomobject]@{
                Name = $name
                Base = $base
                Kind = $kind
                Path = "$(Get-VaultField $d 'path' '')"
                Size = [long]"$(Get-VaultField $d 'size' 0)"
            })
        }
        $next = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    if ($skipped.Count) {
        Write-VaultLog "$($skipped.Count) loose file(s) beside the dossiers, not treated as submissions: $((@($skipped | Select-Object -First 5)) -join ', ')$(if ($skipped.Count -gt 5) { ', ...' })"
        if (@($skipped | Where-Object { $_ -ieq 'export_results.csv' }).Count) {
            # The legacy importer read this off staging and preferred it to the VQL
            # lookup. This port resolves by folder name and application only, so a
            # mapping sheet sitting here is NOT being consulted - say so rather than
            # let it look like it was.
            Write-VaultLog 'export_results.csv is present. This command does NOT read it - submissions resolve by folder name + application via VQL.' 'WARN'
        }
    }
    return @($out)
}

$script:VaultAppIdResolved = $false
$script:VaultAppId         = ''
$script:VaultAppErr        = $null

function Find-VaultApplicationMatch {
    # Which field of the application object actually holds the staging folder name.
    #
    # The configured field is a guess about somebody else's object model, and when it is
    # wrong the run fails on every dossier with the same error. Rather than make an
    # operator go and read the model, ask the vault: read the object's metadata, take its
    # String fields - only a String can hold an alphanumeric like e157135 or 068582 - and
    # look for one whose value equals the key.
    #
    # Partial matches are collected separately and reported but never used. A field that
    # merely CONTAINS the key is a lead for a human, not a match to act on.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Key,
        [string]$Object = 'application__v',
        [int]$MaxPages = 20
    )
    $meta   = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path "/metadata/vobjects/$Object"
    $obj    = Get-VaultField $meta 'object' $meta
    $fields = @(Get-VaultField $obj 'fields' @())
    if ($fields.Count -eq 0) { throw "Could not read the fields of $Object via /metadata/vobjects/$Object" }

    $names = @('id') + @($fields | Where-Object { "$(Get-VaultField $_ 'type' '')" -eq 'String' } |
                         ForEach-Object { Get-VaultField $_ 'name' '' } | Where-Object { $_ })
    $names = @($names | Select-Object -Unique)

    $exactField = ''; $exactId = ''
    $partials   = New-Object System.Collections.ArrayList
    $scanned    = 0
    $pages      = 0
    $truncated  = $false

    # Paged, unlike the tool this came from, which read the first page and stopped - so
    # in a vault with more applications than fit one page the scan could miss the very
    # record it was looking for and report that no field matched.
    $vql  = "SELECT $($names -join ', ') FROM $Object"
    $path = '/query'
    $body = "q=$([Uri]::EscapeDataString($vql))"
    while ($path) {
        $pages++
        if ($pages -gt $MaxPages) { $truncated = $true; break }
        $r = if ($pages -eq 1) {
                Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
                    -Path $path -ContentType 'application/x-www-form-urlencoded' -Body $body
             } else {
                Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path $path
             }
        foreach ($row in @(Get-VaultField $r 'data' @())) {
            $scanned++
            foreach ($f in $names) {
                if ($f -eq 'id') { continue }
                $v = "$(Get-VaultField $row $f '')"
                if (-not $v) { continue }
                if ($v -ieq $Key) {
                    if (-not $exactField) { $exactField = $f; $exactId = "$(Get-VaultField $row 'id' '')" }
                }
                elseif ($v -match [regex]::Escape($Key)) {
                    [void]$partials.Add([pscustomobject]@{ Field = $f; Value = $v })
                }
            }
        }
        if ($exactField) { break }
        $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    return [pscustomobject]@{
        ExactField = $exactField; ExactId = $exactId; Partials = @($partials)
        Scanned = $scanned; Fields = ($names.Count - 1); Truncated = $truncated
    }
}

function Get-VaultApplicationId {
    # The application folder name (e157135) as a record id, resolved once per run.
    #
    # Cached including the FAILURE. Without that, the first submission reports the real
    # cause and every one after it reports whatever the second query happened to say,
    # so a run of four hundred ends with one true error buried under 399 misleading ones.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Key,
        [string]$Object = 'application__v',
        [string]$KeyField = 'name__v'
    )
    if ($script:VaultAppIdResolved) {
        if ($script:VaultAppErr) { throw $script:VaultAppErr }
        return $script:VaultAppId
    }
    $script:VaultAppIdResolved = $true
    $script:VaultAppId = ''; $script:VaultAppErr = $null
    if (-not $Key) { return '' }

    try {
        $k   = $Key.Replace("'", "\'")
        $vql = "SELECT id FROM $Object WHERE $KeyField = '$k'"
        $rows = @()
        try {
            $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
                    -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
                    -Body "q=$([Uri]::EscapeDataString($vql))"
            $rows = @(Get-VaultField $r 'data' @())
        }
        catch {
            # A field that does not exist on this vault fails the QUERY, not just the
            # match - so the fast path has to survive its own configuration being wrong,
            # or the scan below never runs and the operator is told the application does
            # not exist when what does not exist is the field.
            Write-VaultLog "Query on '$KeyField' failed ($_) - falling back to a field scan" 'WARN'
            $rows = @()
        }
        if ($rows.Count -eq 1) {
            $script:VaultAppId = "$(Get-VaultField $rows[0] 'id' '')"
            Write-VaultLog "Application '$Key' is $Object $($script:VaultAppId)" 'OK'
            return $script:VaultAppId
        }
        if ($rows.Count -gt 1) {
            # Genuine ambiguity. Scanning would not help - the vault has already given a
            # clear answer and it is "more than one", which only a human can narrow.
            throw "$($rows.Count) $Object records match $KeyField = '$Key'. Set [submissions] applicationkeyfield to something that identifies one."
        }

        # Zero rows on the configured field is a guess that was wrong, not a dead end.
        # Ask the vault which field actually holds it rather than making someone go and
        # read the object model.
        Write-VaultLog "No $Object where $KeyField = '$Key' - scanning $Object string fields for it" 'WARN'
        $m = Find-VaultApplicationMatch -Context $Context -Key $Key -Object $Object
        if ($m.ExactField) {
            $script:VaultAppId = $m.ExactId
            Write-VaultLog "Application '$Key' is $Object $($m.ExactId), found on field '$($m.ExactField)'" 'OK'
            Write-VaultLog "Set [submissions] applicationkeyfield = $($m.ExactField) to skip this scan next time." 'WARN'
            return $script:VaultAppId
        }

        $hint = ''
        if ($m.Partials.Count) {
            $flds = (@($m.Partials | ForEach-Object { $_.Field }) | Select-Object -Unique) -join ', '
            $hint = " Fields that merely contain it: $flds - a partial match is a lead, not an answer."
        }
        if ($m.Truncated) { $hint += ' The scan stopped at the page cap, so it did not read every record.' }
        throw "Could not find $Object '$Key' by field '$KeyField', nor by scanning $($m.Fields) string field(s) across $($m.Scanned) record(s).$hint Check [submissions] path names a real application folder."
    }
    catch { $script:VaultAppErr = "$_"; throw }
}

function Get-VaultSubmissionSerial {
    # The serial number out of a submission name, from either side of the join.
    #
    #   20130724 Serial No. 0156 Safety Report   -> 0156
    #   20040331 SBM SN 0000 Original IND Sub    -> 0000
    #   20140219 PAM SN 0161 Updated Investigato -> 0161
    #
    # This is the only part of the string both sides agree on. The leading date does not
    # survive the round trip - staged folders were seen a day, three days and ten days
    # off the record they belong to - and the descriptive tail carries typos and
    # substituted punctuation. The serial is what a submission actually IS.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Name)
    # Leading \b only. Without it an 'sn' inside a word followed by a number reads as a
    # serial, and a WRONG serial matches a real record - worse than no match, because no
    # match stops the dossier and a wrong one imports it onto somebody else's submission.
    #
    # A trailing \b cannot be used: 'Serial No.' ends in a period and is followed by a
    # space, and two non-word characters have no boundary between them - so it silently
    # matched nothing at all, which the unit check above caught.
    if ($Name -match '(?i)\b(?:serial\s*no\.?|sn)\s*[:#-]?\s*(\d{3,5})') { return $Matches[1] }
    return ''
}

function Get-VaultSubmissionIndex {
    # Every submission in the application, once, indexed for local matching.
    #
    # One query instead of one per dossier: 161 round trips became 1. That is not only
    # faster, it is what makes serial matching possible at all - VQL forbids a leading
    # wildcard, so "find the record whose name contains 0156" cannot be asked of the
    # vault and has to be answered here.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$ApplicationId,
        [string]$ApplicationRefField = 'application__v'
    )
    $vql  = "SELECT id, name__v FROM submission__v WHERE $ApplicationRefField = '$ApplicationId'"
    $rows = @(Invoke-VaultQuery -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Vql $vql)

    $byName   = @{}
    $bySerial = @{}
    foreach ($r in $rows) {
        $id   = "$(Get-VaultField $r 'id' '')"
        $name = "$(Get-VaultField $r 'name__v' '')"
        if (-not $id -or -not $name) { continue }
        $k = $name.Trim().ToLowerInvariant()
        if (-not $byName.ContainsKey($k)) { $byName[$k] = New-Object System.Collections.ArrayList }
        [void]$byName[$k].Add([pscustomobject]@{ Id = $id; Name = $name })

        $ser = Get-VaultSubmissionSerial -Name $name
        if ($ser) {
            if (-not $bySerial.ContainsKey($ser)) { $bySerial[$ser] = New-Object System.Collections.ArrayList }
            [void]$bySerial[$ser].Add([pscustomobject]@{ Id = $id; Name = $name })
        }
    }
    Write-VaultLog "$($rows.Count) submission(s) in the application, $($bySerial.Count) with a serial number" 'OK'
    return [pscustomobject]@{ Rows = $rows.Count; ByName = $byName; BySerial = $bySerial }
}

function Resolve-VaultSubmissionIdLocal {
    # Match one staged folder to one submission record, against the index.
    #
    # Three passes, most specific first, and every one of them reports HOW it matched -
    # because "resolved" by exact name and "resolved" by serial after the name failed are
    # different levels of confidence and the results file should not flatten them.
    param(
        [Parameter(Mandatory)]$Index,
        [Parameter(Mandatory)][string]$Key
    )
    $k = $Key.Trim().ToLowerInvariant()

    if ($Index.ByName.ContainsKey($k)) {
        $hits = @($Index.ByName[$k])
        if ($hits.Count -eq 1) { return [pscustomobject]@{ Id = $hits[0].Id; How = 'exact name'; Name = $hits[0].Name } }
        throw "$($hits.Count) submissions are named '$Key' - the name does not identify one."
    }

    # Prefix, the way the vault-side LIKE used to do it, kept because a folder named
    # plainly 0000 against a record named "0000 - Meeting Minutes" is the layout this
    # workflow was originally written for and still has to work.
    $pre = @()
    foreach ($nk in $Index.ByName.Keys) { if ($nk.StartsWith($k)) { $pre += @($Index.ByName[$nk]) } }
    if ($pre.Count -eq 1) { return [pscustomobject]@{ Id = $pre[0].Id; How = 'name prefix'; Name = $pre[0].Name } }
    if ($pre.Count -gt 1) { throw "$($pre.Count) submissions start with '$Key' - the prefix does not identify one." }

    $ser = Get-VaultSubmissionSerial -Name $Key
    if (-not $ser) {
        throw "No submission matches '$Key' by name or prefix, and no serial number could be read out of the folder name to match on instead."
    }
    if (-not $Index.BySerial.ContainsKey($ser)) {
        throw "No submission matches '$Key' by name or prefix, and none carries serial $ser."
    }
    $hits = @($Index.BySerial[$ser])
    if ($hits.Count -gt 1) {
        $names = (@($hits | ForEach-Object { $_.Name }) -join '; ')
        throw "$($hits.Count) submissions carry serial ${ser} ($names) - the serial does not identify one."
    }
    return [pscustomobject]@{ Id = $hits[0].Id; How = "serial $ser"; Name = $hits[0].Name }
}

function Start-VaultSubmissionImport {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$SubmissionId,
        [Parameter(Mandatory)][string]$StagingPath,
        [string]$DossierFormatId = '',
        [string]$ActualSubmissionDate = ''
    )
    # Form fields, not a URL path: the request encodes them, so escaping the staging path
    # here as well would double-encode every space in it.
    $pairs = @("file=$([Uri]::EscapeDataString($StagingPath))")
    if ($DossierFormatId)      { $pairs += "dossier_format_record_id=$([Uri]::EscapeDataString($DossierFormatId))" }
    if ($ActualSubmissionDate) { $pairs += "actual_submission_date=$([Uri]::EscapeDataString($ActualSubmissionDate))" }

    $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
            -Path "/vobjects/submission__v/$SubmissionId/actions/import" `
            -ContentType 'application/x-www-form-urlencoded' -Body ($pairs -join '&')

    $warnings = ''
    $w = Get-VaultField $r 'warnings' $null
    if ($w) {
        # APPLICATION_MISMATCH and SUBMISSION_MISMATCH are non-fatal - the job still
        # runs - so they are recorded beside the result rather than treated as failure.
        $warnings = (@($w) | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join ' | '
    }
    return [pscustomobject]@{ JobId = "$(Get-VaultField $r 'job_id' '')"; Warnings = $warnings }
}

function Wait-VaultJob {
    # Poll until the job leaves a running state, or the deadline passes.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$JobId,
        [int]$TimeoutMinutes = 120,
        [int]$PollSeconds = 20
    )
    # Vault allows the Job Status endpoint once every 10 seconds PER job_id, and answers
    # API_LIMIT_EXCEEDED past that. A configured interval below the floor would not poll
    # faster, it would just fail faster.
    if ($PollSeconds -lt 11) {
        Write-VaultLog "jobpollseconds is $PollSeconds; Vault allows one job status call per 10s per job - using 11" 'WARN'
        $PollSeconds = 11
    }
    $running  = @('SCHEDULED', 'QUEUING', 'QUEUED', 'RUNNING', 'IN_PROGRESS')
    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    while ((Get-Date) -lt $deadline) {
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path "/services/jobs/$JobId"
        $status = "$(Get-VaultField (Get-VaultField $r 'data' $null) 'status' '')".ToUpperInvariant()
        if ($status -and ($running -notcontains $status)) { return $status }
        Start-Sleep -Seconds $PollSeconds
    }
    # A distinct status rather than an exception: the import is still running in Vault,
    # and the row has to say that rather than imply the dossier failed.
    return "TIMEOUT_AFTER_${TimeoutMinutes}_MIN"
}

function Get-VaultSubmissionImportResult {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$SubmissionId,
        [Parameter(Mandatory)][string]$JobId
    )
    # Retried, because this call is made the instant the job status poll returned SUCCESS
    # - and Vault meters BOTH by job_id, once per 10 seconds. So the very first attempt
    # lands inside the window the status poll just opened and comes back
    # API_LIMIT_EXCEEDED. Waiting unconditionally would cost 10 seconds on every dossier;
    # trying and retrying costs it only when it is actually hit.
    #
    # The first version of this swallowed the failure into a blank binder id, so five
    # imports reported SUCCESS with nothing to point at and the cause was invisible
    # until someone read the Messages column.
    for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        # Vault 26R3 (Dec 2026) stops returning the data array from this endpoint;
        # importMessages remains. Binder id and version go blank rather than the call
        # failing, which is why every read here is guarded rather than indexed.
        $r = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/vobjects/submission__v/$SubmissionId/actions/import/$JobId/results"
        $binderId = ''; $version = ''
        $d = Get-VaultField $r 'data' $null
        if ($d) {
            $first    = @($d)[0]
            $binderId = "$(Get-VaultField $first 'id' '')"
            $version  = "$(Get-VaultField $first 'major_version_number__v' '?').$(Get-VaultField $first 'minor_version_number__v' '?')"
        }
        $messages = ''
        $im = Get-VaultField $r 'importMessages' $null
        if ($im) { $messages = (@($im) | ForEach-Object { "$_" }) -join ' | ' }
        return [pscustomobject]@{ BinderId = $binderId; BinderVersion = $version; Messages = $messages }
    }
    catch {
        $err = "$_"
        if ($err -match 'API_LIMIT_EXCEEDED' -and $attempt -lt 3) {
            $wait = 11
            Write-VaultLog "import results for job $JobId are inside the 10s per-job polling window - waiting ${wait}s (attempt $attempt/3)" 'WARN'
            Start-Sleep -Seconds $wait
            continue
        }
        # Said out loud, not only written to a column. A SUCCESS row with no binder id
        # is a run that cannot point at what it created, and that should be visible while
        # it happens rather than found afterwards.
        Write-VaultLog "could not read import results for job ${JobId}: $err" 'WARN'
        return [pscustomobject]@{ BinderId = ''; BinderVersion = ''; Messages = "results unavailable: $err" }
    }
    }
    return [pscustomobject]@{ BinderId = ''; BinderVersion = ''; Messages = 'results unavailable after 3 attempts' }
}

function Test-VaultSubmissionsPreflight {
    # Everything that can be proven before the first import, proven before the first
    # import. Returns the number of failures; the caller stops on anything above zero.
    #
    # On the disk check, and what it is NOT: submissions import IN PLACE. No dossier is
    # ever downloaded, so there is no transfer budget to compute and none is claimed
    # here - a check that measured dossier sizes would be describing bytes that never
    # touch this machine. What does get written is the log and the results CSV, and both
    # have failed a run before: a full volume, and a results file held open by Excel,
    # which throws on the FIRST save - after the imports have already happened.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$StagingPath)
    $fail = 0
    Write-VaultLog '=== Preflight ==='

    # 1. Somewhere to write, and room to write it.
    $free = Get-VaultFreeSpace -Path $Context.Out
    if ($free -lt 0) {
        Write-VaultLog "  [WARN] cannot read free space on $($Context.Out)" 'WARN'
    }
    elseif ($free -lt ($Context.ReserveMB * 1MB)) {
        Write-VaultLog ("  [FAIL] {0} free on {1}, below the {2}MB reserve" -f (Format-VaultBytes $free), $Context.Out, $Context.ReserveMB) 'ERROR'
        $fail++
    }
    else {
        Write-VaultLog ("  [PASS] {0} free on {1}" -f (Format-VaultBytes $free), $Context.Out) 'OK'
    }

    # 2. Writable, tested by writing. Permissions that look right and a file that cannot
    #    be created are different things, and only one of them matters.
    $probe = Join-Path $Context.Out ('.preflight-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
    try {
        [IO.File]::WriteAllText($probe, 'probe')
        Remove-Item -LiteralPath $probe -Force -WhatIf:$false -ErrorAction SilentlyContinue
        Write-VaultLog "  [PASS] output folder is writable - $($Context.Out)" 'OK'
    }
    catch {
        Write-VaultLog "  [FAIL] cannot write into $($Context.Out): $_" 'ERROR'
        $fail++
    }

    # 3. The results file, specifically. Excel holds an exclusive lock on an open CSV,
    #    and the run would import everything and then fail to record any of it.
    $res = Join-Path $Context.Out 'submission-import-results.csv'
    if (Test-Path -LiteralPath $res) {
        try {
            $fs = [IO.File]::Open($res, 'Open', 'ReadWrite', 'None')
            $fs.Dispose()
            Write-VaultLog '  [PASS] submission-import-results.csv is not locked' 'OK'
        }
        catch {
            Write-VaultLog '  [FAIL] submission-import-results.csv is open in another program - close it (Excel holds an exclusive lock)' 'ERROR'
            $fail++
        }
    }

    # 4. The staging path resolves and holds something. An application folder that lists
    #    nothing is the single most common way this run does nothing and says it
    #    succeeded, so it fails here rather than reporting "0 dossiers" as a result.
    try {
        $items = Get-VaultSubmissionDossier -Context $Context -Path $StagingPath
        if ($items.Count -eq 0) {
            Write-VaultLog "  [FAIL] $StagingPath lists no dossier folders or archives" 'ERROR'
            $fail++
        }
        else {
            $folders = @($items | Where-Object { $_.Kind -eq 'folder' }).Count
            Write-VaultLog ("  [PASS] {0} dossier(s) under {1} ({2} folder(s), {3} archive(s))" -f `
                            $items.Count, $StagingPath, $folders, ($items.Count - $folders)) 'OK'
        }
    }
    catch {
        Write-VaultLog "  [FAIL] cannot list $StagingPath - $_" 'ERROR'
        $fail++
    }

    Write-VaultLog "  preflight: $fail failure(s)"
    return $fail
}

function Confirm-VaultStagingPath {
    # The Submissions Archive root this run works from, established and agreed before
    # anything reads or imports.
    #
    # Prompted when [submissions] path is empty, and offered back to vault.ini so it is
    # asked for once rather than every run. Shown and confirmed when it is already set,
    # the same way the vaults are - because this path decides which application gets
    # imported, and pointing it at last wave's folder is a mistake nothing downstream
    # can catch. The application is echoed beside it: that is the value actually used to
    # resolve every record, and confirming the string without it confirms the wrong half.
    param(
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [switch]$Yes
    )
    # A console can answer; a scheduled run cannot, and blocking for ever on an answer
    # nobody is there to give is worse than either proceeding or stopping outright.
    $canAsk = $true
    if ($script:VaultNoPrompt) { $canAsk = $false }
    if ($canAsk) { try { if ([Console]::IsInputRedirected) { $canAsk = $false } } catch { } }

    $p = "$Path".Trim()

    if (-not $p) {
        if (-not $canAsk) {
            throw "[submissions] path is not set in $ConfigPath, and this is not a console so it cannot be asked for."
        }
        Write-VaultLog '[submissions] path is not set.' 'WARN'
        Write-Host ''
        Write-Host '  The application folder on the TARGET vault''s File Staging, under the'
        Write-Host '  Submissions Archive root. Its children are the submissions:'
        Write-Host ''
        Write-Host '      /SubmissionsArchive/e157135        <- this'
        Write-Host '      /SubmissionsArchive/e157135/0000'
        Write-Host '      /SubmissionsArchive/e157135/0001'
        Write-Host ''
        $p = (Read-Host 'Submissions Archive path').Trim()
        if (-not $p) { throw 'Stopped: no path given.' }
        if (-not $p.StartsWith('/')) { $p = "/$p" }

        # Offered, not assumed. Writing to somebody's config without asking is the kind
        # of helpfulness that is indistinguishable from a bug when they next read it.
        $save = Read-Host "Save this to [submissions] path in $(Split-Path -Leaf $ConfigPath)? [Y/n]"
        if ($save -notmatch '^[Nn]') {
            try {
                Set-VaultSetting -Path $ConfigPath -Section 'submissions' -Key 'path' -Value $p
                Write-VaultLog "Saved to $ConfigPath - it will be confirmed rather than asked for next time." 'OK'
            }
            catch { Write-VaultLog "Could not write $ConfigPath, so this path applies to this run only: $_" 'WARN' }
        }
        else { Write-VaultLog 'Not saved - this path applies to this run only.' 'WARN' }
    }

    $app = @(($p -replace '\\', '/').Trim('/') -split '/')[-1]
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog ("  staging     {0}" -f $p) 'OK'
    Write-VaultLog ("  application {0}" -f $app)
    Write-VaultLog '----------------------------------------------------------------'

    if ($Yes) { return $p }
    if (-not $canAsk) {
        Write-VaultLog 'Not a console - proceeding without confirmation.' 'WARN'
        return $p
    }
    $answer = Read-Host "Is this the right application? [y/N]"
    if ($answer -notmatch '^[Yy]') { throw 'Stopped: the staging path was not confirmed.' }
    return $p
}

function Invoke-VaultSubmissionsList {
    # What is there, written to a manifest. No VQL, no imports, no vault writes - this
    # answers "did I point it at the right folder" before anything costs anything.
    param([Parameter(Mandatory)]$Context, [int]$Limit = 0)
    $c    = $Context
    $path = $c.StagingPath
    Write-VaultLog "Listing $path"

    $dossiers = @(Get-VaultSubmissionDossier -Context $c -Path $path)
    if ($Limit -gt 0 -and $dossiers.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - showing the first $Limit of $($dossiers.Count)" 'WARN'
        $dossiers = @($dossiers | Select-Object -First $Limit)
    }

    $out = Join-Path $c.Out 'submission-manifest.csv'
    $rows = New-Object System.Collections.ArrayList
    foreach ($d in $dossiers) {
        [void]$rows.Add([pscustomobject][ordered]@{
            FileName             = $d.Name
            SubmissionKey        = $d.Base
            SubmissionId         = ''
            Kind                 = $d.Kind
            StagingPath          = $d.Path
            SizeMB               = [math]::Round(([double]$d.Size) / 1MB, 2)
            ActualSubmissionDate = ''
            DossierFormatId      = ''
        })
    }
    $rows | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "  dossiers   $($dossiers.Count)" 'OK'
    Write-VaultLog "  manifest   $out"
    Write-VaultLog 'SubmissionId is blank here on purpose - resolving it needs the vault, which is what `submissions import -Plan` does.'
    return 0
}

function Invoke-VaultSubmissionsImport {
    param(
        [Parameter(Mandatory)]$Context,
        [switch]$Plan,
        [int]$TestCount = 0,
        [int]$Limit = 0
    )
    $c    = $Context
    $path = $c.StagingPath

    # The application is the last segment of the staging path. Taken from there rather
    # than configured separately, because two settings that must agree are two settings
    # that can disagree - and the layout already says it.
    $appKey = @(($path -replace '\\', '/').Trim('/') -split '/')[-1]

    $bad = Test-VaultSubmissionsPreflight -Context $c -StagingPath $path
    if ($bad -gt 0) {
        Write-VaultLog "Stopping: $bad preflight check(s) failed. Nothing was imported." 'ERROR'
        return $bad
    }

    $dossiers = @(Get-VaultSubmissionDossier -Context $c -Path $path)
    $total    = $dossiers.Count
    if ($Limit -gt 0 -and $dossiers.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - examining the first $Limit of $total dossier(s)" 'WARN'
        $dossiers = @($dossiers | Select-Object -First $Limit)
    }
    Write-VaultLog "$($dossiers.Count) dossier(s) in application '$appKey'"

    # Sequential, and not because nobody got round to sharding it. An import is an async
    # JOB in Vault: this process starts it and then waits. Running eight of them in
    # parallel would queue eight jobs on the same vault rather than doing the work eight
    # times faster, and the failure mode - a wave of imports nobody is watching - is
    # exactly what the phased design exists to prevent.
    $res = New-VaultResults -Path (Join-Path $c.Out 'submission-import-results.csv') -KeyColumn 'FileName' `
              -DoneStatuses @('SUCCESS') -Existing $c.Existing

    # Resolved ONCE, before the loop: the application, then every submission in it.
    # Per dossier this was a VQL call each - 161 round trips - and it could not match on
    # a serial number at all, because VQL forbids a leading wildcard. Both problems go
    # away by fetching the set and matching here.
    try {
        $appId = Get-VaultApplicationId -Context $c -Key $appKey -Object $c.ApplicationObject -KeyField $c.ApplicationKeyField
        $index = Get-VaultSubmissionIndex -Context $c -ApplicationId $appId -ApplicationRefField $c.ApplicationRefField
    }
    catch {
        # One clear stop, not 161 copies of the same error against every dossier.
        Write-VaultLog "Cannot resolve the application: $_" 'ERROR'
        return 1
    }

    $stat = @{ Ok = 0; Failed = 0; Planned = 0; Skipped = 0 }
    $i = 0
    $stopped = $false

    foreach ($d in $dossiers) {
        $i++
        $prefix = "[$i/$($dossiers.Count)] $($d.Name)"
        if ($res.Done.ContainsKey($d.Name)) { $stat.Skipped++; continue }

        $row = [pscustomobject][ordered]@{
            FileName      = $d.Name
            StagingPath   = $d.Path
            SizeMB        = [math]::Round(([double]$d.Size) / 1MB, 2)
            SubmissionKey = $d.Base
            SubmissionId  = ''
            MatchedBy     = ''
            JobId         = ''
            Status        = ''
            BinderId      = ''
            BinderVersion = ''
            Warnings      = ''
            Messages      = ''
            StartedUtc    = (Get-Date).ToUniversalTime().ToString('s')
            FinishedUtc   = ''
        }

        try {
            # Read-only, so it runs in every mode. Resolving the id is the whole point of
            # the dry run: a key that matches nothing, or matches two records, is found
            # here rather than part way through a real wave.
            $m     = Resolve-VaultSubmissionIdLocal -Index $index -Key $d.Base
            $subId = $m.Id
            $row.SubmissionId = $subId
            $row.MatchedBy    = $m.How
            # The matched NAME is logged, not just the id. Where the two strings differ -
            # and they do, by whole days in the leading date - the operator needs to see
            # what it matched to, not be told that something matched.
            if ($m.How -ne 'exact name') {
                Write-VaultLog "$prefix - matched by $($m.How) to '$($m.Name)'" 'WARN'
            }

            if ($Plan -or $c.WhatIf) {
                # StrictMode: assigning a property this row does not have is a
                # terminating error, and the column here is Messages, not Message.
                $row.Status = if ($c.WhatIf) { 'WHATIF' } else { 'PLANNED' }
                $stat.Planned++
                Write-VaultLog "$prefix - resolved to submission $subId ($($m.How)); would import $($d.Path)" 'OK'
            }
            else {
                $job = Start-VaultSubmissionImport -Context $c -SubmissionId $subId -StagingPath $d.Path `
                          -DossierFormatId $c.DossierFormatId
                $row.JobId    = $job.JobId
                $row.Warnings = $job.Warnings
                if ($job.Warnings) { Write-VaultLog "$prefix - import warnings: $($job.Warnings)" 'WARN' }
                Write-VaultLog "$prefix - job $($job.JobId) started, polling every $($c.JobPollSeconds)s"

                $status = Wait-VaultJob -Context $c -JobId $job.JobId -TimeoutMinutes $c.JobTimeoutMinutes -PollSeconds $c.JobPollSeconds
                $row.Status = $status

                $r = Get-VaultSubmissionImportResult -Context $c -SubmissionId $subId -JobId $job.JobId
                $row.BinderId      = $r.BinderId
                $row.BinderVersion = $r.BinderVersion
                $row.Messages      = $r.Messages

                if ($status -eq 'SUCCESS') {
                    $stat.Ok++
                    Write-VaultLog "$prefix - SUCCESS (binder $($r.BinderId) v$($r.BinderVersion))" 'OK'
                }
                else {
                    $stat.Failed++
                    Write-VaultLog "$prefix - job ended $status. $($r.Messages)" 'ERROR'
                }
            }
        }
        catch {
            $row.Status   = 'ERROR'
            $row.Messages = "$_"
            $stat.Failed++
            Write-VaultLog "$prefix - ERROR: $_" 'ERROR'
        }

        $row.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
        Add-VaultResult -Results $res -Row $row

        if ($TestCount -gt 0) {
            $done = if ($Plan -or $c.WhatIf) { $stat.Planned } else { $stat.Ok + $stat.Failed }
            if ($done -ge $TestCount) {
                Write-VaultLog "TEST: $done after $i dossier(s) - stopping" 'OK'
                $stopped = $true
                break
            }
        }
    }

    Save-VaultResults -Results $res
    Write-VaultLog '----------------------------------------------------------------'
    if ($Plan -or $c.WhatIf) {
        Write-VaultLog "$($stat.Planned) dossier(s) resolved, $($stat.Failed) could not be. NOTHING was imported." $(if ($stat.Failed) { 'WARN' } else { 'OK' })
        if ($stat.Failed) { Write-VaultLog 'Fix the ERROR rows before a real run - each is a dossier that would fail there too.' 'WARN' }
    }
    else {
        Write-VaultLog "Imported $($stat.Ok), $($stat.Failed) failed, $($stat.Skipped) already SUCCESS" $(if ($stat.Failed) { 'WARN' } else { 'OK' })
    }
    if ($stopped) { Write-VaultLog "TEST run - stopped after $i of $($dossiers.Count) dossier(s). NOT the whole application." 'WARN' }
    Write-VaultLog "Results: $($res.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($res.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return $stat.Failed
}
