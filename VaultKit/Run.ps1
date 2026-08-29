# Disk budget, scratch space, resumable results, and the run lock.
#
# Everything a long job needs to be interruptible and honest about what it did.

# --------------------------------------------------------------------------------------
# Disk
# --------------------------------------------------------------------------------------

function Get-VaultFreeSpace {
    param([Parameter(Mandatory)][string]$Path)
    $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    try { return (New-Object IO.DriveInfo $root).AvailableFreeSpace }
    catch { return -1 }
}

function Assert-VaultDiskBudget {
    # Stop before the volume fills, not after. Checked ahead of every download, because
    # the whole streaming design rests on the scratch folder staying nearly empty.
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][long]$Needed,
        [int]$ReserveMB = 2048
    )
    $free = Get-VaultFreeSpace -Path $Path
    if ($free -lt 0 -or $Needed -le 0) { return }
    if (($free - $Needed) -lt ($ReserveMB * 1MB)) {
        throw "not enough disk: $(Format-VaultBytes $Needed) needed, $(Format-VaultBytes $free) free, ${ReserveMB}MB reserve"
    }
}

function New-VaultScratch {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Name)
    $dir = Join-Path $Root $Name
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false | Out-Null
    }
    return $dir
}

function Remove-VaultScratchFile {
    # Success or failure, the local copy goes - that is what keeps disk bounded. Logged
    # every time with the free space left, because a delete that quietly stopped working
    # would otherwise surface as a full volume hours later instead of a line in the log.
    #
    # Retried, because the delete competes with whatever scans files as they are written.
    # Windows Defender opening a freshly downloaded PDF is enough to make Remove-Item
    # fail with "being used by another process", and it lets go a moment later.
    param(
        [Parameter(Mandatory)][AllowNull()]$File,
        [Parameter(Mandatory)][string]$Scratch,
        [string]$Prefix = '',
        [int]$Attempts = 5
    )
    if (-not $File) { return }
    if (-not (Test-Path -LiteralPath $File.Path)) { return }

    for ($n = 1; $n -le $Attempts; $n++) {
        try {
            Remove-Item -LiteralPath $File.Path -Force -WhatIf:$false
            $free = Get-VaultFreeSpace -Path $Scratch
            $note = if ($free -ge 0) { ", $(Format-VaultBytes $free) free" } else { '' }
            Write-VaultLog "$Prefix scratch file deleted ($(Format-VaultBytes $File.Size)$note)"
            return
        }
        catch {
            if ($n -eq $Attempts) {
                Write-VaultLog "Could not delete $($File.Path) after $Attempts attempts: $_" 'WARN'
                return
            }
            Start-Sleep -Milliseconds (200 * $n)
        }
    }
}

function Remove-VaultScratchDir {
    # The whole per-item folder, once its files are gone. Deleting a directory that a
    # scanner still holds a file in fails the same way, so it gets the same patience.
    param([Parameter(Mandatory)][string]$Path, [int]$Attempts = 5)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    for ($n = 1; $n -le $Attempts; $n++) {
        try { Remove-Item -LiteralPath $Path -Recurse -Force -WhatIf:$false; return }
        catch {
            if ($n -eq $Attempts) { return }   # Report-VaultLeftovers will name it
            Start-Sleep -Milliseconds (200 * $n)
        }
    }
}

function Report-VaultLeftovers {
    param([Parameter(Mandatory)][string]$Scratch)
    # Recurse: files live in a folder per item now, so a non-recursive look sees an
    # empty scratch root while gigabytes sit one level down.
    $left = @(Get-ChildItem -LiteralPath $Scratch -File -Recurse -ErrorAction SilentlyContinue)
    if (-not $left.Count) { return }
    $bytes = ($left | Measure-Object -Property Length -Sum).Sum
    Write-VaultLog "$($left.Count) file(s) left in $Scratch taking $(Format-VaultBytes $bytes) - safe to delete" 'WARN'
}

