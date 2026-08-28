<#
.SYNOPSIS
    Prove that the sharing settings a run said it wrote are actually on the documents.

.DESCRIPTION
    Validation, and nothing else. Run it with no arguments and it validates:

        curl.exe -sfL -H "Accept: application/vnd.github.raw" -o veeva-validate.ps1 "https://api.github.com/repos/kevinnassery/veeva/contents/oneshot/veeva-validate.ps1?ref=main"
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File veeva-validate.ps1

    A SEPARATE FILE FROM veeva-roles.ps1, ON PURPOSE.

    A validator that shares code with the tool it checks can be wrong in the same way and
    still agree with it. If both used one name-folding function, one directory build and
    one way of reading assignments, a fault in any of them would make the check pass while
    the vault was wrong - which is the one outcome a validator must never produce. So this
    file duplicates the small pieces it needs rather than importing them, reads current
    state through a different endpoint, and is deliberately written differently where it
    would otherwise be tempting to copy.

    Specifically:

      * veeva-roles.ps1 reads assignments from GET /objects/documents/{id}/roles.
        This reads them from doc_role__sys over VQL.
      * veeva-roles.ps1 decides what SHOULD be there from lifecycle rules, document
        defaults and doctype MDL. This decides nothing - it takes what the run RECORDED
        as assigned, from role-results.csv, and looks for exactly that.

    It exists for a failure the run itself cannot see. Vault's own documentation for the
    assign endpoint: "Users and groups (IDs) in the input that are either invalid (not
    recognized) or cannot be assigned to a role due to permissions are ignored and not
    processed." A document can therefore report SUCCESS while a group is quietly dropped.
    The run records ASSIGNED, the summary says 0 failed, and only reading the result back
    from somewhere else shows the difference.

.PARAMETER Vault
    The vault to check. Prompted for if omitted; a session cached by either tool is
    offered back as the default.

.PARAMETER ResultsFile
    The run's results file. Default: role-results.csv in the current folder.

.PARAMETER n
    Check only this many DOCUMENTS. Counted in documents rather than claims because a
    document is what costs time and what you go and look at in the UI - one document
    carries six or seven claims, so "check 5" should mean five documents, not five rows.

        .\veeva-validate.ps1 -n 5

.PARAMETER Slow
    Skip the bulk query and read one document at a time. Only needed if the bulk read is
    ever wrong; it is much slower and answers the same question.

.PARAMETER Version
    Print the version and exit. No vault, no login.

.PARAMETER Logout
    Delete the cached session and exit.

.EXAMPLE
    .\veeva-validate.ps1
    Validate role-results.csv against the vault.

.EXAMPLE
    .\veeva-validate.ps1 -n 5
    Check five documents. Enough to prove the validator itself works before turning it
    loose on the whole file.

.EXAMPLE
    .\veeva-validate.ps1 -ResultsFile role-results-20260828-182528.csv
    Check an earlier run's file.

.NOTES
    Windows PowerShell 5.1 compatible. Nothing to install. Writes nothing to Vault.

    Exit code is the number of MISSING claims, so a scheduled run can fail on it.
#>

[CmdletBinding()]
param(
    [string]$Vault = '',
    [string]$ResultsFile = '',
    [string]$Api = 'v26.2',
    [Alias('Limit')][int]$n = 0,
    [switch]$Slow,
    [switch]$Version,
    [switch]$Logout
)

$ScriptVersion = '2026.08.28-21'

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# ======================================================================================
#  Small things
# ======================================================================================

$script:LogFile = ''

function Write-Log {
    param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Message,
        [Parameter(Position = 1)][ValidateSet('INFO', 'OK', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line }
    }
    if ($script:LogFile) {
        try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 } catch { }
    }
}

function Get-Field {
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

function Get-FoldedName {
    # Written independently of veeva-roles.ps1's ConvertTo-NameKey, and tested against the
    # same cases, because a shared folding bug would silently make both tools agree on the
    # wrong answer. Same contract: drop a trailing __c/__v/__sys, keep letters and digits,
    # lower case.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $s = $Value.Trim()
    foreach ($suffix in @('__c', '__v', '__sys')) {
        if ($s.EndsWith($suffix)) { $s = $s.Substring(0, $s.Length - $suffix.Length); break }
    }
    $sb = New-Object Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        if ([char]::IsLetterOrDigit($ch)) { [void]$sb.Append([char]::ToLowerInvariant($ch)) }
    }
    return $sb.ToString()
}

