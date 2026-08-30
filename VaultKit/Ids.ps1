# Id lists and id maps.
#
# Every rule here was met in a real export, not imagined. A spreadsheet arrives as
# whatever produced it left it: a byte order mark, tabs instead of commas, two columns
# called "Created By", headers written for people rather than parsers, a row per file so
# one document appears eight times, and #N/A where a lookup found nothing.

function Export-VaultIdMap {
    # Write the canonical map. One shape out, whatever went in.
    param(
        [Parameter(Mandatory)]$Map,
        [Parameter(Mandatory)][string]$Path
    )
    $rows = New-Object System.Collections.ArrayList
    foreach ($k in ($Map.Keys | Sort-Object { [long]$_ })) {
        [void]$rows.Add([pscustomobject]@{ source_id = "$k"; target_id = "$($Map[$k])" })
    }
    $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    return $rows.Count
}

function Import-VaultIdList {
    # One id per line. Tolerant because this file is usually pasted out of Excel or a
    # Library grid: a header, quotes, blank lines, #-comments, a trailing comma.
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$LegacyNames = @()
    )
    $resolved = Resolve-VaultInput -Path $Path -LegacyNames $LegacyNames
    if (-not $resolved) { throw "Id list not found: $Path" }

    $ids  = New-Object System.Collections.ArrayList
    $seen = @{}
    $skipped = New-Object System.Collections.ArrayList
    $dupes = 0
    $n = 0

    foreach ($raw in (Get-Content -LiteralPath $resolved)) {
        $n++
        $t = "$raw".Trim().Trim([char]0xFEFF).Trim('"', "'").TrimEnd(',').Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        if ($n -eq 1 -and $t -match '^(id|document.?id)$') { continue }
        if ($t -notmatch '^\d+$') { [void]$skipped.Add("line ${n}: '$t'"); continue }
        if ($seen.ContainsKey($t)) { $dupes++; continue }
        $seen[$t] = $true
        [void]$ids.Add($t)
    }

    if ($skipped.Count) {
        Write-VaultLog "$($skipped.Count) line(s) in $resolved are not ids and were skipped" 'WARN'
        foreach ($s in ($skipped | Select-Object -First 5)) { Write-VaultLog "  $s" 'WARN' }
        if ($skipped.Count -gt 5) { Write-VaultLog "  ... and $($skipped.Count - 5) more" 'WARN' }
    }
    if ($dupes) { Write-VaultLog "$dupes duplicate id(s) dropped" }
    if ($ids.Count -eq 0) { throw "No ids found in $resolved" }

    Write-VaultLog "$($ids.Count) id(s) from $resolved" 'OK'
    return @($ids)
}

function Resolve-VaultInput {
    # Working directory first - that is where an operator drops a file - then beside the
    # script, then any previous name for the same input. Returns $null if nothing is
    # found, and the absolute path otherwise, which is what gets logged: there is then
    # never a question of which file was read.
    param([Parameter(Mandatory)][string]$Path, [string[]]$LegacyNames = @())

    $tries = @($Path, [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)))
    if ($PSScriptRoot) { $tries += (Join-Path (Split-Path -Parent $PSScriptRoot) $Path) }
    foreach ($legacy in $LegacyNames) {
        $tries += [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $legacy))
    }
    foreach ($t in $tries) {
        if ($t -and (Test-Path -LiteralPath $t)) {
            $full = (Resolve-Path -LiteralPath $t).ProviderPath
            $leaf = Split-Path -Leaf $full
            if ($leaf -ne (Split-Path -Leaf $Path)) {
                Write-VaultLog "Using $leaf - rename it to $(Split-Path -Leaf $Path) when convenient" 'WARN'
            }
            return $full
        }
    }
    return $null
}