# --------------------------------------------------------------------------------------
# Results
#
# Rewritten after every item, so an interrupted run still leaves a usable file. Rows an
# earlier run recorded for items this run did not touch are carried through rather than
# dropped - otherwise a capped or resumed run would truncate the file to just what it
# processed, losing the record of everything already done.
# --------------------------------------------------------------------------------------

function New-VaultResults {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$KeyColumn,
        [string[]]$DoneStatuses = @(),
        [ValidateSet('Prompt', 'Resume', 'Fresh')][string]$Existing = 'Resume'
    )
    $prior = [ordered]@{}
    $done  = @{}

    if (Test-Path -LiteralPath $Path) {
        $choice = $Existing
        if ($choice -eq 'Prompt') {
            $rows = @(Import-Csv -LiteralPath $Path)
            Write-Host ''
            Write-Host "Results from an earlier run are here: $($rows.Count) row(s) in $Path" -ForegroundColor Yellow
            if ($Host.UI.RawUI -and -not [Console]::IsInputRedirected) {
                $a = Read-Host 'Resume (keep them) or start Fresh (rotate aside)? [R]esume/[F]resh'
                $choice = if ($a -match '^[Ff]') { 'Fresh' } else { 'Resume' }
            }
            else { $choice = 'Resume' }
        }
        if ($choice -eq 'Fresh') {
            $when = (Get-Item -LiteralPath $Path).LastWriteTime.ToString('yyyyMMdd-HHmmss')
            $moved = [IO.Path]::Combine([IO.Path]::GetDirectoryName($Path),
                     ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($Path), $when, [IO.Path]::GetExtension($Path)))
            Move-Item -LiteralPath $Path -Destination $moved -Force -WhatIf:$false
            Write-VaultLog "Rotated previous results to $(Split-Path -Leaf $moved)"
        }
        else {
            foreach ($row in (Import-Csv -LiteralPath $Path)) {
                $k = "$(Get-VaultField $row $KeyColumn '')"
                if (-not $k) { continue }
                $prior[$k] = $row
                if ($DoneStatuses -contains "$(Get-VaultField $row 'Status' '')") { $done[$k] = $true }
            }
            if ($done.Count) { Write-VaultLog "$($done.Count) item(s) already completed by an earlier run - not repeated" }
        }
    }

    return [pscustomobject]@{
        Path      = $Path
        KeyColumn = $KeyColumn
        Prior     = $prior
        Done      = $done
        Rows      = (New-Object System.Collections.ArrayList)
    }
}

function ConvertTo-VaultUniformRows {
    # Every row given every column, before anything is exported.
    #
    # Export-Csv takes its header from the FIRST object it is handed and then writes only
    # those properties for every row after it. Results files outlive the version that
    # wrote them: a resumed run merges rows from before a column existed with rows from
    # after, and if an older row happens to come first, the newer column is dropped from
    # the whole file. Silently, with an exit code of zero.
    #
    # Columns keep first-seen order, so a file's shape stays recognisable and anything
    # added later appears at the end.
    param([Parameter(Mandatory)][AllowEmptyCollection()]$Rows)
    $all = @($Rows)
    if (-not $all.Count) { return $all }

    $cols = New-Object System.Collections.ArrayList
    foreach ($r in $all) {
        foreach ($p in $r.PSObject.Properties) {
            if (-not $cols.Contains($p.Name)) { [void]$cols.Add($p.Name) }
        }
    }

    $out = New-Object System.Collections.ArrayList
    foreach ($r in $all) {
        $flat = [ordered]@{}
        foreach ($c in $cols) {
            $prop = $r.PSObject.Properties[$c]
            $flat[$c] = if ($prop) { $prop.Value } else { '' }
        }
        [void]$out.Add([pscustomobject]$flat)
    }
    return $out
}

