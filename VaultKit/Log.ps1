# Logging. Console and file, one level vocabulary across every command.
#
# Every write here is -WhatIf:$false on purpose. -WhatIf means "do not write to Vault";
# the log and the reports are how an operator sees what a dry run WOULD do, so
# suppressing them defeats the point. Add-Content honours -WhatIf, and the previous
# generation of these tools silently produced no log at all under -WhatIf because of it.

$script:VaultLogFile = ''

function Start-VaultLog {
    param([Parameter(Mandatory)][string]$Directory, [Parameter(Mandatory)][string]$Name)
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Path $Directory -Force -WhatIf:$false | Out-Null
    }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $script:VaultLogFile = Join-Path $Directory "$Name-$stamp.log"
    return $script:VaultLogFile
}

function Write-VaultLog {
    param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Message,
        # Position 1 matters: every call site passes the level positionally, as
        # Write-VaultLog "..." 'WARN'. Giving Message an explicit position and not Level
        # makes Level named-only, and every one of those calls fails at runtime with
        # "A positional parameter cannot be found that accepts argument 'WARN'".
        [Parameter(Position = 1)][ValidateSet('INFO', 'OK', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line }
    }
    if ($script:VaultLogFile) {
        try { Add-Content -LiteralPath $script:VaultLogFile -Value $line -Encoding UTF8 -WhatIf:$false }
        catch { }
    }
}

function Get-VaultField {
    # Strict-mode-safe property read. Set-StrictMode turns a missing property into a
    # terminating error, which has twice killed a run inside a log line - reading
    # $response.vaultId purely to print it, after the call had already succeeded.
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

function Format-VaultBytes {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}
