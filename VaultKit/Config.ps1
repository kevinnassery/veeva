# One config file, read once.
#
# Sectioned, unlike the flat inis it replaces. That is not decoration: the attachment
# sync wanted Mode = REPORT|SYNC and the validator wanted FAST|DEEP, and sharing one flat
# file meant whichever ran second was misconfigured. Sections give each command its own
# namespace and let the vaults be declared once.
#
#   [vault]
#   source = your-source-vault.veevavault.com
#   target = your-target-vault.veevavault.com
#   api    = v26.2
#
#   [paths]
#   output = C:\Users\you\vault-work
#
#   [attachments]
#   map = attachments-map.csv

function Import-VaultConfig {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { throw "Config not found: $Path" }

    $cfg     = @{}
    $section = 'general'
    $cfg[$section] = @{}

    foreach ($raw in (Get-Content -LiteralPath $Path)) {
        $line = "$raw".Trim().TrimStart([char]0xFEFF)
        if (-not $line -or $line.StartsWith('#') -or $line.StartsWith(';')) { continue }

        if ($line.StartsWith('[') -and $line.EndsWith(']')) {
            $section = $line.Trim('[', ']').Trim().ToLowerInvariant()
            if (-not $cfg.ContainsKey($section)) { $cfg[$section] = @{} }
            continue
        }

        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $line.Substring(0, $eq).Trim().ToLowerInvariant()
        $val = $line.Substring($eq + 1).Trim()

        # An inline comment is whitespace then # or ; - but only outside quotes, so a
        # value like "C:\x # y" survives if it is quoted.
        if ($val -notmatch '^["'']') { $val = ($val -split '\s+[#;]', 2)[0].TrimEnd() }
        $val = $val.Trim('"', "'")
        $cfg[$section][$key] = [Environment]::ExpandEnvironmentVariables($val)
    }
    return $cfg
}

function Get-VaultSetting {
    # Read one setting, with the default applied when the key is absent OR blank. Blank
    # has to count as absent: an operator clearing a value expects the default back, not
    # an empty string threaded into a path.
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        $Default = ''
    )
    $s = $Section.ToLowerInvariant()
    $k = $Key.ToLowerInvariant()
    if (-not $Config.ContainsKey($s)) { return $Default }
    if (-not $Config[$s].ContainsKey($k)) { return $Default }
    $v = $Config[$s][$k]
    if ($null -eq $v -or ($v -is [string] -and [string]::IsNullOrWhiteSpace($v))) { return $Default }
    return $v
}

function Get-VaultRequired {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$ConfigPath
    )
    $v = Get-VaultSetting -Config $Config -Section $Section -Key $Key
    if (-not $v) { throw "[$Section] $Key is not set in $ConfigPath" }
    return $v
}

function Set-VaultSetting {
    # Write ONE key back into the ini, leaving everything else exactly as it was.
    #
    # Line surgery rather than re-serialising the parsed config: vault.ini is mostly
    # comments explaining why each setting is what it is, and a writer that round-tripped
    # through the hashtable would hand back a correct file with all of that deleted.
    # `update` deliberately never overwrites this file; neither does this.
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    $lines = @(Get-Content -LiteralPath $Path)
    $sec   = $Section.ToLowerInvariant()
    $key   = $Key.ToLowerInvariant()

    # Where the section starts, and where it ends - the next header, or the end.
    $start = -1; $end = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $t = "$($lines[$i])".Trim().TrimStart([char]0xFEFF)
        if ($t.StartsWith('[') -and $t.EndsWith(']')) {
            $name = $t.Trim('[', ']').Trim().ToLowerInvariant()
            if ($start -lt 0) { if ($name -eq $sec) { $start = $i } }
            else              { $end = $i; break }
        }
    }

    $out = New-Object System.Collections.ArrayList
    if ($start -lt 0) {
        # No such section: append it rather than guessing where it belongs.
        foreach ($l in $lines) { [void]$out.Add($l) }
        [void]$out.Add('')
        [void]$out.Add("[$Section]")
        [void]$out.Add("$Key = $Value")
    }
    else {
        $hit = -1
        for ($i = $start + 1; $i -lt $end; $i++) {
            $t = "$($lines[$i])".Trim()
            if (-not $t -or $t.StartsWith('#') -or $t.StartsWith(';')) { continue }
            $eq = $t.IndexOf('=')
            if ($eq -lt 1) { continue }
            if ($t.Substring(0, $eq).Trim().ToLowerInvariant() -eq $key) { $hit = $i; break }
        }
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($hit -ge 0 -and $i -eq $hit) { [void]$out.Add("$Key = $Value"); continue }
            [void]$out.Add($lines[$i])
            # Key absent from an existing section: put it directly under the header,
            # where the comments above it still apply to it.
            if ($hit -lt 0 -and $i -eq $start) { [void]$out.Add("$Key = $Value") }
        }
    }

    [IO.File]::WriteAllLines($Path, $out, (New-Object Text.UTF8Encoding $false))
}

function Get-VaultHostName {
    # Accepts a full URL or a bare host and returns the host. Operators paste what is in
    # the address bar, which includes the scheme and a path.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $h = $Value -replace '^https?://', ''
    $h = ($h -split '/')[0]
    return $h.Trim().TrimEnd('/')
}