function Save-VaultResults {
    param([Parameter(Mandatory)]$Results)
    $current = @{}
    foreach ($r in $Results.Rows) { $current["$(Get-VaultField $r $Results.KeyColumn '')"] = $r }

    $out = New-Object System.Collections.ArrayList
    $written = @{}
    foreach ($k in $Results.Prior.Keys) {
        $key = "$k"
        if ($current.ContainsKey($key)) { [void]$out.Add($current[$key]) } else { [void]$out.Add($Results.Prior[$key]) }
        $written[$key] = $true
    }
    foreach ($r in $Results.Rows) {
        $key = "$(Get-VaultField $r $Results.KeyColumn '')"
        if (-not $written.ContainsKey($key)) { [void]$out.Add($r) }
    }
    (ConvertTo-VaultUniformRows -Rows $out) |
        Export-Csv -LiteralPath $Results.Path -NoTypeInformation -Encoding UTF8 -WhatIf:$false
}

function Format-VaultDuration {
    param([double]$Seconds)
    if ($Seconds -ge 3600) { return ('{0:N1} hour(s)'   -f ($Seconds / 3600)) }
    if ($Seconds -ge 60)   { return ('{0:N1} minute(s)' -f ($Seconds / 60)) }
    return ('{0:N0} second(s)' -f $Seconds)
}

function Copy-VaultResultsSnapshot {
    # This run's own copy of its results, stamped, and never written again.
    #
    # The working file keeps a fixed name because resume depends on it: a run has to
    # find what an earlier one finished, and it cannot do that if every run writes to a
    # new name. But that fixed name is then merged into, rotated aside, or overwritten
    # by whatever runs next - so the record of what THIS run did does not survive it.
    #
    # The snapshot is that record. It carries the same timestamp as the run's log, so a
    # report and the log that explains it can be paired without guessing.
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }

    $stamp = ''
    if ($script:VaultLogFile -and ($script:VaultLogFile -match '(\d{8}-\d{6})')) { $stamp = $Matches[1] }
    if (-not $stamp) { $stamp = Get-Date -Format 'yyyyMMdd-HHmmss' }

    $snap = [IO.Path]::Combine(
        [IO.Path]::GetDirectoryName($Path),
        ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($Path), $stamp, [IO.Path]::GetExtension($Path)))
    try {
        Copy-Item -LiteralPath $Path -Destination $snap -Force -WhatIf:$false
        return $snap
    }
    catch {
        Write-VaultLog "Could not write the results snapshot: $_" 'WARN'
        return ''
    }
}

function Add-VaultResult {
    param([Parameter(Mandatory)]$Results, [Parameter(Mandatory)]$Row)
    [void]$Results.Rows.Add($Row)
    Save-VaultResults -Results $Results
}

# --------------------------------------------------------------------------------------
# Run lock
#
# An update replaces the scripts in the operator's folder. Doing that mid-run is not
# harmless, so a running job leaves a lock that the updater refuses to walk over.
# --------------------------------------------------------------------------------------

$script:VaultLock = ''

# Workers take no lock. The supervisor holds one for the whole run, and a worker taking
# the same one means nine processes writing one file - then the first worker to FINISH
# deletes it, disarming the guard while the run is still going. That is worse than no
# lock at all, because it looks like one is held.
$script:VaultLockEnabled = $true

function Set-VaultLockEnabled {
    param([bool]$Value)
    $script:VaultLockEnabled = $Value
}

function Start-VaultLock {
    param([Parameter(Mandatory)][string]$Name)
    if (-not $script:VaultLockEnabled) { return }
    $here = $PSScriptRoot
    if ($here) { $here = Split-Path -Parent $here } else { $here = (Get-Location).ProviderPath }
    $script:VaultLock = Join-Path $here ".run-$Name.lock"
    try {
        Set-Content -LiteralPath $script:VaultLock -Encoding ASCII -WhatIf:$false -Value @(
            "pid=$PID", "command=$Name", "started=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    }
    catch { Write-VaultLog "Could not write the run lock: $_" 'WARN' }
}

function Stop-VaultLock {
    # Explicitly, not only on an exit event: a run that ends badly may never reach the
    # event, and a lock left behind blocks the next update.
    if ($script:VaultLock -and (Test-Path -LiteralPath $script:VaultLock)) {
        try { Remove-Item -LiteralPath $script:VaultLock -Force -WhatIf:$false } catch { }
    }
}
