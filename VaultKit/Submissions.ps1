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
        $r   = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
                  -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
                  -Body "q=$([Uri]::EscapeDataString($vql))"
        $rows = @(Get-VaultField $r 'data' @())
        if ($rows.Count -eq 1) {
            $script:VaultAppId = "$(Get-VaultField $rows[0] 'id' '')"
            Write-VaultLog "Application '$Key' is $Object $($script:VaultAppId)" 'OK'
            return $script:VaultAppId
        }
        if ($rows.Count -gt 1) {
            throw "$($rows.Count) $Object records match $KeyField = '$Key'. Set [submissions] applicationkeyfield to something that identifies one."
        }
        throw "No $Object where $KeyField = '$Key'. Check [submissions] path names a real application folder, and that applicationkeyfield is the field holding it."
    }
    catch { $script:VaultAppErr = "$_"; throw }
}

function Resolve-VaultSubmissionId {
    # A submission__v record from its folder name, scoped to its application.
    #
    # This is what makes the workflow need no manifest and nothing typed in: the staging
    # layout supplies both keys, the folder name and the application above it.
    #
    # The submission name is "0000 - Submission Meeting Minutes", so the folder name is a
    # PREFIX of name__v rather than the whole value - hence prefix matching by default.
    # Zero-padded numbers are prefix-unique (0000 never prefixes 0001), and neither % nor
    # _ can appear in a staging folder name, so the LIKE is safe. Set submissionmatch to
    # exact where the field holds just the number.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Key,
        [string]$ApplicationId = '',
        [string]$LookupField = 'name__v',
        [ValidateSet('prefix', 'exact')][string]$Match = 'prefix',
        [string]$ApplicationRefField = 'application__v'
    )
    $sub    = $Key.Replace("'", "\'")
    $clause = if ($Match -eq 'exact') { "$LookupField = '$sub'" } else { "$LookupField LIKE '$sub%'" }
    $where  = $clause
    # Direct equality on the reference field's stored id rather than traversing the
    # relationship, which is what "Unknown relationship [application__v]" was about.
    if ($ApplicationId) { $where += " AND $ApplicationRefField = '$ApplicationId'" }

    $vql = "SELECT id, name__v FROM submission__v WHERE $where"
    $r   = Invoke-VaultApi -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
              -Path '/query' -ContentType 'application/x-www-form-urlencoded' `
              -Body "q=$([Uri]::EscapeDataString($vql))"
    $rows = @(Get-VaultField $r 'data' @())
    if ($rows.Count -eq 0) { throw "No submission__v where $where" }
    if ($rows.Count -gt 1) {
        # Named rather than counted: "3 records match" is not something anyone can act
        # on, and the names usually say immediately which field is too loose.
        $names = (@($rows | ForEach-Object { Get-VaultField $_ 'name__v' '' }) -join '; ')
        throw "$($rows.Count) submission__v records match $where ($names). Narrow [submissions] lookupfield, or set submissionmatch = exact."
    }
    return "$(Get-VaultField $rows[0] 'id' '')"
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
        return [pscustomobject]@{ BinderId = ''; BinderVersion = ''; Messages = "results unavailable: $_" }
    }
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
            Write-VaultLog "$prefix - resolving submission '$($d.Base)' in application '$appKey'"
            $appId = Get-VaultApplicationId -Context $c -Key $appKey -Object $c.ApplicationObject -KeyField $c.ApplicationKeyField
            $subId = Resolve-VaultSubmissionId -Context $c -Key $d.Base -ApplicationId $appId `
                        -LookupField $c.LookupField -Match $c.SubmissionMatch -ApplicationRefField $c.ApplicationRefField
            $row.SubmissionId = $subId

            if ($Plan -or $c.WhatIf) {
                # StrictMode: assigning a property this row does not have is a
                # terminating error, and the column here is Messages, not Message.
                $row.Status = if ($c.WhatIf) { 'WHATIF' } else { 'PLANNED' }
                $stat.Planned++
                Write-VaultLog "$prefix - resolved to submission $subId; would import $($d.Path)" 'OK'
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