function Import-VaultDelimitedFile {
    # Read a spreadsheet export into rows, whatever shape it arrived in. Returns the rows
    # and the column names actually used, since a duplicate header gets suffixed.
    param([Parameter(Mandatory)][string]$Path)

    $resolved = $null
    foreach ($t in @($Path, [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)))) {
        if ($t -and (Test-Path -LiteralPath $t)) { $resolved = (Resolve-Path -LiteralPath $t).ProviderPath; break }
    }
    if (-not $resolved) {
        throw ("Not found. Looked for:`n    {0}" -f
               [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)))
    }

    # Excel's "CSV UTF-8" writes a byte order mark, which Windows PowerShell 5.1 reads as
    # literal characters glued to the first column name - so source_id arrives as
    # something no name match would ever find.
    $bom = $false
    try {
        $head3 = New-Object byte[] 3
        $fsb = [IO.File]::OpenRead($resolved)
        try { [void]$fsb.Read($head3, 0, 3) } finally { $fsb.Dispose() }
        if ($head3[0] -eq 0xEF -and $head3[1] -eq 0xBB -and $head3[2] -eq 0xBF) { $bom = $true }
    } catch { }

    $header = @(Get-Content -LiteralPath $resolved -TotalCount 1)
    if (-not $header.Count) { throw "$resolved is empty" }
    $header[0] = $header[0].TrimStart([char]0xFEFF)

    # The delimiter is not implied by the extension. A tab-separated export read as
    # comma-separated yields one column and a confusing "cannot work out which columns"
    # error rather than an obvious one.
    $delims = @{ ',' = ([regex]::Matches($header[0], ',')).Count
                 "`t" = ([regex]::Matches($header[0], "`t")).Count
                 ';' = ([regex]::Matches($header[0], ';')).Count
                 '|' = ([regex]::Matches($header[0], '\|')).Count }
    $delim = ','; $best = 0
    foreach ($d in $delims.Keys) { if ($delims[$d] -gt $best) { $best = $delims[$d]; $delim = $d } }
    if ($best -eq 0) { throw "$resolved has no delimiter in its header: '$($header[0])'. It needs at least two columns." }

    # Import-Csv refuses a sheet with a repeated header - "The member 'Created By' is
    # already present" - and a real export usually has one. Only a couple of columns
    # matter, so a duplicate elsewhere must not stop the job.
    $all = if ($bom) { @(Get-Content -LiteralPath $resolved -Encoding UTF8) }
           else      { @(Get-Content -LiteralPath $resolved) }
    if ($all.Count -lt 2) { throw "$resolved has a header but no rows" }

    $names = New-Object System.Collections.ArrayList
    $used  = @{}
    $renamed = 0
    foreach ($raw in ($header[0] -split [regex]::Escape($delim))) {
        $nm = $raw.Trim().Trim('"')
        if (-not $nm) { $nm = 'Column' }
        $base = $nm; $k = 2
        while ($used.ContainsKey($nm.ToLowerInvariant())) { $nm = "${base}_$k"; $k++; $renamed++ }
        $used[$nm.ToLowerInvariant()] = $true
        [void]$names.Add($nm)
    }
    if ($renamed) { Write-VaultLog "$renamed duplicate column name(s) in $(Split-Path -Leaf $resolved) suffixed to keep them apart" }

    $rows = @($all | Select-Object -Skip 1 | ConvertFrom-Csv -Header $names -Delimiter $delim)
    if ($rows.Count -eq 0) { throw "$resolved has a header but no rows" }

    $shown = if ($delim -eq "`t") { 'tab' } else { $delim }
    return [pscustomobject]@{ Path = $resolved; Rows = $rows; Names = @($names); Delimiter = $shown }
}

# What the last Import-VaultIdMap decided. A side channel rather than a changed return
# type, because several callers want the map and only `map check` wants the reasoning.
$script:VaultIdMapStats = @{}

# The canonical map. This is what the kit WRITES, and what it looks for before it starts
# guessing - two columns, named, comma separated, one pair per row:
#
#     source_id,target_id
#     55056,207311
#
# Anything else is still read, because a real map arrives as whatever Excel produced and
# refusing it would just move the work to a person. But a file in this shape needs no
# detection at all, and `map write` turns one into the other.
$script:VaultCanonicalSource = @('source_id', 'sourceid', 'source')
$script:VaultCanonicalTarget = @('target_id', 'targetid', 'target')

