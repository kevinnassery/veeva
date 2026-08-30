# Running one workflow across several processes.
#
# Above one worker the command stops moving anything itself and becomes a supervisor: it
# shards the outstanding work, launches that many copies of vault.ps1 - each in its own
# output folder, with its own input file, its own results and its own log - waits, and
# merges their results back into the one file the operator reads.
#
# Separate PROCESSES rather than runspaces or jobs, because that is what makes the work
# genuinely independent: no shared state to contend on, a worker that dies takes nothing
# with it, and the results file each one writes is a complete record on its own. The cost
# is that a worker cannot ask for a password, which is what the credential file is for.
#
# Per-document time is dominated by round trips, not bytes, so this scales close to
# linearly until Vault's burst limit starts throttling.

function Read-VaultWorkerLog {
    # Forward a worker's new WARN/ERROR lines into the parent log.
    #
    # Workers run hidden and write their own logs, so without this a worker failing every
    # document looks - from the parent - like progress that simply stopped, with the
    # error text sitting in a file nobody is watching.
    #
    # Opened with FileShare.ReadWrite because the worker still has it open for writing.
    # The read offset is kept per worker so each line is forwarded exactly once.
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][hashtable]$Offsets,
        [int]$MaxLines = 20
    )
    $log = @(Get-ChildItem -LiteralPath $Dir -Filter $Pattern -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime | Select-Object -Last 1)
    if (-not $log.Count) { return }
    $path = $log[0].FullName

    try {
        $fs = New-Object IO.FileStream($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    }
    catch { return }
    try {
        $start = 0
        if ($Offsets.ContainsKey($Label)) { $start = [long]$Offsets[$Label] }
        if ($start -gt $fs.Length) { $start = 0 }   # rotated or truncated
        [void]$fs.Seek($start, [IO.SeekOrigin]::Begin)
        $sr   = New-Object IO.StreamReader($fs)
        $text = $sr.ReadToEnd()
        $Offsets[$Label] = $start + [Text.Encoding]::UTF8.GetByteCount($text)
        $sr.Dispose()
    }
    finally { $fs.Dispose() }

    $bad = @($text -split "`r?`n" | Where-Object { $_ -match '\[(WARN|ERROR)\]' })
    if (-not $bad.Count) { return }
    foreach ($line in ($bad | Select-Object -First $MaxLines)) {
        $level = if ($line -match '\[ERROR\]') { 'ERROR' } else { 'WARN' }
        Write-VaultLog ("{0} | {1}" -f $Label, ($line -replace '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[(WARN|ERROR)\] ', '')) $level
    }
    if ($bad.Count -gt $MaxLines) {
        Write-VaultLog ("{0} | ... {1} more line(s) this interval, full detail in {2}" -f $Label, ($bad.Count - $MaxLines), $path) 'WARN'
    }
}

function Merge-VaultWorkerLog {
    # One log out of many, in the order things actually happened.
    #
    # Each worker keeps its own log - that is what makes a single worker's story readable
    # when it is the one that went wrong. But nobody wants to open nine files to find out
    # what a run did, and "which worker was that" is not a question worth answering by
    # hand. So the per-worker files stay as the raw evidence and this writes the narrative.
    #
    # Sorted on the timestamp each line already carries. A line without one is a
    # continuation of the line above it - a wrapped error, say - so it inherits that
    # timestamp and stays attached rather than being sorted to the top.
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][string]$OutPath,
        [string]$SupervisorLog = ''
    )
    $entries = New-Object System.Collections.ArrayList

    $sources = New-Object System.Collections.ArrayList
    if ($SupervisorLog -and (Test-Path -LiteralPath $SupervisorLog)) {
        [void]$sources.Add([pscustomobject]@{ Label = 'sup'; Path = $SupervisorLog })
    }
    for ($w = 1; $w -le $Count; $w++) {
        $dir = Join-Path $Root "w$w"
        $log = @(Get-ChildItem -LiteralPath $dir -Filter $Pattern -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime | Select-Object -Last 1)
        if ($log.Count) { [void]$sources.Add([pscustomobject]@{ Label = "w$w"; Path = $log[0].FullName }) }
    }
    if (-not $sources.Count) { return '' }

    foreach ($src in $sources) {
        $seq = 0; $ts = '0000-00-00 00:00:00'
        foreach ($line in (Get-Content -LiteralPath $src.Path -ErrorAction SilentlyContinue)) {
            $seq++
            if ("$line" -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})') { $ts = $Matches[1] }
            [void]$entries.Add([pscustomobject]@{ Ts = $ts; Label = $src.Label; Seq = $seq; Line = "$line" })
        }
    }

    # Ts first, then the worker, then its own line order - so a worker's lines never
    # shuffle among themselves when several share a second.
    $sorted = @($entries | Sort-Object Ts, Label, Seq)
    $out = New-Object System.Collections.ArrayList
    foreach ($e in $sorted) { [void]$out.Add(('{0,-3} | {1}' -f $e.Label, $e.Line)) }
    [IO.File]::WriteAllLines($OutPath, $out, (New-Object Text.UTF8Encoding $false))
    return $OutPath
}

