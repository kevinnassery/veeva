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
        [string[]]$ExtraArgs = @()
    )
    $c     = $Context
    $count = [math]::Min($Workers, $Pending.Count)
    $root  = Join-Path $c.Out 'workers'
    if (-not (Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root -Force -WhatIf:$false | Out-Null }

    $resultsPath = Join-Path $c.Out $ResultsName
    $prior = [ordered]@{}
    if (Test-Path -LiteralPath $resultsPath) {
        foreach ($row in (Import-Csv -LiteralPath $resultsPath)) {
            $k = "$(Get-VaultField $row $KeyColumn '')"
            if ($k) { $prior[$k] = $row }
        }
    }

    $credPath = Join-Path $c.Out ('.worker-cred-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.xml')
    $nCred = Export-VaultCredentials -Path $credPath
    if ($nCred -lt 1) {
        Remove-Item -LiteralPath $credPath -Force -WhatIf:$false -ErrorAction SilentlyContinue
        throw @'
Cannot start workers: no credentials are held in memory to pass to them.

A worker runs hidden and cannot be prompted, so it needs the passwords this process
was given. Run the command from a console so it can ask, rather than relying on a
cached session file alone.
'@
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
            $shardFile = Join-Path $wDir 'ids.txt'
            Set-Content -LiteralPath $shardFile -Value ($shards[$w] -join "`r`n") -Encoding ASCII -WhatIf:$false

            # -Existing Fresh, because the worker folder is this run's alone and a
            # previous run's rows in it would be counted twice at merge time.
            $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($c.ScriptPath)`"") +
                       $Command +
                       @('-ConfigFile',    "`"$($c.ConfigPath)`"",
                         '-IdFile',        "`"$shardFile`"",
                         '-OutputRoot',    "`"$wDir`"",
                         '-CredentialFile', "`"$credPath`"",
                         '-Workers', '1', '-Existing', 'Fresh', '-NoPrompt', '-Yes') +
                       $ExtraArgs

            $procs += Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -PassThru -WindowStyle Hidden
            Write-VaultLog "worker $w started (pid $($procs[-1].Id)) with $($shards[$w].Count) item(s)"
        }

        Write-VaultLog "$count worker(s) moving $($Pending.Count) item(s). Per-worker output is under $root"

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
                    try { $moved += @(Import-Csv -LiteralPath $f | Where-Object { $_.Status -eq 'SUCCESS' }).Count } catch { }
                }
            }
            $elapsed = ((Get-Date) - $started).TotalSeconds
            $alive   = @($procs | Where-Object { -not $_.HasExited }).Count
            if ($moved -gt 0 -and $elapsed -gt 0) {
                $rate = $moved / $elapsed
                $left = $Pending.Count - $moved
                $eta  = (Get-Date).AddSeconds($left / [math]::Max($rate, 0.0001))
                Write-VaultLog ("progress {0:N0}/{1:N0} at {2:N2}/s, {3} worker(s) alive, ETA {4:yyyy-MM-dd HH:mm}" -f `
                                $moved, $Pending.Count, $rate, $alive, $eta)
            }
            else { Write-VaultLog "progress 0/$($Pending.Count), $alive worker(s) alive" }
        }

        # Drain whatever each worker wrote between the last poll and exiting.
        for ($w = 1; $w -le $count; $w++) {
            Read-VaultWorkerLog -Dir (Join-Path $root "w$w") -Label "w$w" -Pattern $LogPattern -Offsets $offsets -MaxLines 50
        }
        foreach ($proc in $procs) {
            if ($proc.ExitCode -ne 0) { Write-VaultLog "worker pid $($proc.Id) exited $($proc.ExitCode) - some items failed" 'WARN' }
        }

        # Merge every worker's rows back into the one results file the operator reads.
        $merged  = New-Object System.Collections.ArrayList
        $seen    = @{}
        foreach ($k in $prior.Keys) { [void]$merged.Add($prior[$k]); $seen["$k"] = $true }
        $ok = 0; $bad = 0
        for ($w = 1; $w -le $count; $w++) {
            $f = Join-Path (Join-Path $root "w$w") $ResultsName
            if (-not (Test-Path -LiteralPath $f)) { Write-VaultLog "worker $w produced no results file" 'WARN'; continue }
            foreach ($row in (Import-Csv -LiteralPath $f)) {
                if ("$(Get-VaultField $row 'Status' '')" -eq 'SUCCESS') { $ok++ } else { $bad++ }
                if ($seen.ContainsKey("$(Get-VaultField $row $KeyColumn '')")) { continue }
                [void]$merged.Add($row)
            }
        }
        $merged | Export-Csv -LiteralPath $resultsPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false

        $secs = ((Get-Date) - $started).TotalSeconds
        Write-VaultLog '----------------------------------------------------------------'
        Write-VaultLog ("Moved $ok of $($Pending.Count) item(s), $bad failed, in {0:N1} hour(s) across $count worker(s)" -f ($secs / 3600)) $(if ($bad) { 'WARN' } else { 'OK' })
        Write-VaultLog "Results     : $resultsPath"
        Write-VaultLog "Worker output: $root"
        return $bad
    }
    finally {
        # The credential file must not outlive the run, even on Ctrl-C.
        if (Test-Path -LiteralPath $credPath) {
            Remove-Item -LiteralPath $credPath -Force -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }
}