function Test-CanPrompt {
    try { return -not [Console]::IsInputRedirected } catch { return $true }
}

function Get-HostName {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $h = $Value -replace '^https?://', ''
    return (($h -split '/')[0]).Trim().TrimEnd('/')
}


# ======================================================================================
#  Session - the same file veeva-roles.ps1 writes, so a login is not needed twice
#
#  Sharing the session file is not a correctness risk: a token says who you are, not what
#  the answer is. Everything that could change the ANSWER is written separately here.
# ======================================================================================

$script:Sessions = @{}
$script:Cred     = $null

function Get-SessionPath {
    $here = $PSScriptRoot
    if (-not $here) { $here = (Get-Location).ProviderPath }
    return (Join-Path $here '.vault-session.json')
}

function Read-SessionFile {
    $path = Get-SessionPath
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try { return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) } catch { return $null }
}

function Get-CachedHost {
    $json = Read-SessionFile
    if (-not $json) { return '' }
    $best = ''; $bestT = [datetime]::MinValue
    foreach ($p in $json.PSObject.Properties) {
        if (-not "$(Get-Field $p.Value 'sessionId' '')") { continue }
        $t = [datetime]::MinValue
        try { $t = [datetime]::Parse("$(Get-Field $p.Value 'obtained' '')") } catch { }
        if (-not $best -or $t -gt $bestT) { $best = $p.Name; $bestT = $t }
    }
    return $best
}