function Invoke-VaultShardedRun {
    # Returns the number of items that failed, so the caller's exit code is unchanged
    # whether the run was sequential or parallel.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Pending,
        [Parameter(Mandatory)][int]$Workers,
        [Parameter(Mandatory)][string[]]$Command,     # e.g. @('documents', 'stage')
        [Parameter(Mandatory)][string]$LogPattern,    # e.g. 'documents-stage-*.log'
        [Parameter(Mandatory)][string]$ResultsName,   # e.g. 'document-results.csv'
        [string]$KeyColumn = 'Id',
        # What a shard file is. The transfer works from a list of ids; the attachment
        # sync works from a map of source id to target id, and handing a worker half a
        # map as a list of ids loses the half that says where things go.
        [ValidateSet('ids', 'map')][string]$ShardKind = 'ids',
        # Whether one item produces one result row. It does for documents. It does not
        # for attachments, where a shard is documents and the rows are attachments - so
        # progress against a document count would read 500/200 and an ETA computed from
        # it would be wrong rather than merely coarse.
        [bool]$RowsAreItems = $true,
        # What a good row looks like for this workflow. The transfer records SUCCESS and
        # the validator records MATCH, and a supervisor that only knows one of them
        # counts every row of the other as a failure.
        [string]$SuccessStatus = 'SUCCESS',
        [string]$Verb = 'Moved',
        # Only the transfer renames anything. The validator's Name column holds what the
        # SOURCE calls the file, which is a different thing from the name that was
        # written - comparing them there reported 195 renames out of 200 when 2 had
        # happened.
        [switch]$ReportRenames,
        [string[]]$ExtraArgs = @()
    )
    $c     = $Context
    $count = [math]::Min($Workers, $Pending.Count)
    $root  = Join-Path $c.Out 'workers'
    if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force -WhatIf:$false | Out-Null }

    $resultsPath = Join-Path $c.Out $ResultsName

    # -Existing Fresh, honoured here too. The single-process path rotates the results
    # aside and starts clean; the supervisor read them regardless and merged, so asking
    # for a fresh start on a worker run silently did not get one.
    if ($c.Existing -eq 'Fresh' -and (Test-Path -LiteralPath $resultsPath)) {
        $when  = (Get-Item -LiteralPath $resultsPath).LastWriteTime.ToString('yyyyMMdd-HHmmss')
        $moved = [IO.Path]::Combine([IO.Path]::GetDirectoryName($resultsPath),
                 ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($resultsPath), $when, [IO.Path]::GetExtension($resultsPath)))
        Move-Item -LiteralPath $resultsPath -Destination $moved -Force -WhatIf:$false
        Write-VaultLog "Rotated previous results to $(Split-Path -Leaf $moved)"
    }

    $prior = [ordered]@{}
    if (Test-Path -LiteralPath $resultsPath) {
        foreach ($row in (Import-Csv -LiteralPath $resultsPath)) {
            $k = "$(Get-VaultField $row $KeyColumn '')"
            if ($k) { $prior[$k] = $row }
        }
    }

    # Credentials are a bonus here, not a requirement. Workers share .vault-session.json
    # with this process and read their session straight out of it, so they can work
    # without ever holding a password. What a password buys them is the ability to
    # re-authenticate if a session expires mid-run - so its absence is a warning about
    # long runs, not a reason to refuse to start.
    #
    # On the normal path there is nothing to export: `login` cached the sessions in an
    # earlier process, so this one was never prompted and holds nothing.
    $credPath = ''
    $nCred    = 0
    try {
        $try = Join-Path $c.Out ('.worker-cred-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.xml')
        $nCred = Export-VaultCredentials -Path $try
        if ($nCred -gt 0) { $credPath = $try }
        else { Remove-Item -LiteralPath $try -Force -WhatIf:$false -ErrorAction SilentlyContinue }
    }
    catch { Write-VaultLog "Could not stage credentials for the workers: $_" 'WARN' }

    if ($nCred -gt 0) {
        Write-VaultLog "$nCred credential(s) staged for the workers - they can re-authenticate if a session expires"
    }
    else {
        Write-VaultLog 'No passwords are held in this process, so the workers run on the cached sessions alone.' 'WARN'
        Write-VaultLog 'If a session expires mid-run a worker cannot renew it and its remaining items will fail.' 'WARN'
        Write-VaultLog 'For a long run, log out and let the run prompt: vault logout, then start it again.' 'WARN'
    }

    $procs   = @()
    $offsets = @{}
    $started = Get-Date
    try {
        # Round robin rather than contiguous blocks. Document sizes are not evenly
        # distributed through an id list - they arrive grouped by whatever produced the
        # export - so contiguous shards routinely give one worker every large file.
        $shards = @{}
        for ($w = 1; $w -le $count; $w++) { $shards[$w] = New-Object System.Collections.ArrayList }
        for ($n = 0; $n -lt $Pending.Count; $n++) { [void]$shards[($n % $count) + 1].Add($Pending[$n]) }

        for ($w = 1; $w -le $count; $w++) {
            $wDir = Join-Path $root "w$w"
            if (-not (Test-Path -LiteralPath $wDir)) { New-Item -ItemType Directory -Path $wDir -Force -WhatIf:$false | Out-Null }
            if ($ShardKind -eq 'map') {
                $shardFile = Join-Path $wDir 'map.csv'
                $lines = New-Object System.Collections.ArrayList
                [void]$lines.Add('source,target')
                foreach ($pair in $shards[$w]) { [void]$lines.Add(('{0},{1}' -f $pair.Source, $pair.Target)) }
                Set-Content -LiteralPath $shardFile -Value $lines -Encoding ASCII -WhatIf:$false
                $inputArg = '-MapFile'
            }
            else {
                $shardFile = Join-Path $wDir 'ids.txt'
                Set-Content -LiteralPath $shardFile -Value ($shards[$w] -join "`r`n") -Encoding ASCII -WhatIf:$false
                $inputArg = '-IdFile'
            }

            # -Existing Fresh, because the worker folder is this run's alone and a
            # previous run's rows in it would be counted twice at merge time.
            # -Worker, not the credential file, is what marks worker mode: a worker must
            # never write the session file it shares with this process and its siblings,
            # whether or not it was given a password.
            $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($c.ScriptPath)`"") +
                       $Command +
                       @('-ConfigFile', "`"$($c.ConfigPath)`"",
                         $inputArg,     "`"$shardFile`"",
                         '-OutputRoot', "`"$wDir`"",
                         '-Worker',
                         '-Workers', '1', '-Existing', 'Fresh', '-NoPrompt', '-Yes')
            if ($credPath) { $argList += @('-CredentialFile', "`"$credPath`"") }
            $argList += $ExtraArgs

            $procs += Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -PassThru -WindowStyle Hidden
            Write-VaultLog "worker $w started (pid $($procs[-1].Id)) with $($shards[$w].Count) item(s)"
        }

        # No verb here on purpose. The summary at the end takes one because it reads
        # better with it; this line does not need one, and a hardcoded "moving" told an
        # operator running the validator that 200 documents were being transferred.
        Write-VaultLog "$count worker(s), $($Pending.Count) item(s). Per-worker output is under $root"

        # Progress is read from the workers' own results files - no shared state to
        # contend on, and a stalled worker shows up as a flat count rather than silence.
        while ($procs | Where-Object { -not $_.HasExited }) {
            Start-Sleep -Seconds 30
            $moved = 0
            for ($w = 1; $w -le $count; $w++) {
                $wDir = Join-Path $root "w$w"
                Read-VaultWorkerLog -Dir $wDir -Label "w$w" -Pattern $LogPattern -Offsets $offsets
                $f = Join-Path $wDir $ResultsName
                if (Test-Path -LiteralPath $f) {
                    try { $moved += @(Import-Csv -LiteralPath $f | Where-Object { $_.Status -eq $SuccessStatus }).Count } catch { }
                }
            }
            $elapsed = ((Get-Date) - $started).TotalSeconds
            $alive   = @($procs | Where-Object { -not $_.HasExited }).Count
            if (-not $RowsAreItems) {
                $rate = if ($elapsed -gt 0) { $moved / $elapsed } else { 0 }
                Write-VaultLog ("progress {0:N0} row(s) at {1:N2}/s overall, {2} of {3} worker(s) alive" -f `
                                $moved, $rate, $alive, $count)
            }
            elseif ($moved -gt 0 -and $elapsed -gt 0) {
                $rate = $moved / $elapsed
                $left = $Pending.Count - $moved
                $eta  = (Get-Date).AddSeconds($left / [math]::Max($rate, 0.0001))
                # "overall", said every time: this is the sum across all workers over
                # wall clock, not one worker's rate. Reading it as per-worker overstates
                # throughput by the worker count, which turns an eight hour wave into a
                # one hour one on paper.
                Write-VaultLog ("progress {0:N0}/{1:N0} at {2:N2}/s overall, {3} of {4} worker(s) alive, ETA {5:yyyy-MM-dd HH:mm}" -f `
                                $moved, $Pending.Count, $rate, $alive, $count, $eta)
            }
            else { Write-VaultLog "progress 0/$($Pending.Count), $alive of $count worker(s) alive" }
        }

        # Drain whatever each worker wrote between the last poll and exiting.
        for ($w = 1; $w -le $count; $w++) {
            Read-VaultWorkerLog -Dir (Join-Path $root "w$w") -Label "w$w" -Pattern $LogPattern -Offsets $offsets -MaxLines 50
        }
        foreach ($proc in $procs) {
            if ($proc.ExitCode -ne 0) { Write-VaultLog "worker pid $($proc.Id) exited $($proc.ExitCode) - some items failed" 'WARN' }
        }

        # Merge every worker's rows back into the one results file the operator reads.
        #
        # A worker's row REPLACES the earlier one for the same document. It has to: a
        # document that failed once and is retried already has a row, and keeping the
        # older one meant the retry succeeded, was counted as moved, and was still
        # recorded ERROR - so the next resume retried it again, and so would every
        # resume after that, for ever.
        $fresh = @{}
        $ok = 0; $bad = 0
        for ($w = 1; $w -le $count; $w++) {
            $f = Join-Path (Join-Path $root "w$w") $ResultsName
            if (-not (Test-Path -LiteralPath $f)) { Write-VaultLog "worker $w produced no results file" 'WARN'; continue }
            foreach ($row in (Import-Csv -LiteralPath $f)) {
                if ("$(Get-VaultField $row 'Status' '')" -eq $SuccessStatus) { $ok++ } else { $bad++ }
                $key = "$(Get-VaultField $row $KeyColumn '')"
                if ($key) { $fresh[$key] = $row }
            }
        }

        $merged  = New-Object System.Collections.ArrayList
        $written = @{}
        foreach ($k in $prior.Keys) {
            $key = "$k"
            if ($fresh.ContainsKey($key)) { [void]$merged.Add($fresh[$key]) } else { [void]$merged.Add($prior[$key]) }
            $written[$key] = $true
        }
        foreach ($key in $fresh.Keys) {
            if (-not $written.ContainsKey("$key")) { [void]$merged.Add($fresh[$key]) }
        }
        (ConvertTo-VaultUniformRows -Rows $merged) |
            Export-Csv -LiteralPath $resultsPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false

        # Counted from the merged rows rather than from each worker, because a rename is
        # a property of the result and the supervisor only ever sees the workers' output.
        # Read with Get-VaultField: rows written by an older version have no StagedName,
        # and under StrictMode reaching for a missing property is a terminating error.
        $renamed = 0
        if ($ReportRenames) { $renamed = @($merged | Where-Object {
            # The row's own answer where it has one. Rows written before the column
            # existed fall back to the comparison it was derived from.
            $flag = "$(Get-VaultField $_ 'Renamed' '')"
            if ($flag) { $flag -eq 'True' }
            else {
                $sn = "$(Get-VaultField $_ 'StagedName' '')"
                $sn -and ($sn -cne "$(Get-VaultField $_ 'Name' '')")
            }
        }).Count }
        if ($renamed) {
            Write-VaultLog "$renamed document(s) were written under a changed name - the rows where Name and StagedName differ" 'WARN'
        }

        # Merged before the summary is written, so the summary can name it. The few
        # supervisor lines after this point are in the supervisor's own log rather than
        # the merged one - which is the right way round, since they say where to look.
        $merged = ''
        try {
            $stamp = if ($script:VaultLogFile -and ($script:VaultLogFile -match '(\d{8}-\d{6})')) { $Matches[1] } else { Get-Date -Format 'yyyyMMdd-HHmmss' }
            $name  = ($LogPattern -replace '\*.*$', '') + $stamp + '-all.log'
            $merged = Merge-VaultWorkerLog -Root $root -Pattern $LogPattern -Count $count `
                          -OutPath (Join-Path $c.Out $name) -SupervisorLog $script:VaultLogFile
        }
        catch { Write-VaultLog "Could not merge the worker logs: $_" 'WARN' }

        $secs = ((Get-Date) - $started).TotalSeconds
        Write-VaultLog '----------------------------------------------------------------'
        $of = if ($RowsAreItems) { " of $($Pending.Count)" } else { '' }
        Write-VaultLog ("$Verb $ok$of item(s), $bad not $SuccessStatus, in $(Format-VaultDuration $secs) across $count worker(s)") $(if ($bad) { 'WARN' } else { 'OK' })
        Write-VaultLog "Results     : $resultsPath"
        if ($merged) { Write-VaultLog "Merged log  : $merged" }
        # Said at the end of every parallel run, because "should we use more workers" is
        # a question about this number and nothing else.
        foreach ($line in (Get-VaultBurstReport)) { Write-VaultLog "  $line" }
        $snap = Copy-VaultResultsSnapshot -Path $resultsPath
        if ($snap) { Write-VaultLog "This run    : $snap" }
        Write-VaultLog "Worker output: $root"
        return $bad
    }
    finally {
        # Ctrl-C stops THIS process. The workers are separate processes and carry on:
        # still uploading, still writing results, still holding scratch files open - so
        # an operator who stopped the run watches it continue, and the next run trips
        # over files an orphan is still using.
        #
        # Anything still alive when the supervisor leaves is stopped, whether it left by
        # finishing, by an error, or by Ctrl-C.
        $orphans = @($procs | Where-Object { $_ -and -not $_.HasExited })
        if ($orphans.Count) {
            Write-VaultLog "stopping $($orphans.Count) worker(s) still running: $(($orphans | ForEach-Object { $_.Id }) -join ', ')" 'WARN'
            foreach ($proc in $orphans) {
                try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop }
                catch { Write-VaultLog "could not stop worker pid $($proc.Id): $_" 'WARN' }
            }
            Write-VaultLog 'Their part-finished work is recorded, so resuming picks up where they stopped.' 'WARN'
        }

        # The credential file must not outlive the run, even on Ctrl-C.
        if ($credPath -and (Test-Path -LiteralPath $credPath)) {
            Remove-Item -LiteralPath $credPath -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }
}