function Import-VaultIdMap {
    # source id -> target id, from a spreadsheet export.
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$SourceColumn = '',
        [string]$TargetColumn = '',
        [string[]]$LegacyNames = @()
    )
    $resolved = Resolve-VaultInput -Path $Path -LegacyNames $LegacyNames
    if (-not $resolved) {
        $where = @([IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $Path)))
        throw ("Id map not found. Looked in:`n" + (($where | ForEach-Object { "    $_" }) -join "`n"))
    }

    # Excel's "CSV UTF-8" writes a byte order mark, which Windows PowerShell 5.1 reads as
    # literal characters glued to the first column name - so source_id arrives as
    # something no name match would ever find.
    $bom = $false
    try {
        $head3 = New-Object byte[] 3
        $fsb = [IO.File]::OpenRead($resolved)
        try { [void]$fsb.Read($head3, 0, 3) } finally { $fsb.Dispose() }
        if ($head3[0] -eq 0xEF -and $head3[1] -eq 0xBB -and $head3[2] -eq 0xBF) { $bom = $true }
    } catch { }

    $header = @(Get-Content -LiteralPath $resolved -TotalCount 1)
    if (-not $header.Count) { throw "Id map $resolved is empty" }
    $header[0] = $header[0].TrimStart([char]0xFEFF)

    # The delimiter is not implied by the extension. A tab-separated export read as
    # comma-separated yields one column and a confusing "cannot work out which columns"
    # error rather than an obvious one.
    $delims = @{ ',' = ([regex]::Matches($header[0], ',')).Count
                 "`t" = ([regex]::Matches($header[0], "`t")).Count
                 ';' = ([regex]::Matches($header[0], ';')).Count
                 '|' = ([regex]::Matches($header[0], '\|')).Count }
    $delim = ','; $best = 0
    foreach ($d in $delims.Keys) { if ($delims[$d] -gt $best) { $best = $delims[$d]; $delim = $d } }
    if ($best -eq 0) { throw "Id map $resolved has no delimiter in its header: '$($header[0])'. It needs at least two columns." }
    $shown = if ($delim -eq "`t") { 'tab' } else { $delim }

    # Import-Csv refuses a sheet with a repeated header - "The member 'Created By' is
    # already present" - and a real export usually has one. Only two columns matter, so a
    # duplicate elsewhere must not stop the job.
    $all = if ($bom) { @(Get-Content -LiteralPath $resolved -Encoding UTF8) }
           else      { @(Get-Content -LiteralPath $resolved) }
    if ($all.Count -lt 2) { throw "Id map $resolved has a header but no rows" }

    $names = New-Object System.Collections.ArrayList
    $used  = @{}
    $renamed = 0
    foreach ($raw in ($header[0] -split [regex]::Escape($delim))) {
        $nm = $raw.Trim().Trim('"')
        if (-not $nm) { $nm = 'Column' }
        $base = $nm; $k = 2
        while ($used.ContainsKey($nm.ToLowerInvariant())) { $nm = "${base}_$k"; $k++; $renamed++ }
        $used[$nm.ToLowerInvariant()] = $true
        [void]$names.Add($nm)
    }
    if ($renamed) { Write-VaultLog "$renamed duplicate column name(s) suffixed to keep them apart" }

    $rows = @($all | Select-Object -Skip 1 | ConvertFrom-Csv -Header $names -Delimiter $delim)
    if ($rows.Count -eq 0) { throw "Id map $resolved has a header but no rows" }
    Write-VaultLog "Id map columns: $($names -join ', ')"

    # Match on what a header MEANS, not a list of exact spellings. Real headers are
    # written for people - "Source (old) Document ID" is perfectly clear and matches no
    # fixed name at all.
    function Test-IsIdColumn {
        param([string]$Header, [string[]]$Words)
        $n = ($Header -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
        if ($n -notmatch 'id$|id[^a-z]|^id') { return $false }
        foreach ($w in $Words) { if ($n -like "*$w*") { return $true } }
        return $false
    }

    $srcCol = $SourceColumn
    $tgtCol = $TargetColumn
    $how    = 'named on the command line'

    # The canonical names first, exactly. Detection is for files written for people;
    # a file written by this kit should not be guessed at - and the heuristic below
    # requires the header to contain "id", so a column called plainly "source" would
    # otherwise fail to be found at all.
    if (-not $srcCol -and -not $tgtCol) {
        $lower = @{}
        foreach ($n in $names) { $lower[($n -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()] = $n }
        foreach ($cand in $script:VaultCanonicalSource) { if ($lower.ContainsKey($cand)) { $srcCol = $lower[$cand]; break } }
        foreach ($cand in $script:VaultCanonicalTarget) { if ($lower.ContainsKey($cand)) { $tgtCol = $lower[$cand]; break } }
        if ($srcCol -and $tgtCol) { $how = 'canonical header' }
        else { $srcCol = ''; $tgtCol = '' }
    }
    if (-not $srcCol -and -not $tgtCol) { $how = 'detected from the header wording' }

    if (-not $srcCol) {
        $c = @($names | Where-Object { Test-IsIdColumn -Header $_ -Words @('source', 'old', 'from', 'legacy') })
        if ($c.Count -eq 1) { $srcCol = $c[0] }
        elseif ($c.Count -gt 1) { throw "More than one column could be the source id: $($c -join ', '). Name it explicitly." }
    }
    if (-not $tgtCol) {
        $c = @($names | Where-Object { Test-IsIdColumn -Header $_ -Words @('destination', 'target', 'new', 'to') })
        if ($c.Count -eq 1) { $tgtCol = $c[0] }
        elseif ($c.Count -gt 1) { throw "More than one column could be the target id: $($c -join ', '). Name it explicitly." }
    }
    if (-not $srcCol -or -not $tgtCol) {
        throw "Could not work out which columns hold the ids in $resolved. Headers: $($names -join ', ')."
    }

    Write-VaultLog "Id columns: '$srcCol' -> '$tgtCol' ($how)"

    $map = @{}
    $bad = 0; $sci = 0; $dupes = 0
    $badRows  = New-Object System.Collections.ArrayList
    $conflict = New-Object System.Collections.ArrayList
    $rowNo = 1

    foreach ($row in $rows) {
        $rowNo++
        $a = "$(Get-VaultField $row $srcCol '')".Trim()
        $b = "$(Get-VaultField $row $tgtCol '')".Trim()

        if ($a -match '^\d+(\.\d+)?[eE][+-]?\d+$' -or $b -match '^\d+(\.\d+)?[eE][+-]?\d+$') { $sci++; $bad++; continue }
        if ($a -notmatch '^\d+$' -or $b -notmatch '^\d+$') {
            $bad++
            [void]$badRows.Add(("line {0}: source='{1}' target='{2}'" -f $rowNo, $a, $b))
            continue
        }
        if ($map.ContainsKey($a)) {
            # A row per file means one document appears many times. Repeats are expected;
            # a repeat pointing somewhere ELSE is not.
            if ($map[$a] -ne $b) { [void]$conflict.Add("$a -> $($map[$a]) and $b") } else { $dupes++ }
            continue
        }
        $map[$a] = $b
    }

    $script:VaultIdMapStats = @{
        Path = $resolved; Delimiter = $shown; Bom = $bom; Headers = @($names)
        SourceColumn = $srcCol; TargetColumn = $tgtCol; How = $how
        Rows = $rows.Count; Pairs = $map.Count; Skipped = $bad
        RepeatedPairs = $dupes; Conflicts = $conflict.Count; Scientific = $sci
        BadRows = @($badRows)
        Canonical = ($how -eq 'canonical header' -and $shown -eq ',')
    }

    if ($sci) {
        # Refuse rather than continue on the rows that survived: a mangled id is a
        # document that silently never gets processed while the run still reports success.
        throw @"
$sci row(s) in $resolved hold ids in scientific notation, e.g. 5.5283E+04.

Excel does that to long numbers on export and the digits are gone - they cannot be
recovered from the file. Re-export with both id columns formatted as Text.
"@
    }
    if ($conflict.Count) {
        $show = ($conflict | Select-Object -First 5) -join '; '
        throw "The map sends the same source to two different targets: $show. Fix the map - choosing between them is not something this can do."
    }
    if ($bad) {
        Write-VaultLog "$bad row(s) in $resolved had no usable id pair and were skipped - those are NOT processed" 'WARN'
        foreach ($br in ($badRows | Select-Object -First 10)) { Write-VaultLog "  $br" 'WARN' }
        if ($badRows.Count -gt 10) { Write-VaultLog "  ... and $($badRows.Count - 10) more" 'WARN' }

        $excel = @($badRows | Where-Object { $_ -match '#(N/A|REF!|VALUE!|NAME\?|DIV/0!|NUM!|NULL!)' })
        if ($excel.Count) {
            Write-VaultLog "  $($excel.Count) hold an Excel error such as #N/A - the lookup in the sheet found no match," 'WARN'
            Write-VaultLog '  so those have no target id. Either they were never migrated, or the formula missed them.' 'WARN'
        }
        $distinct = @($badRows | ForEach-Object { ($_ -split "source='")[1] -split "'" | Select-Object -First 1 } |
                      Where-Object { $_ } | Select-Object -Unique)
        if ($distinct.Count -and $distinct.Count -ne $badRows.Count) {
            Write-VaultLog "  $($distinct.Count) distinct source(s) affected: $($distinct -join ', ')" 'WARN'
        }
    }
    if ($dupes) { Write-VaultLog "$dupes repeated row(s) for pairs already mapped - expected when the sheet has a row per file" }
    if ($map.Count -eq 0) { throw "No usable id pairs in $resolved" }

    Write-VaultLog "$($map.Count) id pair(s) from $resolved ($shown-separated, '$srcCol' -> '$tgtCol')" 'OK'
    return $map
}
