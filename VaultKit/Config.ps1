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

function Get-VaultHostName {
    # Accepts a full URL or a bare host and returns the host. Operators paste what is in
    # the address bar, which includes the scheme and a path.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $h = $Value -replace '^https?://', ''
    $h = ($h -split '/')[0]
    return $h.Trim().TrimEnd('/')
}