function Connect-Vault {
    param([Parameter(Mandatory)][string]$VaultHost)
    if (-not $script:Cred) {
        if (-not (Test-CanPrompt)) { throw 'No cached session and nobody here to ask for a login.' }
        $script:Cred = Get-Credential -Message "Vault login for $VaultHost"
        if (-not $script:Cred) { throw 'No credentials given.' }
    }
    $body = @{ username = $script:Cred.UserName; password = $script:Cred.GetNetworkCredential().Password }
    $r = Invoke-RestMethod -Method Post -Uri "https://$VaultHost/api/$Api/auth" `
            -Body $body -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' }
    if ((Get-Field $r 'responseStatus') -ne 'SUCCESS') { throw "Authentication failed for $VaultHost" }
    $sid = "$(Get-Field $r 'sessionId' '')"
    if (-not $sid) { throw "Authentication for $VaultHost returned no sessionId" }
    $script:Sessions[$VaultHost] = $sid

    $all = [ordered]@{}
    $existing = Read-SessionFile
    if ($existing) { foreach ($p in $existing.PSObject.Properties) { $all[$p.Name] = $p.Value } }
    $all[$VaultHost] = [pscustomobject]@{
        sessionId = $sid; userId = "$(Get-Field $r 'userId' '')"
        vaultId = "$(Get-Field $r 'vaultId' '')"; api = $Api
        obtained = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    }
    try { ($all | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath (Get-SessionPath) -Encoding UTF8 } catch { }
    Write-Log "$VaultHost - authenticated" 'OK'
    return $sid
}

function Get-SessionId {
    param([Parameter(Mandatory)][string]$VaultHost)
    if ($script:Sessions.ContainsKey($VaultHost)) { return $script:Sessions[$VaultHost] }
    $json = Read-SessionFile
    if ($json) {
        $sid = "$(Get-Field (Get-Field $json $VaultHost $null) 'sessionId' '')"
        if ($sid) { $script:Sessions[$VaultHost] = $sid; return $sid }
    }
    return (Connect-Vault -VaultHost $VaultHost)
}


# ======================================================================================
#  HTTP
# ======================================================================================

function Invoke-Api {
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][ValidateSet('GET', 'POST')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body,
        [string]$ContentType,
        [int]$MaxRetries = 4
    )
    $uri = if     ($Path -match '^https?://') { $Path }
           elseif ($Path -match '^/api/')     { "https://$VaultHost$Path" }
           else                               { "https://$VaultHost/api/$Api$Path" }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sid = Get-SessionId -VaultHost $VaultHost
        try {
            $req = @{ Method = $Method; Uri = $uri; TimeoutSec = 900; UseBasicParsing = $true
                      Headers = @{ Authorization = $sid; Accept = 'application/json' } }
            if ($null -ne $Body) { $req['Body'] = $Body }
            if ($ContentType)    { $req['ContentType'] = $ContentType }
            $resp = Invoke-WebRequest @req

            $remaining = $resp.Headers['X-VaultAPI-BurstLimitRemaining']
            if ($remaining -and [int]$remaining -lt 200) {
                Write-Log "burst limit low ($remaining) - pausing 30s" 'WARN'
                Start-Sleep -Seconds 30
            }

            $json = $null
            if ($resp.Content) { try { $json = $resp.Content | ConvertFrom-Json } catch { } }
            if ($null -eq $json) { return [pscustomobject]@{ responseStatus = 'SUCCESS'; raw = $resp.Content } }

            if ((Get-Field $json 'responseStatus') -eq 'FAILURE') {
                $errs  = @(Get-Field $json 'errors' @())
                if (@($errs | ForEach-Object { Get-Field $_ 'type' }) -contains 'INVALID_SESSION_ID') {
                    $script:Sessions.Remove($VaultHost)
                    [void](Connect-Vault -VaultHost $VaultHost)
                    continue
                }
                throw (($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; ')
            }
            return $json
        }
        catch {
            $ex = $_.Exception
            if ($ex.GetType().Name -notin @('WebException', 'HttpResponseException', 'HttpRequestException')) { throw }
            $status = $null
            try { if ($ex.Response) { $status = [int]$ex.Response.StatusCode } } catch { }
            if ($status -eq 429 -and $attempt -lt $MaxRetries) { Start-Sleep -Seconds 60; continue }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                Start-Sleep -Seconds ([math]::Pow(2, $attempt) * 5); continue
            }
            $detail = ''
            try { $detail = "$($_.ErrorDetails.Message)" } catch { }
            throw "$Method $Path failed (HTTP $status): $($ex.Message) $detail"
        }
    }
    throw "$Method $Path failed after $MaxRetries attempts"
}


# ======================================================================================
#  Groups, by name
#
#  Built here rather than shared, and only groups are needed - this checks group
#  assignments, which is what -Assign Groups writes.
# ======================================================================================

function Get-GroupIndex {
    param([Parameter(Mandatory)][string]$VaultHost)
    $byName = @{}
    $byId   = @{}
    $r = Invoke-Api -VaultHost $VaultHost -Method GET -Path '/objects/groups'
    foreach ($rec in @(Get-Field $r 'groups' @())) {
        $g = Get-Field $rec 'group' $null
        if ($null -eq $g) { $g = $rec }
        $id = "$(Get-Field $g 'id' '')"
        if (-not $id) { continue }
        foreach ($f in @('label__v', 'name__v')) {
            $n = "$(Get-Field $g $f '')"
            if (-not $n) { continue }
            $k = Get-FoldedName $n
            if ($k -and -not $byName.ContainsKey($k)) { $byName[$k] = $id }
            if (-not $byId.ContainsKey($id)) { $byId[$id] = $n }
        }
    }
    Write-Log "$($byId.Count) group(s) in this vault"
    return [pscustomobject]@{ ByName = $byName; ById = $byId }
}


# ======================================================================================
#  Current state, read through doc_role__sys
# ======================================================================================

function Get-CurrentGroups {
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][array]$DocIds)

    $byKey = @{}
    $bulk  = -not $Slow

    if ($bulk) {
        $chunk = 200
        for ($off = 0; $off -lt $DocIds.Count; $off += $chunk) {
            $slice = @($DocIds[$off..([math]::Min($off + $chunk - 1, $DocIds.Count - 1))])
            $vql = "SELECT document_id, role_name__sys, group__sys FROM doc_role__sys WHERE document_id CONTAINS ($($slice -join ','))"
            $path = '/query'
            $body = "q=$([Uri]::EscapeDataString($vql))"
            $pages = 0
            try {
                while ($path -and $pages -lt 500) {
                    $pages++
                    $r = if ($pages -eq 1) {
                            Invoke-Api -VaultHost $VaultHost -Method POST -Path $path -Body $body `
                                -ContentType 'application/x-www-form-urlencoded' -MaxRetries 1
                         } else {
                            Invoke-Api -VaultHost $VaultHost -Method GET -Path $path -MaxRetries 1
                         }
                    foreach ($row in @(Get-Field $r 'data' @())) {
                        $d = "$(Get-Field $row 'document_id' '')"
                        $n = "$(Get-Field $row 'role_name__sys' '')"
                        $g = "$(Get-Field $row 'group__sys' '')"
                        if (-not $d -or -not $n -or -not $g) { continue }
                        $k = "$d|$(Get-FoldedName $n)"
                        if (-not $byKey.ContainsKey($k)) { $byKey[$k] = @{} }
                        $byKey[$k][$g] = $true
                    }
                    $path = "$(Get-Field (Get-Field $r 'responseDetails' $null) 'next_page' '')"
                }
            }
            catch {
                Write-Log "doc_role__sys will not take that query, falling back to one read per document: $_" 'WARN'
                $bulk = $false
                break
            }
            Write-Log "  read $([math]::Min($off + $chunk, $DocIds.Count)) of $($DocIds.Count)"
        }
    }

    if ($bulk) { return [pscustomobject]@{ ByKey = $byKey; Method = 'doc_role__sys (bulk)' } }

    # Fallback. Still not the same call the assign run made for its comparison - it reads
    # the roles endpoint, which is at least a different query - but the point of the bulk
    # path is that it is a genuinely separate route, so a fallback is worth saying out loud.
    $byKey = @{}
    $i = 0
    foreach ($docId in $DocIds) {
        $i++
        if (($i % 500) -eq 0) { Write-Log "  read $i of $($DocIds.Count)" }
        try {
            $r = Invoke-Api -VaultHost $VaultHost -Method GET -Path "/objects/documents/$docId/roles"
            foreach ($role in @(Get-Field $r 'documentRoles' @())) {
                $n = "$(Get-Field $role 'name' '')"
                if (-not $n) { continue }
                $k = "$docId|$(Get-FoldedName $n)"
                if (-not $byKey.ContainsKey($k)) { $byKey[$k] = @{} }
                foreach ($g in @(Get-Field $role 'assignedGroups' @())) { $byKey[$k]["$g"] = $true }
            }
        }
        catch { Write-Log "  could not read document ${docId}: $_" 'ERROR' }
    }
    return [pscustomobject]@{ ByKey = $byKey; Method = 'one read per document' }
}


function Get-CurrentFacts {
    # type, subtype and lifecycle for a set of documents, in bulk.
    #
    # These are the INPUTS the run's decision rested on: the lifecycle picks the rule, the
    # type and subtype pick the MDL component. Confirming them checks the premises without
    # re-running the reasoning - which is the line this tool tries to hold. Re-deriving
    # what SHOULD be on a document would just be the same logic agreeing with itself.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][array]$DocIds)

    $byId  = @{}
    $chunk = 200
    for ($off = 0; $off -lt $DocIds.Count; $off += $chunk) {
        $slice = @($DocIds[$off..([math]::Min($off + $chunk - 1, $DocIds.Count - 1))])
        $vql = "SELECT id, type__v, subtype__v, lifecycle__v FROM documents WHERE id CONTAINS ($($slice -join ','))"
        $path = '/query'
        $body = "q=$([Uri]::EscapeDataString($vql))"
        $pages = 0
        try {
            while ($path -and $pages -lt 500) {
                $pages++
                $r = if ($pages -eq 1) {
                        Invoke-Api -VaultHost $VaultHost -Method POST -Path $path -Body $body `
                            -ContentType 'application/x-www-form-urlencoded' -MaxRetries 1
                     } else {
                        Invoke-Api -VaultHost $VaultHost -Method GET -Path $path -MaxRetries 1
                     }
                foreach ($row in @(Get-Field $r 'data' @())) {
                    $id = "$(Get-Field $row 'id' '')"
                    if (-not $id) { continue }
                    $sub = "$(Get-Field $row 'subtype__v' '')"
                    $ty  = "$(Get-Field $row 'type__v' '')"
                    if (-not $sub) { $sub = $ty }
                    $byId[$id] = [pscustomobject]@{ Type = $ty; Subtype = $sub; Lifecycle = "$(Get-Field $row 'lifecycle__v' '')" }
                }
                $path = "$(Get-Field (Get-Field $r 'responseDetails' $null) 'next_page' '')"
            }
        }
        catch {
            Write-Log "Could not read document facts, so type and lifecycle go unchecked: $_" 'WARN'
            return @{}
        }
    }
    return $byId
}

# ======================================================================================
#  Run
# ======================================================================================

$exitCode = 0
try {
    if ($Version) { Write-Host $ScriptVersion; exit 0 }
    if ($Logout) {
        $p = Get-SessionPath
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force; Write-Host "Deleted $p" }
        else { Write-Host 'No session file to delete.' }
        exit 0
    }

    Write-Host ''
    Write-Host "veeva-validate $ScriptVersion" -ForegroundColor Cyan
    Write-Host ''

    $vaultHost = $Vault
    if (-not $vaultHost) {
        $default = Get-CachedHost
        if (Test-CanPrompt) {
            $suffix = if ($default) { " [$default]" } else { '' }
            $answer = (Read-Host "  Vault$suffix").Trim().Trim('"', "'")
            if (-not $answer) { $answer = $default }
            $vaultHost = $answer
        }
        else { $vaultHost = $default }
    }
    $vaultHost = Get-HostName $vaultHost
    if (-not $vaultHost) { throw 'A vault is required. Pass -Vault.' }

    $path = $ResultsFile
    if (-not $path) { $path = Join-Path (Get-Location).ProviderPath 'role-results.csv' }
    if (-not (Test-Path -LiteralPath $path)) {
        throw "No results file at $path. Pass -ResultsFile. There is nothing to validate without one - this checks what a run RECORDED, it does not work out what ought to be there."
    }

    $script:LogFile = Join-Path (Get-Location).ProviderPath ('veeva-validate-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Write-Log "veeva-validate $ScriptVersion"
    Write-Log "  vault    $vaultHost"
    Write-Log "  results  $path"

    $rows = @(Import-Csv -LiteralPath $path)
    $statuses = @{}
    $claims = New-Object System.Collections.ArrayList
    foreach ($row in $rows) {
        $st = "$(Get-Field $row 'Status' '')"
        if ($st) { $statuses[$st] = 1 + $(if ($statuses.ContainsKey($st)) { $statuses[$st] } else { 0 }) }
        if ($st -ne 'ASSIGNED') { continue }
        $groups = "$(Get-Field $row 'MissingGroups' '')"
        if (-not $groups) { continue }
        [void]$claims.Add([pscustomobject]@{
            DocId     = "$(Get-Field $row 'DocId' '')"
            Role      = "$(Get-Field $row 'Role' '')"
            Lifecycle = "$(Get-Field $row 'Lifecycle' '')"
            Type      = "$(Get-Field $row 'Type' '')"
            Subtype   = "$(Get-Field $row 'Subtype' '')"
            Groups    = @($groups -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        })
    }
    Write-Log "$($rows.Count) row(s): $((($statuses.Keys | Sort-Object) | ForEach-Object { "$_=$($statuses[$_])" }) -join ', ')"

    if (-not $claims.Count) {
        Write-Log 'No ASSIGNED rows carrying groups. Nothing was claimed, so there is nothing to prove.' 'WARN'
        Write-Log "Log: $script:LogFile"
        exit 0
    }

    $docIds = @($claims | ForEach-Object { $_.DocId } | Select-Object -Unique)

    # Trimmed by DOCUMENT, then the claims are filtered to match - not the other way
    # round. Cutting the claim list first would leave a document half-checked, and a
    # document that is partly verified is the one thing worse than one that is not.
    if ($n -gt 0 -and $docIds.Count -gt $n) {
        Write-Log "-n $n - checking the first $n of $($docIds.Count) document(s)" 'WARN'
        $docIds = @($docIds | Select-Object -First $n)
        $keep   = @{}
        foreach ($d in $docIds) { $keep[$d] = $true }
        $claims = @($claims | Where-Object { $keep.ContainsKey($_.DocId) })
    }

    Write-Log "$($claims.Count) claim(s) over $($docIds.Count) document(s)"

    $groups  = Get-GroupIndex -VaultHost $vaultHost
    $current = Get-CurrentGroups -VaultHost $vaultHost -DocIds $docIds
    $facts   = Get-CurrentFacts  -VaultHost $vaultHost -DocIds $docIds

    # One row per DOCUMENT, not per claim. A claim-level file for this scope runs to
    # hundreds of thousands of rows that nobody can scan; a document is the thing you
    # filter to a work list and then go and open in the UI. The detail is not lost - the
    # groups that failed are named in the row.
    $byDoc = @{}
    foreach ($claim in $claims) {
        if (-not $byDoc.ContainsKey($claim.DocId)) { $byDoc[$claim.DocId] = New-Object System.Collections.ArrayList }
        [void]$byDoc[$claim.DocId].Add($claim)
    }

    $out  = New-Object System.Collections.ArrayList
    $stat = @{ Documents = 0; Clean = 0; Missing = 0; Unresolved = 0
               LifecycleMismatch = 0; TypeMismatch = 0; NotChecked = 0
               ClaimsConfirmed = 0; ClaimsMissing = 0 }

    foreach ($docId in ($byDoc.Keys | Sort-Object)) {
        $stat.Documents++
        $docClaims = @($byDoc[$docId])

        $confirmed = 0
        $missing   = New-Object System.Collections.ArrayList
        $unres     = New-Object System.Collections.ArrayList
        $roles     = New-Object System.Collections.ArrayList

        foreach ($claim in $docClaims) {
            if ($roles -notcontains $claim.Role) { [void]$roles.Add($claim.Role) }
            $k    = "$docId|$(Get-FoldedName $claim.Role)"
            $have = if ($current.ByKey.ContainsKey($k)) { $current.ByKey[$k] } else { @{} }
            foreach ($gName in $claim.Groups) {
                $gid = ''
                $fk  = Get-FoldedName $gName
                if ($groups.ByName.ContainsKey($fk)) { $gid = $groups.ByName[$fk] }
                elseif ($gName -match '^\d+$')       { $gid = $gName }

                if (-not $gid)                   { [void]$unres.Add("$($claim.Role): $gName") }
                elseif ($have.ContainsKey($gid)) { $confirmed++ }
                else                             { [void]$missing.Add("$($claim.Role): $gName") }
            }
        }
        $stat.ClaimsConfirmed += $confirmed
        $stat.ClaimsMissing   += $missing.Count
        if ($unres.Count) { $stat.Unresolved++ }

        # The dimensions the run's decision rested on. Blank where the run did not record
        # them - older results files carry no Type or Subtype - which is reported as
        # NOT_RECORDED rather than quietly passing.
        $recLc  = "$($docClaims[0].Lifecycle)"
        $recTy  = "$($docClaims[0].Type)"
        $recSub = "$($docClaims[0].Subtype)"
        $now    = if ($facts.ContainsKey($docId)) { $facts[$docId] } else { $null }

        function Compare-Dimension {
            param([string]$Recorded, $Now, [string]$Field)
            if (-not $Recorded)  { return 'NOT_RECORDED' }
            if ($null -eq $Now)  { return 'NOT_CHECKED' }
            $current = "$(Get-Field $Now $Field '')"
            if (-not $current)   { return 'NOT_CHECKED' }
            if ((Get-FoldedName $Recorded) -eq (Get-FoldedName $current)) { return 'CONFIRMED' }
            return 'CHANGED'
        }

        $lcState  = Compare-Dimension -Recorded $recLc  -Now $now -Field 'Lifecycle'
        $tyState  = Compare-Dimension -Recorded $recTy  -Now $now -Field 'Type'
        $subState = Compare-Dimension -Recorded $recSub -Now $now -Field 'Subtype'

        if ($lcState -eq 'CHANGED') { $stat.LifecycleMismatch++ }
        if ($tyState -eq 'CHANGED' -or $subState -eq 'CHANGED') { $stat.TypeMismatch++ }
        if ($lcState -eq 'NOT_CHECKED') { $stat.NotChecked++ }

        $status =
            if ($missing.Count)                                  { $stat.Missing++; 'GROUPS_MISSING' }
            elseif ($lcState -eq 'CHANGED' -or $tyState -eq 'CHANGED' -or $subState -eq 'CHANGED') { 'DIMENSION_CHANGED' }
            elseif ($unres.Count)                                { 'NAMES_UNRESOLVED' }
            else                                                 { $stat.Clean++; 'CONFIRMED' }

        if ($status -ne 'CONFIRMED') {
            $why = if ($missing.Count) { ($missing | Select-Object -First 4) -join '; ' }
                   elseif ($unres.Count) { ($unres | Select-Object -First 4) -join '; ' }
                   else { "lifecycle $lcState, type $tyState, subtype $subState" }
            Write-Log "  doc $docId - $status : $why" $(if ($status -eq 'GROUPS_MISSING') { 'ERROR' } else { 'WARN' })
        }

        [void]$out.Add([pscustomobject][ordered]@{
            DocId = $docId
            Status = $status
            RolesChecked = $roles.Count
            GroupsClaimed = $confirmed + $missing.Count + $unres.Count
            GroupsConfirmed = $confirmed
            GroupsMissing = $missing.Count
            MissingDetail = ($missing -join '; ')
            UnresolvedDetail = ($unres -join '; ')
            LifecycleRecorded = $recLc
            LifecycleNow = $(if ($now) { $now.Lifecycle } else { '' })
            LifecycleCheck = $lcState
            TypeRecorded = $recTy
            TypeNow = $(if ($now) { $now.Type } else { '' })
            TypeCheck = $tyState
            SubtypeRecorded = $recSub
            SubtypeNow = $(if ($now) { $now.Subtype } else { '' })
            SubtypeCheck = $subState
            CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
        })
    }

    $report = Join-Path (Get-Location).ProviderPath 'validate-roles.csv'
    $out | Export-Csv -LiteralPath $report -NoTypeInformation -Encoding UTF8

    Write-Log '----------------------------------------------------------------'
    Write-Log "$($stat.Documents) document(s) checked, assignments read by $($current.Method)"
    Write-Log ("  CONFIRMED           {0}" -f $stat.Clean) 'OK'
    if ($stat.Missing) {
        Write-Log ("  GROUPS_MISSING      {0}  ({1} group assignment(s))" -f $stat.Missing, $stat.ClaimsMissing) 'ERROR'
        Write-Log '  The run recorded these as assigned and the vault does not have them. Vault' 'ERROR'
        Write-Log '  ignores ids it cannot grant and still reports SUCCESS, so re-running will not' 'ERROR'
        Write-Log '  fix it. Check whether the account may grant those groups.' 'ERROR'
    }
    if ($stat.LifecycleMismatch) {
        Write-Log ("  lifecycle changed   {0}  - not what the run saw, so its rule choice no longer holds" -f $stat.LifecycleMismatch) 'WARN'
    }
    if ($stat.TypeMismatch) {
        Write-Log ("  type/subtype changed {0} - the run picked its type defaults from a different one" -f $stat.TypeMismatch) 'WARN'
    }
    if ($stat.Unresolved) {
        Write-Log ("  NAMES_UNRESOLVED    {0}  - recorded under a name no group here answers to" -f $stat.Unresolved) 'WARN'
    }
    if ($stat.NotChecked) {
        Write-Log ("  dimensions unchecked {0} - the document facts could not be read" -f $stat.NotChecked) 'WARN'
    }
    Write-Log ("  {0} group assignment(s) confirmed in total" -f $stat.ClaimsConfirmed)
    if ($out.Count -and -not $out[0].TypeRecorded) {
        Write-Log 'Type and subtype were NOT_RECORDED - this results file predates the run recording them.' 'WARN'
    }
    if (-not $stat.Missing -and -not $stat.Unresolved -and -not $stat.LifecycleMismatch -and -not $stat.TypeMismatch) {
        Write-Log 'Every group the run recorded as assigned is on its document, on the facts it decided from.' 'OK'
    }
    Write-Log "Report: $report"
    Write-Log "Log: $script:LogFile"
    $exitCode = $stat.Missing
}
catch {
    Write-Log "$_" 'ERROR'
    $exitCode = 1
}
finally { $script:Cred = $null }

exit $exitCode
