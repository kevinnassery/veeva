<#
.SYNOPSIS
    Fill in the Document Sharing Settings a migration left empty. One file.

.DESCRIPTION
    Documents created through the Vault UI get users and groups populated into their
    Sharing Settings automatically, from the lifecycle's role assignment rules and from
    the document type's "Default Settings for New Documents". Documents created through
    the Vault API or Vault Loader do NOT - Veeva confirms this is by design. A migrated
    document therefore arrives with its roles empty, and something has to put them back.

    This is that something. For each document it reads the roles Vault reports, works out
    who the document's lifecycle role assignment rules say should be there, and assigns
    whoever is missing. It never removes anyone and never invents an assignment:
    everything it writes is something the configuration already names as a default.

    One file. No folder of scripts, no ini, no refresh step, nothing installed:

        curl.exe -sfL -H "Accept: application/vnd.github.raw" -o veeva-roles.ps1 "https://api.github.com/repos/kevinnassery/veeva/contents/oneshot/veeva-roles.ps1?ref=main"

    The contents API, not raw.githubusercontent.com. Raw caches a branch url for five
    minutes and ignores no-cache, so straight after a fix is pushed it hands back the
    previous file - which looks exactly like a fix that did not work. The API is a
    different host with a 60-second, ETag-revalidated cache. For an exact version rather
    than the latest, fetch a commit url from raw instead: those are immutable.
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File veeva-roles.ps1 -Probe

    Three steps, in order. Nothing is written to Vault until the third.

        -Probe   Read a sample of the mapped documents and report what Vault holds:
                 which subtypes they span, which roles each subtype has, what each role
                 says its defaults are, and how those compare with the lifecycle's own
                 role assignment rules. Writes probe-report.csv and a starter
                 discovered-defaults.csv. Changes nothing.

        -Plan    Work out, for every document, exactly who would be added to which role,
                 and print it. Changes nothing.

        (none)   Assign them.

.PARAMETER Vault
    The vault holding the migrated documents. Only one vault is involved - this repairs
    the target of a migration, it does not compare two vaults.

.PARAMETER Map
    The same attachments-map.csv the rest of the migration uses. The TARGET id column
    names the documents to repair. Header row, comma/tab/semicolon/pipe - the delimiter
    and the two id columns are both detected. Two rows pointing at the same target are one
    document to repair, not two.

.PARAMETER Where
    Enumerate the documents from the vault instead of listing them in a map - a VQL
    condition, run as SELECT id FROM documents WHERE <condition> and paged through. A
    full SELECT is accepted too.

        -Where "type__v = 'Administrative Information'"
        -Where "created_date__v > '2026-08-01T00:00:00.000Z'"

    Prefer -Map when one exists. It says exactly which documents the migration produced,
    where a query says which documents match a condition today - and the two stop being
    the same set the moment anyone adds a document by hand. -Where is for when the
    migration WAS the vault, or when the job really is "every document of this subtype".
    Mutually exclusive with -Map.

.PARAMETER Version
    Print the version and exit. Needs no vault and no login - it is here because this file
    is fetched by URL, so "which copy am I holding" is a real question.

.PARAMETER Logout
    Delete the cached session and exit.

    The session id is cached in .vault-session.json beside this script and reused by the
    next run, so probing, planning and assigning over the same vault do not each stop for
    a credential prompt. It is checked against the vault before being trusted, and a dead
    one just means logging in again.

    That file is a bearer token: whoever holds it acts as you until Vault expires it. It
    is ACL'd to the current user where Windows allows it, but it is not encrypted. Treat
    it like a password, and -Logout when you are done.

.PARAMETER DesiredFrom
    Where "who should be in this role" comes from. Default: Lifecycle.

    Lifecycle  The document's own lifecycle role assignment rules, read once from
               GET /configuration/role_assignment_rule and applied per document. Where a
               role has override rules, the override matching the document's product,
               country or study wins over the default - as it does in Vault. Two
               overrides matching equally well is refused rather than guessed at, and so
               is a document that could not be read: both are reported UNRESOLVED and
               nothing is written for them.

    Document   The defaultUsers and defaultGroups that GET /objects/documents/{id}/roles
               reports. One call per document, no rule interpretation, and Vault has
               already resolved the overrides - but see -Probe for whether it also
               carries the document type's default security.

    Table      The -Defaults CSV. Implied by passing -Defaults.

.PARAMETER Defaults
    Optional. A small CSV naming what each role should hold, transcribed from Admin >
    Document Types > (type) > Security > "Default Settings for New Documents":

        role,groups
        editor__v,"Business Administrators,Label Authors,Label Editors"
        viewer__v,"Regulatory Users,Submission Managers"
        consumer__v,"Document Users"

    A `users` column is accepted too, and an optional `subtype` column when the map spans
    more than one document subtype. Roles and groups may be given by API name
    (editor__v, label_authors__c) or by the label shown in the UI (Editors, Label
    Authors) - both are matched, case-insensitively.

    Use it when the lifecycle rules are not the whole story - the document TYPE's default
    security is configured on a different screen, and whether the API exposes it anywhere
    is not stated in the documentation. -Probe reports whether the two agree on a live
    vault, so the choice is made on evidence rather than on a reading of the docs.

.PARAMETER Assign
    What to write. Default: Both.

    Both    Users and groups, exactly as the configuration names them.
    Groups  Groups only. Use this when the direct user assignments turn out to be the
            membership of those same groups: a direct assignment outlives the group, so
            taking someone out of the group later does not take away their access.
    Users   Users only.

    -Plan reports how many of the user assignments are already covered by group
    membership, so this can be decided on the numbers rather than on a hunch.

.PARAMETER Probe
    Read-only survey of the target vault. Reports the subtypes the map spans, the roles
    each has, what Vault calls their defaults, and whether those defaults exceed the
    lifecycle's own role assignment rules - the test for whether document type default
    security is included. Writes probe-report.csv and discovered-defaults.csv. Samples 25
    documents unless -Limit says otherwise.

.PARAMETER Plan
    Report what would be assigned and change nothing.

.PARAMETER Role
    Only these roles, by API name or label. Default: every role on the document.

.PARAMETER ExcludeRole
    Leave these roles alone. owner__v is a reasonable one to exclude.

.PARAMETER Test
    Stop once this many documents have actually been changed - not this many examined.
    Documents already in step cost a read and nothing else, so capping by document
    examined can prove nothing.

.PARAMETER Limit
    Cap the documents examined.

.PARAMETER BatchSize
    Documents per bulk assign call. Vault's maximum is 1000; the default is 200 so a
    failure names a smaller set.

.PARAMETER Fresh
    Rotate an earlier results file aside instead of adding to it.

.EXAMPLE
    .\veeva-roles.ps1 -Probe
    Answer two prompts and a login box. Reports what the target vault holds and writes
    discovered-defaults.csv. Changes nothing.

.EXAMPLE
    .\veeva-roles.ps1 -Vault acme.veevavault.com -Map map.csv -Plan
    What would be assigned, using Vault's own per-document defaults.

.EXAMPLE
    .\veeva-roles.ps1 -Vault acme.veevavault.com -Map map.csv -Defaults defaults.csv -Limit 5 -Plan
    Prove a hand-checked defaults table against five documents before touching the rest.

.EXAMPLE
    .\veeva-roles.ps1 -Vault acme.veevavault.com -Map map.csv -Defaults defaults.csv
    Assign them.

.NOTES
    Windows PowerShell 5.1 compatible. Nothing to install.

    Assignment is additive on Vault's side: sending a user who is already in the role
    changes nothing. That plus the read-then-compare makes this safe to run repeatedly -
    a second run over the same map is a no-op.

    The session id is cached in .vault-session.json beside this script; -Logout removes
    it. The password itself never touches disk.

    API: GET /objects/documents/{id}/roles, POST /objects/documents/roles/batch.
    Mirrored offline in the repo at
    docs/api/vault-api/api-reference/26.2/document-binder-roles/document-roles/.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Vault = '',
    [string]$Map = '',
    [string]$Where = '',
    [ValidateSet('Lifecycle', 'Document', 'Table')][string]$DesiredFrom = 'Lifecycle',
    [ValidateSet('Both', 'Groups', 'Users')][string]$Assign = 'Both',
    [switch]$WithTypeDefaults,
    [string]$Defaults = '',
    [string]$Api = 'v26.2',
    [string]$OutputRoot = '',

    [switch]$Version,
    [switch]$Logout,
    [switch]$Probe,
    [switch]$Plan,
    [string[]]$Role = @(),
    [string[]]$ExcludeRole = @(),
    [int]$Test = 0,
    [int]$Limit = 0,
    [ValidateRange(1, 1000)][int]$BatchSize = 200,
    [switch]$Fresh,

    [pscredential]$Credential
)

$ScriptVersion = '2026.08.28-14'

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -WhatIf means "withhold every write to VAULT". It must not also silence the log and the
# report - those are how anyone sees what a dry run would have done. Add-Content and
# Export-Csv both honour it, so every local write below carries -WhatIf:$false.
$script:WhatIf = [bool]$WhatIfPreference


# ======================================================================================
#  Small things everything else uses
# ======================================================================================

$script:LogFile = ''

function Write-Log {
    param(
        [Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Message,
        # Position 1 matters: every call site passes the level positionally. Giving
        # Message a position and not Level makes Level named-only, and each of those
        # calls then fails with "A positional parameter cannot be found".
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
        try { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -WhatIf:$false } catch { }
    }
}

function Get-Field {
    # Strict-mode-safe property read. Set-StrictMode turns a missing property into a
    # terminating error, which has killed a run inside a log line - reading a field purely
    # to print it, after the call had already succeeded.
    param($Object, [Parameter(Mandatory)][string]$Name, $Default = '')
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    if ($p.Value -is [string] -and [string]::IsNullOrWhiteSpace($p.Value)) { return $Default }
    return $p.Value
}

function Test-CanPrompt {
    # Read-Host and Get-Credential block for ever when stdin is redirected - a scheduled
    # task, a pipeline, a CI step. Better to fail naming the parameter that would have
    # answered the question.
    try { return -not [Console]::IsInputRedirected } catch { return $true }
}

function ConvertTo-NameKey {
    # A key that survives Vault handing back the NAME in one place and the LABEL in
    # another for the same thing.
    #
    # GET /objects/documents/{id} reports lifecycle__v as "General Lifecycle".
    # GET /configuration/role_assignment_rule reports it as "general_lifecycle__c".
    # Keyed literally those are two different lifecycles, so every rule lookup missed,
    # every role came back "no rule", and an assign run would have read every document in
    # the vault and written nothing - reporting success while doing so.
    #
    # Dropping the __c/__v/__sys suffix before folding makes both spellings converge, and
    # a label really is the name in title case in every case seen so far.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $v = $Value -replace '__(c|v|sys)$', ''
    return ($v -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}

function ConvertTo-Key {
    # One spelling for every name comparison. The UI shows labels ("Label Authors"), the
    # API returns names ("label_authors__c"), and a person transcribing a screen will
    # produce either. Compare on a form that survives both.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return ($Value -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}


# ======================================================================================
#  Settings
# ======================================================================================

function Get-HostName {
    # Operators paste what is in the address bar, scheme and path included.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $h = $Value -replace '^https?://', ''
    $h = ($h -split '/')[0]
    return $h.Trim().TrimEnd('/')
}

function Read-Setting {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][string]$Parameter,
        [string]$Default = ''
    )
    if ($Value) { return $Value }
    if (-not (Test-CanPrompt)) {
        # A default is an answer, not a suggestion, when there is nobody to ask. Throwing
        # here with a perfectly good cached value in hand would break the unattended run
        # for no reason.
        if ($Default) { return $Default }
        throw "$Label was not given and there is nobody here to ask. Pass -$Parameter."
    }
    $suffix = if ($Default) { " [$Default]" } else { '' }
    while ($true) {
        $answer = (Read-Host "  $Label$suffix").Trim().Trim('"', "'")
        if (-not $answer -and $Default) { return $Default }
        if ($answer) { return $answer }
        Write-Host "    $Label is required." -ForegroundColor Yellow
    }
}

function Resolve-Settings {
    Write-Host ''
    Write-Host "veeva-roles $ScriptVersion" -ForegroundColor Cyan
    Write-Host ''

    $vaultHost = Get-HostName (Read-Setting -Label 'Vault' -Value $Vault -Parameter 'Vault' `
                                            -Default (Get-CachedVaultHost))
    if (-not $vaultHost) { throw 'A vault is required.' }

    # Nothing is asked for that the run does not need.
    #
    #   -Where     names the documents itself.
    #   -Probe     writes nothing, so it can survey a sample of the vault on its own. Made
    #              to demand a spreadsheet, the one step that is meant to cost nothing
    #              becomes the one step you have to prepare for.
    #
    # Otherwise a file already sitting in the folder is almost always the one meant, so
    # offer it rather than making someone type a path they can see from where they stand.
    $mapPath = ''
    if (-not $Where -and -not ($Probe -and -not $Map)) {
        $mapDefault = ''
        foreach ($guess in @('attachments-map.csv', 'map.csv')) {
            if (Test-Path -LiteralPath (Join-Path (Get-Location).ProviderPath $guess)) { $mapDefault = $guess; break }
        }
        $mapPath = Read-Setting -Label 'Map CSV' -Value $Map -Parameter 'Map' -Default $mapDefault
    }

    $root = $OutputRoot
    if (-not $root) { $root = (Get-Location).ProviderPath }
    $root = [IO.Path]::GetFullPath([IO.Path]::Combine((Get-Location).ProviderPath, $root))
    # Not on a bare drive root: trimming C:\ to C: means "the current directory on C:",
    # which is a different place.
    if ($root.Length -gt 3) { $root = $root.TrimEnd('\') }
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force -WhatIf:$false | Out-Null
    }

    $script:LogFile = Join-Path $root ('veeva-roles-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    return [pscustomobject]@{
        VaultHost = $vaultHost
        MapPath   = $mapPath
        Api       = $Api
        Out       = $root
        WhatIf    = $script:WhatIf
    }
}


# ======================================================================================
#  Authentication
#
#  The session is cached in .vault-session.json beside this script and reused by the next
#  run, keyed by vault host. Probing, planning and assigning are three runs over the same
#  vault minutes apart, and making each one stop for a credential prompt is a tax on
#  exactly the careful, iterative use this tool is built around.
#
#  It is a bearer token: whoever holds that file acts as you until Vault expires it. The
#  file is ACL'd to the current user where Windows allows it, but it is NOT encrypted.
#  Treat it like a password, and -Logout deletes it.
# ======================================================================================

$script:Sessions    = @{}
$script:Cred        = $null
$script:SessionPath = ''
$script:SessionsRead = $false

function Get-SessionPath {
    if ($script:SessionPath) { return $script:SessionPath }
    $here = $PSScriptRoot
    if (-not $here) { $here = (Get-Location).ProviderPath }
    $script:SessionPath = Join-Path $here '.vault-session.json'
    return $script:SessionPath
}

function Read-Sessions {
    # Hydrate once. An unreadable or half-written file is not a reason to stop - it only
    # means logging in again, which is what would have happened without it anyway.
    if ($script:SessionsRead) { return }
    $script:SessionsRead = $true
    $path = Get-SessionPath
    if (-not (Test-Path -LiteralPath $path)) { return }
    try {
        $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        foreach ($p in $json.PSObject.Properties) {
            $sid = "$(Get-Field $p.Value 'sessionId' '')"
            if (-not $sid) { continue }
            $script:Sessions[$p.Name] = $sid
            $age = ''
            try {
                $t = [datetime]::Parse("$(Get-Field $p.Value 'obtained' '')").ToUniversalTime()
                $age = ' ({0:N0} min old)' -f ((Get-Date).ToUniversalTime() - $t).TotalMinutes
            } catch { }
            Write-Log "Reusing the cached session for $($p.Name)$age - -Logout to discard it"
        }
    }
    catch { Write-Log "Session file unreadable, ignoring it: $_" 'WARN' }
}

function Write-Sessions {
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)]$Entry)
    $path = Get-SessionPath
    $all  = [ordered]@{}
    if (Test-Path -LiteralPath $path) {
        try {
            $json = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            foreach ($p in $json.PSObject.Properties) { $all[$p.Name] = $p.Value }
        } catch { }
    }
    $all[$VaultHost] = $Entry
    try {
        # -WhatIf:$false throughout. -WhatIf means "write nothing to VAULT"; suppressing
        # the session cache would only make a rehearsal ask for credentials again.
        ($all | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $path -Encoding UTF8 -WhatIf:$false
    }
    catch { Write-Log "Could not write the session file: $_" 'WARN'; return }

    # Restrict to the current user. Windows only; elsewhere this is a no-op and the file
    # inherits the directory's permissions.
    try {
        $acl = Get-Acl -LiteralPath $path
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($r in @($acl.Access)) { [void]$acl.RemoveAccessRule($r) }
        $me   = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $path -AclObject $acl
    }
    catch { }
}

function Get-CachedVaultHost {
    # The host of the most recently obtained session, for the prompt's default.
    #
    # Deliberately does NOT log or use the hydrated cache: this runs before the log file
    # exists, because the answer is needed to work out where the log file goes.
    #
    # Offered as a default rather than used outright. It is one keystroke, and it puts the
    # vault about to be written to on the screen before anything happens - which for a
    # tool that grants people access is worth the keystroke.
    $path = Get-SessionPath
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    try {
        $json  = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $best  = ''
        $bestT = [datetime]::MinValue
        foreach ($p in $json.PSObject.Properties) {
            if (-not "$(Get-Field $p.Value 'sessionId' '')") { continue }
            $t = [datetime]::MinValue
            try { $t = [datetime]::Parse("$(Get-Field $p.Value 'obtained' '')") } catch { }
            if (-not $best -or $t -gt $bestT) { $best = $p.Name; $bestT = $t }
        }
        return $best
    }
    catch { return '' }
}

function Clear-Sessions {
    $path = Get-SessionPath
    $script:Sessions = @{}
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -WhatIf:$false
        return $true
    }
    return $false
}

function Get-VaultCredential {
    param([string]$Message = 'Vault credentials')
    if ($script:Cred) { return $script:Cred }
    if ($Credential) { $script:Cred = $Credential; return $script:Cred }
    if (-not (Test-CanPrompt)) { throw 'No credentials and no way to ask for them here. Pass -Credential.' }
    $script:Cred = Get-Credential -Message $Message
    if (-not $script:Cred) { throw 'No credentials given.' }
    return $script:Cred
}

function Connect-Vault {
    # Every field is read defensively. Under StrictMode a missing property is a
    # terminating error, and reaching straight for $r.vaultId to print it has killed a run
    # AFTER the login succeeded - which also hid the response that would have explained
    # why the field was absent.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion)

    $cred = Get-VaultCredential -Message "Vault login for $VaultHost"
    $body = @{ username = $cred.UserName; password = $cred.GetNetworkCredential().Password }
    $r = Invoke-RestMethod -Method Post -Uri "https://$VaultHost/api/$ApiVersion/auth" `
            -Body $body -ContentType 'application/x-www-form-urlencoded' `
            -Headers @{ Accept = 'application/json' }

    if ((Get-Field $r 'responseStatus') -ne 'SUCCESS') {
        throw "Authentication failed for ${VaultHost}: $($r | ConvertTo-Json -Depth 5 -Compress)"
    }
    $sid = "$(Get-Field $r 'sessionId' '')"
    if (-not $sid) {
        throw "Authentication for $VaultHost returned no sessionId. Vault said: $($r | ConvertTo-Json -Depth 5 -Compress)"
    }

    $script:Sessions[$VaultHost] = $sid
    Write-Sessions -VaultHost $VaultHost -Entry ([pscustomobject]@{
        sessionId = $sid
        userId    = "$(Get-Field $r 'userId' '')"
        vaultId   = "$(Get-Field $r 'vaultId' '')"
        api       = $ApiVersion
        obtained  = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    })
    Write-Log "$VaultHost - authenticated (vaultId $(Get-Field $r 'vaultId' '?'), userId $(Get-Field $r 'userId' '?'))" 'OK'
    return $sid
}

function Get-SessionId {
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion)
    Read-Sessions
    if ($script:Sessions.ContainsKey($VaultHost)) { return $script:Sessions[$VaultHost] }
    return (Connect-Vault -VaultHost $VaultHost -ApiVersion $ApiVersion)
}

function Test-Session {
    # Prove a cached session before leaning on it. Vault expires sessions on idle, so the
    # one in the file is often dead - and finding that out on the first call of a long run
    # is fine, but finding it out AFTER the enumeration and the directory build is a
    # minute of someone's life spent to learn they have to log in.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion)
    Read-Sessions
    if (-not $script:Sessions.ContainsKey($VaultHost)) { return }
    try {
        [void](Invoke-Api -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET `
                  -Path '/objects/users/me' -MaxRetries 1)
    }
    catch {
        Write-Log "The cached session for $VaultHost is no longer good - logging in again" 'WARN'
        $script:Sessions.Remove($VaultHost)
        [void](Connect-Vault -VaultHost $VaultHost -ApiVersion $ApiVersion)
    }
}

function Reset-Session {
    # Vault rejected the session mid-run. Re-authenticate from the credential held in
    # memory so a long job outlives its session instead of stopping at hour three. With
    # nothing in memory - a session that came from the file - this prompts once.
    param([Parameter(Mandatory)][string]$VaultHost, [Parameter(Mandatory)][string]$ApiVersion)
    Write-Log "$VaultHost - session expired, re-authenticating" 'WARN'
    $script:Sessions.Remove($VaultHost)
    return (Connect-Vault -VaultHost $VaultHost -ApiVersion $ApiVersion)
}


# ======================================================================================
#  HTTP
# ======================================================================================

function Invoke-Api {
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body,
        [string]$ContentType,
        [int]$TimeoutSec = 900,
        [int]$MaxRetries = 4
    )
    # Three shapes of Path arrive here and they are not interchangeable:
    #   https://...       a full URL, which pagination returns
    #   /api/v26.2/query  host-relative and ALREADY carrying the api prefix, which
    #                     next_page returns - prefixing again gives /api/v26.2/api/v26.2
    #   /objects/...      our own calls, relative to the versioned base
    $uri =
        if     ($Path -match '^https?://') { $Path }
        elseif ($Path -match '^/api/')     { "https://$VaultHost$Path" }
        else                               { "https://$VaultHost/api/$ApiVersion$Path" }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sid = Get-SessionId -VaultHost $VaultHost -ApiVersion $ApiVersion

        try {
            $req = @{ Method = $Method; Uri = $uri
                      Headers = @{ Authorization = $sid; Accept = 'application/json' }
                      TimeoutSec = $TimeoutSec; UseBasicParsing = $true }
            if ($null -ne $Body) { $req['Body'] = $Body }
            if ($ContentType)    { $req['ContentType'] = $ContentType }

            $resp = Invoke-WebRequest @req

            $remaining = $resp.Headers['X-VaultAPI-BurstLimitRemaining']
            if ($remaining -and [int]$remaining -lt 200) {
                Write-Log "$VaultHost burst limit low ($remaining) - pausing 30s" 'WARN'
                Start-Sleep -Seconds 30
            }

            $json = $null
            if ($resp.Content) { try { $json = $resp.Content | ConvertFrom-Json } catch { } }
            if ($null -eq $json) { return [pscustomobject]@{ responseStatus = 'SUCCESS'; raw = $resp.Content } }

            if ((Get-Field $json 'responseStatus') -eq 'FAILURE') {
                $errs  = @(Get-Field $json 'errors' @())
                $types = @($errs | ForEach-Object { Get-Field $_ 'type' })
                if ($types -contains 'INVALID_SESSION_ID') {
                    [void](Reset-Session -VaultHost $VaultHost -ApiVersion $ApiVersion)
                    continue
                }
                throw "$VaultHost $Method $Path -- " +
                      (($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; ')
            }
            return $json
        }
        catch {
            # 5.1 raises WebException; 7 raises HttpResponseException for a status and
            # HttpRequestException for a transport failure. Matching on the type NAME
            # covers all three without needing System.Net.Http loadable on 5.1. Anything
            # else is a bug in this file and is rethrown rather than retried four times.
            $ex   = $_.Exception
            $name = $ex.GetType().Name
            if ($name -notin @('WebException', 'HttpResponseException', 'HttpRequestException')) { throw }

            $status = $null
            try { if ($ex.Response) { $status = [int]$ex.Response.StatusCode } } catch { }

            if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                Write-Log "$VaultHost HTTP 429 - waiting 60s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = [math]::Pow(2, $attempt) * 5
                Write-Log "$VaultHost transient error on $Method $Path (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            $detail = ''
            try { $detail = "$($_.ErrorDetails.Message)" } catch { }
            if (-not $detail) {
                try { $detail = (New-Object IO.StreamReader($ex.Response.GetResponseStream())).ReadToEnd() } catch { }
            }
            throw "$VaultHost $Method $Path failed (HTTP $status): $($ex.Message) $detail"
        }
    }
    throw "$VaultHost $Method $Path failed after $MaxRetries attempts"
}


# ======================================================================================
#  The map
#
#  Every rule here was met in a real export, not imagined. A spreadsheet arrives as
#  whatever produced it left it: a byte order mark, tabs instead of commas, two columns
#  called "Created By", headers written for people rather than parsers, a row per file so
#  one document appears eight times, and #N/A where a lookup found nothing.
# ======================================================================================

function Test-IsIdColumn {
    # Match on what a header MEANS, not a list of exact spellings. Real headers are
    # written for people - "Source (old) Document ID" is perfectly clear and matches no
    # fixed name at all.
    param([string]$Header, [string[]]$Words)
    $n = ConvertTo-Key $Header
    if ($n -notmatch 'id$|id[^a-z]|^id') { return $false }
    foreach ($w in $Words) { if ($n -like "*$w*") { return $true } }
    return $false
}

function Import-DelimitedFile {
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
    if ($renamed) { Write-Log "$renamed duplicate column name(s) in $(Split-Path -Leaf $resolved) suffixed to keep them apart" }

    $rows = @($all | Select-Object -Skip 1 | ConvertFrom-Csv -Header $names -Delimiter $delim)
    if ($rows.Count -eq 0) { throw "$resolved has a header but no rows" }

    $shown = if ($delim -eq "`t") { 'tab' } else { $delim }
    return [pscustomobject]@{ Path = $resolved; Rows = $rows; Names = @($names); Delimiter = $shown }
}

function Import-TargetIds {
    # The documents to repair: the TARGET id column of the migration map. The source
    # column is read too, purely so the report can say which old document a row came from
    # - that is the only handle anyone has when a result needs chasing back to a
    # spreadsheet row.
    param([Parameter(Mandatory)][string]$Path)

    $f    = Import-DelimitedFile -Path $Path
    $names = $f.Names
    Write-Log "Map columns: $($names -join ', ')"

    $srcCol = @($names | Where-Object { Test-IsIdColumn -Header $_ -Words @('source', 'old', 'from', 'legacy') })
    $tgtCol = @($names | Where-Object { Test-IsIdColumn -Header $_ -Words @('destination', 'target', 'new', 'to') })
    if ($tgtCol.Count -gt 1) { throw "More than one column could be the target id: $($tgtCol -join ', '). Rename the extras in the sheet." }
    if ($srcCol.Count -gt 1) { throw "More than one column could be the source id: $($srcCol -join ', '). Rename the extras in the sheet." }
    if ($tgtCol.Count -ne 1) {
        throw "Could not work out which column holds the target document id in $($f.Path). Headers: $($names -join ', ')."
    }
    $tgtCol = $tgtCol[0]
    $srcCol = if ($srcCol.Count -eq 1) { $srcCol[0] } else { '' }

    $out  = New-Object System.Collections.ArrayList
    $seen = @{}
    $bad = 0; $sci = 0; $dupes = 0
    $badRows = New-Object System.Collections.ArrayList
    $rowNo = 1

    foreach ($row in $f.Rows) {
        $rowNo++
        $t = "$(Get-Field $row $tgtCol '')".Trim()
        $s = if ($srcCol) { "$(Get-Field $row $srcCol '')".Trim() } else { '' }

        if ($t -match '^\d+(\.\d+)?[eE][+-]?\d+$') { $sci++; $bad++; continue }
        if ($t -notmatch '^\d+$') {
            $bad++
            [void]$badRows.Add(("line {0}: target='{1}' source='{2}'" -f $rowNo, $t, $s))
            continue
        }
        # A row per file means one document appears many times. Repeats are expected.
        if ($seen.ContainsKey($t)) { $dupes++; continue }
        $seen[$t] = $true
        [void]$out.Add([pscustomobject]@{ TargetId = $t; SourceId = $s })
    }

    if ($sci) {
        # Refuse rather than continue on the rows that survived: a mangled id is a
        # document that silently never gets repaired while the run still reports success.
        throw @"
$sci row(s) in $($f.Path) hold ids in scientific notation, e.g. 5.5283E+04.

Excel does that to long numbers on export and the digits are gone - they cannot be
recovered from the file. Re-export with the id columns formatted as Text.
"@
    }
    if ($bad) {
        Write-Log "$bad row(s) in $($f.Path) had no usable target id and were skipped - those are NOT repaired" 'WARN'
        foreach ($br in ($badRows | Select-Object -First 10)) { Write-Log "  $br" 'WARN' }
        if ($badRows.Count -gt 10) { Write-Log "  ... and $($badRows.Count - 10) more" 'WARN' }

        $excel = @($badRows | Where-Object { $_ -match '#(N/A|REF!|VALUE!|NAME\?|DIV/0!|NUM!|NULL!)' })
        if ($excel.Count) {
            Write-Log "  $($excel.Count) hold an Excel error such as #N/A - the lookup in the sheet found no match," 'WARN'
            Write-Log '  so those documents were never migrated, or the formula missed them.' 'WARN'
        }
    }
    if ($dupes) { Write-Log "$dupes repeated row(s) for documents already listed - expected when the sheet has a row per file" }
    if ($out.Count -eq 0) { throw "No usable target ids in $($f.Path)" }

    Write-Log "$($out.Count) document(s) from $($f.Path) ($($f.Delimiter)-separated, target column '$tgtCol')" 'OK'
    return @($out)
}

function Get-DocumentsByQuery {
    # The documents to repair, enumerated from the vault instead of listed in a map.
    #
    # A map says exactly which documents a migration produced, and that is the safer
    # scope. A query is for when the migration WAS the vault, or when the job is "every
    # document of this subtype" - cases where maintaining a spreadsheet of ids would be
    # busywork. Only the WHERE clause is taken, so the query cannot quietly select
    # something other than document ids.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Where,
        # Stop paging once this many are in hand. 0 means every page. A survey needs
        # twenty-five documents, and paging a 500,000-document vault to the end to throw
        # away all but twenty-five is five hundred calls spent on nothing.
        [int]$Stop = 0
    )

    $w = $Where.Trim()
    $vql = if (-not $w)                  { 'SELECT id FROM documents' }
           elseif ($w -match '^\s*SELECT\s') { $w }
           else                          { "SELECT id FROM documents WHERE $w" }
    Write-Log "Enumerating: $vql"

    $out  = New-Object System.Collections.ArrayList
    $seen = @{}
    $path  = '/query'
    $body  = "q=$([Uri]::EscapeDataString($vql))"
    $pages = 0

    while ($path -and $pages -lt 1000) {
        $pages++
        # Page 1 is a POST carrying the query; every page after it is a GET on the URL
        # Vault hands back, which already has the query baked in.
        $r = if ($pages -eq 1) {
                Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
                    -Path $path -Body $body -ContentType 'application/x-www-form-urlencoded'
             } else {
                Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path $path
             }

        foreach ($row in @(Get-Field $r 'data' @())) {
            $id = "$(Get-Field $row 'id' '')"
            if (-not $id -or $seen.ContainsKey($id)) { continue }
            $seen[$id] = $true
            [void]$out.Add([pscustomobject]@{ TargetId = $id; SourceId = '' })
        }
        if ($Stop -gt 0 -and $out.Count -ge $Stop) { break }
        $path = "$(Get-Field (Get-Field $r 'responseDetails' $null) 'next_page' '')"
    }

    if ($out.Count -eq 0) { throw "The query matched no documents: $vql" }
    if ($Stop -gt 0 -and $out.Count -gt $Stop) { $out = @($out | Select-Object -First $Stop) }
    Write-Log "$($out.Count) document(s) from the query" 'OK'
    return @($out)
}


# ======================================================================================
#  Users and groups, by name
#
#  The document roles API speaks in numeric ids. The Admin screen a defaults table is
#  transcribed from speaks in labels. Both directions are needed: names in, so the table
#  can be written by a person, and names out, so the plan can be read by one.
# ======================================================================================

$script:Directory = $null

function Get-Directory {
    # Every user and group in the vault, indexed by id and by every name it answers to.
    # Fetched once. A vault with tens of thousands of users makes this a handful of pages;
    # doing it per document instead would make it thousands of calls.
    param([Parameter(Mandatory)]$Context)
    if ($script:Directory) { return $script:Directory }

    $byId      = @{}
    $byName    = @{}
    $byMembers = @{}   # group id -> the user ids in it

    # Both listings come back wrapped - users: [ { user: {...} } ] - but not every Vault
    # release wraps them, so unwrap defensively rather than assuming either shape.
    function Add-Entry {
        param($Record, [string]$Wrapper, [string[]]$NameFields, [string]$Kind)
        $r = Get-Field $Record $Wrapper $null
        if ($null -eq $r) { $r = $Record }
        $id = "$(Get-Field $r 'id' '')"
        if (-not $id) { return }
        $names = @()
        foreach ($nf in $NameFields) {
            $v = "$(Get-Field $r $nf '')"
            if ($v) { $names += $v }
        }
        $display = if ($names.Count) { $names[0] } else { $id }
        $byId["$Kind`:$id"] = $display
        # Group membership, so a run can say whether the users it is about to assign
        # directly are simply the people already in the groups it is assigning.
        if ($Kind -eq 'group') {
            $byMembers[$id] = @(@(Get-Field $r 'members__v' @()) | ForEach-Object { "$_" })
        }
        # Indexed under BOTH foldings. A group arrives here as a label ("Business
        # Administrators") and is looked up by MDL as a name ("business_administrators__c");
        # keying only one way means the lookup misses and the group is silently dropped
        # from a role. That is the same failure the lifecycle join already had.
        foreach ($n in $names) {
            foreach ($k in @("$Kind`:$(ConvertTo-Key $n)", "$Kind`:$(ConvertTo-NameKey $n)")) {
                if (-not $byName.ContainsKey($k)) { $byName[$k] = $id }
            }
        }
    }

    # Groups come back whole - Retrieve All Groups documents no pagination parameters at
    # all - so one call is the whole set.
    $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET -Path '/objects/groups'
    foreach ($rec in @(Get-Field $r 'groups' @())) {
        Add-Entry -Record $rec -Wrapper 'group' -NameFields @('label__v', 'name__v') -Kind 'group'
    }

    # Users page by limit and start, NOT by responseDetails.next_page - that field is a
    # VQL thing and this endpoint does not return it. Reading the page-1 response for a
    # next_page that is never there stops silently at the first 200 users, and a user the
    # directory has never heard of resolves to nothing, which quietly shrinks a role.
    #
    # 200 is the documented default. Anything from 500 up is rejected outright:
    # INVALID_DATA, "The 'limit' parameter must be < 500."
    $pageSize = 200
    $start    = 0
    $pages    = 0
    while ($pages -lt 2000) {
        $pages++
        $before = $byId.Count
        $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/objects/users?limit=$pageSize&start=$start"
        $batch = @(Get-Field $r 'users' @())
        foreach ($rec in $batch) {
            Add-Entry -Record $rec -Wrapper 'user' -NameFields @('user_name__v', 'user_email__v', 'name__v') -Kind 'user'
        }
        # Two independent stop conditions, because either alone can fail. A short page
        # means the end; no NEW entries means the endpoint ignored `start` and is handing
        # back page one for ever, which would otherwise spin until the page cap.
        if ($batch.Count -lt $pageSize) { break }
        if ($byId.Count -eq $before)    { break }
        $start += $pageSize
    }

    $users  = @($byId.Keys | Where-Object { $_ -like 'user:*' }).Count
    $groups = @($byId.Keys | Where-Object { $_ -like 'group:*' }).Count
    Write-Log "Directory: $users user(s), $groups group(s)"
    $script:Directory = [pscustomobject]@{ ById = $byId; ByName = $byName; Members = $byMembers }
    return $script:Directory
}

# ======================================================================================
#  Document type default security
#
#  The "Default Settings for New Documents" box on Admin > Document Types > (subtype) >
#  Security. This is NOT the lifecycle's role assignment rules, and it is NOT in
#  defaultUsers/defaultGroups on the document roles endpoint - a real vault reported
#  nothing at all for editor__v while that screen listed three groups for it.
#
#  It IS in the MDL component for the doctype, as role_defaulting_editors / _viewers /
#  _consumers, each a list of "group:Group.name__c" or "user:username". Read once per
#  subtype rather than once per document, so it costs a handful of calls for a whole run.
# ======================================================================================

$script:DocTypeNames    = $null
$script:DocTypeDefaults = @{}

function Get-DocTypeNameIndex {
    # label -> api name, for document types. A document reports LABELS ("Administrative
    # Information") while MDL is keyed by NAME, so one has to become the other before
    # anything can be looked up at all.
    param([Parameter(Mandatory)]$Context)
    if ($script:DocTypeNames) { return $script:DocTypeNames }

    $types = @{}
    $subs  = @{}
    $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path '/metadata/objects/documents/types'
    foreach ($ty in @(Get-Field $r 'types' @())) {
        $label = "$(Get-Field $ty 'label' '')"
        $url   = "$(Get-Field $ty 'value' '')"
        if (-not $label -or -not $url) { continue }
        $name = ($url -split '/')[-1]
        if ($name) { $types[(ConvertTo-NameKey $label)] = $name }
    }
    $script:DocTypeNames = [pscustomobject]@{ Types = $types; Subtypes = $subs }
    return $script:DocTypeNames
}

function Get-SubtypeName {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$TypeName,
        [Parameter(Mandatory)][AllowEmptyString()][string]$SubtypeLabel
    )
    $idx = Get-DocTypeNameIndex -Context $Context
    $key = "$TypeName|$(ConvertTo-NameKey $SubtypeLabel)"
    if ($idx.Subtypes.ContainsKey($key)) { return $idx.Subtypes[$key] }
    try {
        $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/metadata/objects/documents/types/$TypeName"
        foreach ($st in @(Get-Field $r 'subtypes' @())) {
            $label = "$(Get-Field $st 'label' '')"
            $url   = "$(Get-Field $st 'value' '')"
            if (-not $label -or -not $url) { continue }
            $nm = ($url -split '/')[-1]
            if ($nm) { $idx.Subtypes["$TypeName|$(ConvertTo-NameKey $label)"] = $nm }
        }
    }
    catch { Write-Log "  could not list the subtypes of ${TypeName}: $_" 'WARN' }
    if ($idx.Subtypes.ContainsKey($key)) { return $idx.Subtypes[$key] }
    return ''
}

function ConvertFrom-MdlPrincipalList {
    # "group:Group.business_administrators__c" / "user:jane@example.com" -> ids.
    param(
        [Parameter(Mandatory)]$Directory,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Values
    )
    $users   = New-Object System.Collections.ArrayList
    $groups  = New-Object System.Collections.ArrayList
    $unknown = New-Object System.Collections.ArrayList
    foreach ($raw in $Values) {
        $v = "$raw".Trim().Trim("'", '"')
        if (-not $v) { continue }
        if ($v -match '^group:\s*(?:Group\.)?(.+)$') {
            $nm = $Matches[1].Trim()
            $id = Resolve-NameToId -Directory $Directory -Kind 'group' -Name $nm
            if ($id) { [void]$groups.Add($id) } else { [void]$unknown.Add("group '$nm'") }
        }
        elseif ($v -match '^user:\s*(.+)$') {
            $nm = $Matches[1].Trim()
            $id = Resolve-NameToId -Directory $Directory -Kind 'user' -Name $nm
            if ($id) { [void]$users.Add($id) } else { [void]$unknown.Add("user '$nm'") }
        }
    }
    return [pscustomobject]@{ Users = @($users); Groups = @($groups); Unknown = @($unknown) }
}

function Get-MdlAttributeValue {
    # One multi-value attribute out of an MDL component response.
    #
    # Three shapes are accepted because this endpoint's is not documented in the mirror: a
    # JSON component carrying the attribute as a property, one carrying it in an
    # attributes list, and raw MDL source written as name('a', 'b'). Betting on one and
    # being wrong would apply no type defaults at all and say nothing - which is precisely
    # the failure this code exists to fix.
    param([Parameter(Mandatory)]$Response, [Parameter(Mandatory)][string]$Attribute)

    foreach ($holder in @($Response, (Get-Field $Response 'data' $null), (Get-Field $Response 'component' $null))) {
        if ($null -eq $holder) { continue }
        $v = Get-Field $holder $Attribute $null
        if ($null -ne $v) { return @($v) }
        foreach ($listName in @('attributes', 'properties')) {
            foreach ($a in @(Get-Field $holder $listName @())) {
                if ("$(Get-Field $a 'name' '')" -eq $Attribute) {
                    $av = Get-Field $a 'value' $null
                    if ($null -ne $av) { return @($av) }
                }
            }
        }
    }

    $raw = "$(Get-Field $Response 'raw' '')"
    if ($raw -and $raw -match ($Attribute + '\s*\(([^)]*)\)')) {
        return @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim("'", '"') } | Where-Object { $_ })
    }
    return @()
}

function Get-DocTypeRoleDefault {
    # editor__v / viewer__v / consumer__v defaults for one subtype, from its MDL component.
    # Cached, so a run over 15,000 documents of six subtypes makes six of these calls.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$TypeLabel,
        [Parameter(Mandatory)][AllowEmptyString()][string]$SubtypeLabel,
        [Parameter(Mandatory)]$Directory
    )
    $cacheKey = "$TypeLabel|$SubtypeLabel"
    if ($script:DocTypeDefaults.ContainsKey($cacheKey)) { return $script:DocTypeDefaults[$cacheKey] }

    $empty = @{}
    $script:DocTypeDefaults[$cacheKey] = $empty
    if (-not $TypeLabel) { return $empty }

    $idx     = Get-DocTypeNameIndex -Context $Context
    $typeKey = ConvertTo-NameKey $TypeLabel
    if (-not $idx.Types.ContainsKey($typeKey)) {
        Write-Log "No document type called '$TypeLabel' - its type defaults cannot be read" 'WARN'
        return $empty
    }
    $typeName = $idx.Types[$typeKey]

    # Walk the hierarchy, most specific first. The component reference is explicit that
    # these attributes are inherited: "If none are specified, the default value is
    # inherited from parent or base." A subtype usually does NOT restate them, which is
    # why reading only the subtype found nothing while the Admin screen - which shows the
    # EFFECTIVE value - listed three groups.
    #
    # First level that defines a role wins for that role, which is what inheritance means.
    # Roles are filled independently: a subtype may override Editors while still
    # inheriting Viewers from its type.
    $candidates = New-Object System.Collections.ArrayList
    if ($SubtypeLabel -and (ConvertTo-NameKey $SubtypeLabel) -ne $typeKey) {
        $subName = Get-SubtypeName -Context $Context -TypeName $typeName -SubtypeLabel $SubtypeLabel
        if ($subName) { [void]$candidates.Add("Doctype.$typeName.$subName") }
    }
    [void]$candidates.Add("Doctype.$typeName")
    [void]$candidates.Add('Doctype.base_document__v')

    $out      = @{}
    $unknown  = New-Object System.Collections.ArrayList
    $sources  = New-Object System.Collections.ArrayList
    $lastResp = $null
    $lastName = ''
    $why      = ''

    foreach ($component in $candidates) {
        if ($out.Count -eq 3) { break }   # every role already answered by a nearer level

        # Two endpoints return this, and they are shaped differently on purpose:
        #
        #   GET /api/{version}/configuration/{Type}.{name}   JSON, versioned
        #   GET /api/mdl/components/{Type}.{name}            MDL source, NOT versioned
        #
        # The second has no version segment at all. Building it as /api/v26.2/mdl/... earns
        # a 404 MALFORMED_URL, which is how the first attempt at this failed.
        $r = $null
        foreach ($path in @("/configuration/$component", "/api/mdl/components/$component")) {
            try {
                $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                        -Path $path -MaxRetries 1
                break
            }
            catch { if (-not $why) { $why = "$_" } }
        }
        if ($null -eq $r) { continue }
        $lastResp = $r
        $lastName = $component

        foreach ($pair in @(
            @{ Role = 'editor__v';   Attr = 'role_defaulting_editors' },
            @{ Role = 'viewer__v';   Attr = 'role_defaulting_viewers' },
            @{ Role = 'consumer__v'; Attr = 'role_defaulting_consumers' }
        )) {
            if ($out.ContainsKey($pair.Role)) { continue }
            $vals = @(Get-MdlAttributeValue -Response $r -Attribute $pair.Attr)
            if (-not $vals.Count) { continue }
            $res = ConvertFrom-MdlPrincipalList -Directory $Directory -Values $vals
            foreach ($u in $res.Unknown) { [void]$unknown.Add($u) }
            if ($res.Users.Count -or $res.Groups.Count) {
                $out[$pair.Role] = [pscustomobject]@{ Users = $res.Users; Groups = $res.Groups }
                [void]$sources.Add("$($pair.Role) from $component")
            }
        }
    }

    if ($unknown.Count) {
        Write-Log "Type defaults name $($unknown.Count) principal(s) matching nothing in this vault: $(($unknown | Select-Object -Unique | Select-Object -First 5) -join '; ')" 'WARN'
    }

    if ($out.Count) {
        Write-Log "Type defaults for '$SubtypeLabel': $(($sources | Sort-Object) -join ', ')"
    }
    else {
        # Nothing found anywhere up the hierarchy. That is either a vault that really has
        # no type defaults, or a response shaped in a way this does not read - and those
        # two look identical from the outside, so print what actually came back rather
        # than leave someone to guess which it was.
        Write-Log "No type defaults found for '$SubtypeLabel' at any level: $($candidates -join ', ')" 'WARN'
        if ($why) { Write-Log "  last error: $why" 'WARN' }
        if ($lastResp) {
            $props = @()
            try { $props = @($lastResp.PSObject.Properties | ForEach-Object { $_.Name }) } catch { }
            Write-Log "  $lastName returned: $($props -join ', ')" 'WARN'
            $raw = "$(Get-Field $lastResp 'raw' '')"
            if (-not $raw) { try { $raw = ($lastResp | ConvertTo-Json -Depth 4 -Compress) } catch { } }
            if ($raw.Length -gt 600) { $raw = $raw.Substring(0, 600) + ' ...' }
            Write-Log "  $raw" 'WARN'
        }
    }

    $script:DocTypeDefaults[$cacheKey] = $out
    return $out
}

function Get-RedundantUserCount {
    # How many of these users are already in at least one of these groups.
    #
    # Counted per USER, not per membership row. Counting per row reported 1,449 redundant
    # out of 1,430 total on a real run - a subset larger than the set it is part of -
    # because anyone in two of the groups was counted twice. A number that cannot be true
    # discredits the finding it exists to support.
    param(
        [Parameter(Mandatory)]$Directory,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Groups,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Users
    )
    if (-not $Users.Count -or -not $Groups.Count) { return 0 }
    $covered = @{}
    foreach ($g in $Groups) {
        if (-not $Directory.Members.ContainsKey("$g")) { continue }
        foreach ($m in $Directory.Members["$g"]) { $covered["$m"] = $true }
    }
    return @($Users | Where-Object { $covered.ContainsKey("$_") }).Count
}

function Get-DisplayName {
    param([Parameter(Mandatory)]$Directory, [Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Id)
    $k = "$Kind`:$Id"
    if ($Directory.ById.ContainsKey($k)) { return $Directory.ById[$k] }
    return $Id
}

function Resolve-NameToId {
    param([Parameter(Mandatory)]$Directory, [Parameter(Mandatory)][string]$Kind, [Parameter(Mandatory)][string]$Name)
    $n = $Name.Trim()
    if (-not $n) { return '' }
    if ($n -match '^\d+$') { return $n }      # already an id
    foreach ($k in @("$Kind`:$(ConvertTo-Key $n)", "$Kind`:$(ConvertTo-NameKey $n)")) {
        if ($Directory.ByName.ContainsKey($k)) { return $Directory.ByName[$k] }
    }
    return ''
}


# ======================================================================================
#  The desired state
#
#  Two sources, one shape. Without -Defaults it is whatever Vault reports as the defaults
#  for that document, which is the better answer when it is right because Vault has
#  already evaluated the override conditions. With -Defaults it is a table transcribed
#  from Admin > Document Types > Security, which is the better answer when it is not.
# ======================================================================================

function Import-DefaultsTable {
    # role,users,groups[,subtype] - names or ids, either spelling.
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)]$Directory)

    $f = Import-DelimitedFile -Path $Path
    $col = @{}
    foreach ($n in $f.Names) {
        switch (ConvertTo-Key $n) {
            'role'    { $col['role'] = $n }
            'users'   { $col['users'] = $n }
            'user'    { $col['users'] = $n }
            'groups'  { $col['groups'] = $n }
            'group'   { $col['groups'] = $n }
            'subtype' { $col['subtype'] = $n }
        }
    }
    if (-not $col.ContainsKey('role')) {
        throw "The defaults table needs a 'role' column. $($f.Path) has: $($f.Names -join ', ')."
    }
    if (-not $col.ContainsKey('users') -and -not $col.ContainsKey('groups')) {
        throw "The defaults table needs a 'users' or a 'groups' column. $($f.Path) has: $($f.Names -join ', ')."
    }

    $table   = New-Object System.Collections.ArrayList
    $unknown = New-Object System.Collections.ArrayList

    foreach ($row in $f.Rows) {
        $roleName = "$(Get-Field $row $col['role'] '')".Trim()
        if (-not $roleName) { continue }

        $users  = New-Object System.Collections.ArrayList
        $groups = New-Object System.Collections.ArrayList
        foreach ($pair in @(@{ Kind = 'user'; Col = 'users'; Bag = $users },
                            @{ Kind = 'group'; Col = 'groups'; Bag = $groups })) {
            if (-not $col.ContainsKey($pair.Col)) { continue }
            $raw = "$(Get-Field $row $col[$pair.Col] '')"
            foreach ($piece in ($raw -split '[,;|]')) {
                $name = $piece.Trim().Trim('"', "'")
                if (-not $name) { continue }
                $id = Resolve-NameToId -Directory $Directory -Kind $pair.Kind -Name $name
                if ($id) { [void]$pair.Bag.Add($id) }
                else     { [void]$unknown.Add("$($pair.Kind) '$name' (role $roleName)") }
            }
        }

        [void]$table.Add([pscustomobject]@{
            RoleKey = ConvertTo-Key $roleName
            RoleRaw = $roleName
            Subtype = if ($col.ContainsKey('subtype')) { ConvertTo-Key "$(Get-Field $row $col['subtype'] '')" } else { '' }
            Users   = @($users)
            Groups  = @($groups)
        })
    }

    if ($unknown.Count) {
        # Refuse. A name that resolved to nothing means a role silently gets fewer people
        # than the screen says it should, and the run still reports success - which is
        # exactly the failure this script exists to fix.
        $show = ($unknown | Select-Object -Unique | Select-Object -First 10) -join "`n    "
        throw @"
$($unknown.Count) name(s) in $($f.Path) match no user or group in this vault:

    $show

Check the spelling against Admin > Users & Groups. Ids are accepted too, if a name is
ambiguous.
"@
    }
    if ($table.Count -eq 0) { throw "No usable rows in $($f.Path)" }

    Write-Log "$($table.Count) default rule(s) from $($f.Path)" 'OK'
    return @($table)
}

function Get-DesiredForRole {
    # What this role should hold on this document, as two lists of ids, from whichever
    # source -DesiredFrom named. Every branch returns the same shape plus a Which/Message
    # pair saying where the answer came from, because that is what goes in the report and
    # it is the only way anyone can audit an assignment after the fact.
    param(
        [Parameter(Mandatory)][ValidateSet('Lifecycle', 'Document', 'Table')][string]$From,
        [Parameter(Mandatory)]$RoleRecord,
        [AllowNull()]$Table,
        [AllowNull()]$Rules,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Subtype,
        [AllowNull()]$DocumentInfo
    )
    $nameKey  = ConvertTo-Key "$(Get-Field $RoleRecord 'name' '')"
    $labelKey = ConvertTo-Key "$(Get-Field $RoleRecord 'label' '')"
    # The rules index is keyed name-tolerantly, so the lookup has to be too.
    $roleNameKey = ConvertTo-NameKey "$(Get-Field $RoleRecord 'name' '')"

    switch ($From) {

        'Document' {
            # Whatever Vault itself calls the default for this document. Cheapest, and it
            # needs no rule interpretation at all - but see -Probe for whether it carries
            # the document type's default security as well as the lifecycle's rules.
            return [pscustomobject]@{
                Users   = @(@(Get-Field $RoleRecord 'defaultUsers'  @()) | ForEach-Object { "$_" })
                Groups  = @(@(Get-Field $RoleRecord 'defaultGroups' @()) | ForEach-Object { "$_" })
                Which   = 'DOCUMENT_DEFAULT'
                Message = ''
            }
        }

        'Lifecycle' {
            if ($null -eq $Rules -or $null -eq $DocumentInfo) {
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_RULES'
                                          Message = 'the lifecycle rules were not read' }
            }
            if (-not $DocumentInfo.Read) {
                # The document could not be read, so which override applies is unknown.
                # Falling back to the default rule here would be the dangerous kind of
                # guess: an override exists precisely because the default is wrong for
                # some documents, and this may be one of them.
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'DOCUMENT_UNREADABLE'
                                          Message = 'could not read the document, so no rule can be chosen for it' }
            }
            if (-not $DocumentInfo.Lifecycle) {
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_LIFECYCLE'
                                          Message = 'the document reports no lifecycle' }
            }
            $key = "$(ConvertTo-NameKey $DocumentInfo.Lifecycle)|$roleNameKey"
            if (-not $Rules.ContainsKey($key)) {
                # Not an error. Most lifecycles configure rules for a few roles only, and
                # a role with no rule simply has no default - there is nothing to apply.
                return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_RULE_FOR_ROLE'; Message = '' }
            }
            return (Select-RuleForDocument -Rule $Rules[$key] -Conditions $DocumentInfo.Conditions)
        }

        default {
            $users  = New-Object System.Collections.ArrayList
            $groups = New-Object System.Collections.ArrayList
            foreach ($rule in @($Table)) {
                if ($rule.RoleKey -ne $nameKey -and $rule.RoleKey -ne $labelKey) { continue }
                # A subtype-less rule applies everywhere; a subtype-bearing one only to its own.
                if ($rule.Subtype -and $rule.Subtype -ne $Subtype) { continue }
                foreach ($u in $rule.Users)  { [void]$users.Add($u) }
                foreach ($g in $rule.Groups) { [void]$groups.Add($g) }
            }
            return [pscustomobject]@{ Users = @($users); Groups = @($groups); Which = 'TABLE'; Message = '' }
        }
    }
}


# ======================================================================================
#  Results - rewritten after every batch, so an interrupted run leaves a usable file
# ======================================================================================

function New-Results {
    param([Parameter(Mandatory)][string]$Path)
    $prior = [ordered]@{}

    if (Test-Path -LiteralPath $Path) {
        if ($Fresh) {
            $when = (Get-Item -LiteralPath $Path).LastWriteTime.ToString('yyyyMMdd-HHmmss')
            $moved = [IO.Path]::Combine([IO.Path]::GetDirectoryName($Path),
                     ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($Path), $when, [IO.Path]::GetExtension($Path)))
            Move-Item -LiteralPath $Path -Destination $moved -Force -WhatIf:$false
            Write-Log "Rotated previous results to $(Split-Path -Leaf $moved)"
        }
        else {
            # Rows an earlier run recorded for documents this run does not touch are
            # carried through rather than dropped - otherwise a capped run would truncate
            # the file to just what it processed, losing the record of everything already
            # done. Nothing is SKIPPED on the strength of them: the point of the read is
            # the CURRENT state, and an assignment recorded yesterday says nothing about
            # today.
            foreach ($row in (Import-Csv -LiteralPath $Path)) {
                $k = "$(Get-Field $row 'Key' '')"
                if ($k) { $prior[$k] = $row }
            }
            if ($prior.Count) { Write-Log "$($prior.Count) row(s) from an earlier run kept in the results file" }
        }
    }
    return [pscustomobject]@{ Path = $Path; Prior = $prior; Rows = (New-Object System.Collections.ArrayList) }
}

function Save-Results {
    param([Parameter(Mandatory)]$Results)
    $current = @{}
    foreach ($r in $Results.Rows) { $current["$(Get-Field $r 'Key' '')"] = $r }

    $out = New-Object System.Collections.ArrayList
    $written = @{}
    foreach ($k in $Results.Prior.Keys) {
        $key = "$k"
        if ($current.ContainsKey($key)) { [void]$out.Add($current[$key]) } else { [void]$out.Add($Results.Prior[$key]) }
        $written[$key] = $true
    }
    foreach ($r in $Results.Rows) {
        $key = "$(Get-Field $r 'Key' '')"
        if (-not $written.ContainsKey($key)) { [void]$out.Add($r) }
    }
    $out | Export-Csv -LiteralPath $Results.Path -NoTypeInformation -Encoding UTF8 -WhatIf:$false
}


# ======================================================================================
#  Reading and repairing
# ======================================================================================

function Get-DocumentRole {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$DocId
    )
    $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path "/objects/documents/$DocId/roles"
    return @(Get-Field $r 'documentRoles' @())
}

# The fields an override rule can be conditioned on. Read from every document so an
# override can be matched against it; eTMF adds the two study fields, and a vault without
# them simply reports nothing there.
$script:ConditionFields = @('product__v', 'country__v', 'study__v', 'study_country__v')

function Get-DocumentInfo {
    # Type, subtype, lifecycle, and the fields an override rule can turn on. One extra
    # read per document - unavoidable in Lifecycle mode, since the rule that applies is a
    # property of the document, not of the map.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$DocId)
    try {
        $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
                -Path "/objects/documents/$DocId"
        $d = Get-Field $r 'document' $null
        $type    = "$(Get-Field $d 'type__v' '')"
        $subtype = "$(Get-Field $d 'subtype__v' '')"
        # A type with no subtypes configured reports none. Falling back to the type keeps
        # every document in exactly one bucket, which is what the grouping needs.
        if (-not $subtype) { $subtype = $type }

        # Every one of these is multi-value in some vaults and single in others, so read
        # them all as lists. Matching a scalar against a list works either way; the
        # reverse does not.
        $cond = @{}
        foreach ($f in $script:ConditionFields) {
            $cond[$f] = @(@(Get-Field $d $f @()) | ForEach-Object { "$_" } | Where-Object { $_ })
        }

        return [pscustomobject]@{
            Type       = $type
            Subtype    = $subtype
            Lifecycle  = "$(Get-Field $d 'lifecycle__v' '')"
            Conditions = $cond
            Read       = $true
        }
    }
    catch {
        Write-Log "  could not read document ${DocId}: $_" 'WARN'
        $cond = @{}
        foreach ($f in $script:ConditionFields) { $cond[$f] = @() }
        return [pscustomobject]@{ Type = ''; Subtype = ''; Lifecycle = ''; Conditions = $cond; Read = $false }
    }
}

function Get-RoleAssignmentRule {
    # GET /configuration/role_assignment_rule - every lifecycle role's default and
    # override rules, in one call. Indexed by lifecycle and role.
    #
    # This endpoint speaks in NAMES (ally@veepharm.com, global_products_team__c) while the
    # document roles endpoint speaks in ids, so everything is resolved to ids here and the
    # two become comparable. That comparison is the whole point of the probe.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)]$Directory)

    $byKey = @{}
    $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method GET `
            -Path '/configuration/role_assignment_rule'

    $unresolved = New-Object System.Collections.ArrayList

    foreach ($rule in @(Get-Field $r 'data' @())) {
        $lc   = "$(Get-Field $rule 'lifecycle__v' '')"
        $role = "$(Get-Field $rule 'role__v' '')"
        if (-not $lc -or -not $role) { continue }

        # A row carrying product/country/study is an OVERRIDE row; one carrying none is
        # the default. They must never be merged: an override REPLACES the default when
        # its condition is met, so adding them together would invent a rule Vault does not
        # have and hand people access the configuration never granted.
        $conds = @{}
        foreach ($f in $script:ConditionFields) {
            $v = "$(Get-Field $rule $f '')"
            if ($v) { $conds[$f] = $v }
        }

        # allowed_default_* is what Vault ASSIGNS automatically. allowed_* is the wider
        # set a person MAY be added to later, by hand. Only the first is a default, and
        # applying the second would put everyone who could ever be on the document onto
        # every document.
        $users  = New-Object System.Collections.ArrayList
        $groups = New-Object System.Collections.ArrayList
        foreach ($pair in @(@{ Field = 'allowed_default_users__v';  Kind = 'user';  Bag = $users },
                            @{ Field = 'allowed_default_groups__v'; Kind = 'group'; Bag = $groups })) {
            foreach ($n in @(Get-Field $rule $pair.Field @())) {
                $name = "$n"
                if (-not $name) { continue }
                $id = Resolve-NameToId -Directory $Directory -Kind $pair.Kind -Name $name
                if ($id) { [void]$pair.Bag.Add($id) }
                else     { [void]$unresolved.Add("$($pair.Kind) '$name' ($lc / $role)") }
            }
        }

        $key = "$(ConvertTo-NameKey $lc)|$(ConvertTo-NameKey $role)"
        if (-not $byKey.ContainsKey($key)) {
            $byKey[$key] = [pscustomobject]@{
                Lifecycle = $lc; Role = $role
                Users = @(); Groups = @(); HasDefault = $false
                Overrides = (New-Object System.Collections.ArrayList)
            }
        }
        if ($conds.Count) {
            [void]$byKey[$key].Overrides.Add([pscustomobject]@{
                Conditions = $conds; Users = @($users); Groups = @($groups)
            })
        }
        else {
            $byKey[$key].Users      = @($users)
            $byKey[$key].Groups     = @($groups)
            $byKey[$key].HasDefault = $true
        }
    }

    if ($unresolved.Count) {
        # Not fatal - a rule may name a user who has since been deactivated, and that must
        # not stop the other rules being applied. But it is said out loud, because the
        # alternative is a role quietly getting fewer people than the configuration says.
        $show = ($unresolved | Select-Object -Unique | Select-Object -First 5) -join '; '
        Write-Log "$($unresolved.Count) name(s) in the rules match no active user or group and are skipped: $show" 'WARN'
    }

    $overrides = (@($byKey.Values) | ForEach-Object { $_.Overrides.Count } | Measure-Object -Sum).Sum
    Write-Log "$($byKey.Count) lifecycle/role rule(s) from /configuration/role_assignment_rule, $overrides override row(s)" 'OK'
    return $byKey
}

function Select-RuleForDocument {
    # Which row of a lifecycle role's rules applies to THIS document.
    #
    # An override applies when the document carries every value the override names. More
    # than one can match - a product-only rule and a product-and-country rule - and Vault
    # takes the more specific. A tie between two equally specific overrides is not
    # something this can resolve, so it refuses rather than picking one: guessing here
    # means granting access to the wrong people.
    param([Parameter(Mandatory)]$Rule, [Parameter(Mandatory)][hashtable]$Conditions)

    $best = $null; $bestScore = -1; $tied = $false
    foreach ($ov in $Rule.Overrides) {
        $matched = $true
        foreach ($f in $ov.Conditions.Keys) {
            $have = @()
            if ($Conditions.ContainsKey($f)) { $have = @($Conditions[$f]) }
            if ($have -notcontains $ov.Conditions[$f]) { $matched = $false; break }
        }
        if (-not $matched) { continue }
        $score = $ov.Conditions.Count
        if ($score -gt $bestScore) { $best = $ov; $bestScore = $score; $tied = $false }
        elseif ($score -eq $bestScore) { $tied = $true }
    }

    if ($tied) {
        return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'AMBIGUOUS_OVERRIDE'
                                  Message = 'two override rules match this document equally well - Vault must be asked which wins' }
    }
    if ($best) {
        return [pscustomobject]@{ Users = @($best.Users); Groups = @($best.Groups); Which = 'OVERRIDE'
                                  Message = (($best.Conditions.Keys | Sort-Object | ForEach-Object { "$_=$($best.Conditions[$_])" }) -join ', ') }
    }
    if (-not $Rule.HasDefault) {
        return [pscustomobject]@{ Users = @(); Groups = @(); Which = 'NO_DEFAULT_RULE'
                                  Message = 'the role has override rules but no default, and none of the overrides match' }
    }
    return [pscustomobject]@{ Users = @($Rule.Users); Groups = @($Rule.Groups); Which = 'DEFAULT'; Message = '' }
}

function ConvertTo-CsvField {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return '"' + ($Value -replace '"', '""') + '"'
}

function Send-RoleBatch {
    # POST /objects/documents/roles/batch, as CSV.
    #
    # Batched by which COLUMNS a document needs, not just by count. The endpoint takes one
    # header for the whole batch, so mixing documents that need different roles would mean
    # blank cells - and nothing in Vault's documentation says what a blank cell in a
    # role column does. Grouping by shape removes the question rather than betting on it.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Items,
        [Parameter(Mandatory)][string[]]$Columns
    )
    $sb = New-Object Text.StringBuilder
    [void]$sb.AppendLine((@('id') + $Columns | ForEach-Object { ConvertTo-CsvField $_ }) -join ',')
    foreach ($it in $Items) {
        $cells = @(ConvertTo-CsvField $it.DocId)
        foreach ($cn in $Columns) { $cells += ConvertTo-CsvField ($it.Cells[$cn] -join ',') }
        [void]$sb.AppendLine($cells -join ',')
    }

    # Sent as bytes with the charset stated. Windows PowerShell 5.1 will encode a string
    # body as ISO-8859-1 when the content type names no charset, which is the wrong answer
    # for a file the API requires to be UTF-8.
    $bytes = [Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $r = Invoke-Api -VaultHost $Context.VaultHost -ApiVersion $Context.Api -Method POST `
            -Path '/objects/documents/roles/batch' -Body $bytes -ContentType 'text/csv; charset=UTF-8'

    $byDoc = @{}
    foreach ($entry in @(Get-Field $r 'data' @())) {
        $id = "$(Get-Field $entry 'id' '')"
        if (-not $id) { continue }
        $ok = ((Get-Field $entry 'responseStatus' '') -eq 'SUCCESS')
        $msg = ''
        if (-not $ok) {
            $errs = @(Get-Field $entry 'errors' @())
            $msg = (($errs | ForEach-Object { "$(Get-Field $_ 'type'): $(Get-Field $_ 'message')" }) -join '; ')
            if (-not $msg) { $msg = 'Vault reported FAILURE with no message' }
        }
        $byDoc[$id] = [pscustomobject]@{ Ok = $ok; Message = $msg }
    }
    return $byDoc
}

function Invoke-Probe {
    # Read-only. Answers the questions that have to be answered before anything is
    # written, and answers them from the vault rather than from an assumption:
    #
    #   1. Which document types and subtypes does the map actually span?
    #   2. Within a subtype, do all documents report the same defaults? If they do, the
    #      subtype has one rule and a defaults table can be written for it. If they do
    #      not, something is conditional and a flat table would be wrong.
    #   3. Does defaultUsers/defaultGroups carry MORE than the lifecycle's role assignment
    #      rules? If it does, it is also carrying the document type's default security,
    #      and -Defaults is unnecessary. If it matches the lifecycle rules exactly, then
    #      the type defaults are NOT in there and -Defaults is the only way to apply them.
    #
    # It writes the discovered subtype/role/groups table out as a starter defaults file,
    # so the answer to (2) can be checked against the Admin screen side by side.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][array]$Documents)

    $c   = $Context
    $dir = Get-Directory -Context $c

    $rules = @{}
    try { $rules = Get-RoleAssignmentRule -Context $c -Directory $dir }
    catch { Write-Log "Could not read the lifecycle role assignment rules: $_" 'WARN' }

    # Everything handed in, unless -Limit says otherwise. The scope was decided before
    # this function was called; it does not get to second-guess it.
    $docs = $Documents
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-Log "Limit $Limit - surveying the first $Limit of $($docs.Count) document(s)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-Log "$($docs.Count) document(s) to survey - two reads each"

    # subtypeKey -> role name -> what was seen
    $seen    = [ordered]@{}
    $rows    = New-Object System.Collections.ArrayList
    $errors  = 0
    $lifecyclesSeen = @{}
    $beyond  = 0    # roles whose document defaults exceed the lifecycle rule
    $equal   = 0    # roles whose document defaults match the lifecycle rule exactly
    $i = 0

    foreach ($doc in $docs) {
        $i++
        $docId = $doc.TargetId
        $info  = Get-DocumentInfo -Context $c -DocId $docId
        if (-not $info.Subtype) { $errors++; continue }

        try { $roles = @(Get-DocumentRole -Context $c -DocId $docId) }
        catch { Write-Log "[$i/$($docs.Count)] doc $docId - ERROR reading roles: $_" 'ERROR'; $errors++; continue }

        if ($info.Lifecycle) { $lifecyclesSeen[$info.Lifecycle] = $true }
        $sk = ConvertTo-Key $info.Subtype
        if (-not $seen.Contains($sk)) {
            $seen[$sk] = [pscustomobject]@{
                Subtype = $info.Subtype; Type = $info.Type
                Lifecycles = New-Object System.Collections.ArrayList
                Docs = 0
                Roles = [ordered]@{}
            }
        }
        $bucket = $seen[$sk]
        $bucket.Docs++
        if ($info.Lifecycle -and $bucket.Lifecycles -notcontains $info.Lifecycle) { [void]$bucket.Lifecycles.Add($info.Lifecycle) }

        foreach ($r in $roles) {
            $name  = "$(Get-Field $r 'name' '')"
            $label = "$(Get-Field $r 'label' $name)"
            if (-not $name) { continue }

            $defUsers  = @(@(Get-Field $r 'defaultUsers'  @()) | ForEach-Object { "$_" })
            $defGroups = @(@(Get-Field $r 'defaultGroups' @()) | ForEach-Object { "$_" })
            $asgUsers  = @(@(Get-Field $r 'assignedUsers' @()) | ForEach-Object { "$_" })
            $asgGroups = @(@(Get-Field $r 'assignedGroups' @()) | ForEach-Object { "$_" })

            # What the lifecycle's own default rule says, for the same role.
            # The rule that actually applies to THIS document - the matching override if
            # one matches, the default otherwise. Comparing against the default row alone
            # would report a false "beyond the rule" on every document an override covers.
            $ruleUsers = @(); $ruleGroups = @(); $overrides = 0; $haveRule = $false
            $which = ''
            $rk = "$(ConvertTo-NameKey $info.Lifecycle)|$(ConvertTo-NameKey $name)"
            if ($rules.ContainsKey($rk)) {
                $haveRule  = $true
                $overrides = $rules[$rk].Overrides.Count
                $applied   = Select-RuleForDocument -Rule $rules[$rk] -Conditions $info.Conditions
                $ruleUsers  = @($applied.Users)
                $ruleGroups = @($applied.Groups)
                $which      = $applied.Which
            }

            $extraUsers  = @($defUsers  | Where-Object { $ruleUsers  -notcontains $_ })
            $extraGroups = @($defGroups | Where-Object { $ruleGroups -notcontains $_ })
            $verdict = 'NO_RULE'
            if ($haveRule) {
                if ($extraUsers.Count -or $extraGroups.Count) { $verdict = 'BEYOND_LIFECYCLE_RULE'; $beyond++ }
                else { $verdict = 'MATCHES_LIFECYCLE_RULE'; $equal++ }
            }

            $sig = ((@($defUsers | Sort-Object) -join ',') + '/' + (@($defGroups | Sort-Object) -join ','))
            if (-not $bucket.Roles.Contains($name)) {
                $bucket.Roles[$name] = [pscustomobject]@{
                    Label = $label
                    Users = $defUsers; Groups = $defGroups
                    Signature = $sig; Consistent = $true
                }
            }
            elseif ($bucket.Roles[$name].Signature -ne $sig) { $bucket.Roles[$name].Consistent = $false }

            [void]$rows.Add([pscustomobject][ordered]@{
                DocId = $docId; SourceDocId = $doc.SourceId
                Type = $info.Type; Subtype = $info.Subtype; Lifecycle = $info.Lifecycle
                Role = $name; RoleLabel = $label
                AssignedUsers  = ($asgUsers  | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                AssignedGroups = ($asgGroups | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                DefaultUsers   = ($defUsers  | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                DefaultGroups  = ($defGroups | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                LifecycleRuleUsers  = ($ruleUsers  | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                LifecycleRuleGroups = ($ruleGroups | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                OverrideRules = $overrides
                RuleApplied = $which
                Verdict = $verdict
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            })
        }
    }

    $reportPath = Join-Path $c.Out 'probe-report.csv'
    $rows | Export-Csv -LiteralPath $reportPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false

    # The discovered table, in the shape -Defaults reads. Written whether or not the
    # defaults look trustworthy: it is a starting point to check against the screen, not
    # an answer to run unread.
    $defaultsPath = Join-Path $c.Out 'discovered-defaults.csv'
    $out = New-Object System.Collections.ArrayList
    foreach ($sk in $seen.Keys) {
        $b = $seen[$sk]
        foreach ($roleName in $b.Roles.Keys) {
            $r = $b.Roles[$roleName]
            if (-not $r.Users.Count -and -not $r.Groups.Count) { continue }
            [void]$out.Add([pscustomobject][ordered]@{
                subtype = $b.Subtype
                role    = $roleName
                users   = ($r.Users  | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join ','
                groups  = ($r.Groups | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'group' -Id $_ }) -join ','
            })
        }
    }
    if ($out.Count) { $out | Export-Csv -LiteralPath $defaultsPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false }

    Write-Log '----------------------------------------------------------------'
    Write-Log "$($docs.Count) document(s) surveyed, $($seen.Count) subtype(s)"
    foreach ($sk in $seen.Keys) {
        $b = $seen[$sk]
        Write-Log ''
        Write-Log ("  {0}   ({1} document(s), lifecycle {2})" -f $b.Subtype, $b.Docs,
                   $(if ($b.Lifecycles.Count) { $b.Lifecycles -join ' / ' } else { '?' }))
        foreach ($roleName in $b.Roles.Keys) {
            $r = $b.Roles[$roleName]
            $bits = @()
            if ($r.Users.Count)  { $bits += 'users '  + (($r.Users  | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join ', ') }
            if ($r.Groups.Count) { $bits += 'groups ' + (($r.Groups | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'group' -Id $_ }) -join ', ') }
            $what = if ($bits.Count) { $bits -join ' + ' } else { 'no defaults reported' }
            $note = if (-not $r.Consistent) { '   *** documents in this subtype disagree - a flat table would be wrong ***' } else { '' }
            Write-Log ("    {0,-24} {1}{2}" -f $roleName, $what, $note) $(if ($r.Consistent) { 'INFO' } else { 'WARN' })
        }
    }

    Write-Log ''
    Write-Log '----------------------------------------------------------------'
    if (-not $rules.Count) {
        Write-Log 'The lifecycle role assignment rules could not be read, so no verdict on where the defaults come from.' 'WARN'
        Write-Log 'Compare discovered-defaults.csv against Admin > Document Types > Security by hand.' 'WARN'
    }
    elseif ($beyond -gt 0) {
        Write-Log "$beyond role(s) report defaults BEYOND the lifecycle's own rule." 'OK'
        Write-Log 'So defaultUsers/defaultGroups carries more than the lifecycle rules - very likely the'
        Write-Log 'document type default security too. Running without -Defaults should be right; confirm'
        Write-Log 'on a few rows of probe-report.csv, then use -Plan.'
    }
    elseif ($equal -gt 0) {
        Write-Log "Every role's defaults match its lifecycle rule exactly ($equal role(s) compared)." 'WARN'
        Write-Log 'That is the signature of defaultUsers/defaultGroups carrying ONLY the lifecycle rules.'
        Write-Log 'If the Admin screen shows groups that are not in probe-report.csv, they will NOT be'
        Write-Log 'applied without -Defaults. Transcribe the screen, or start from discovered-defaults.csv.' 'WARN'
    }
    else {
        # Rules were read and documents were read, and not one pair joined. Saying nothing
        # here once let a probe look like a clean run while the entire rule lookup was
        # missing - and -DesiredFrom Lifecycle would then have assigned nobody, quietly,
        # after reading every document in the vault.
        Write-Log 'NOT ONE role matched a lifecycle rule, though both were read.' 'ERROR'
        Write-Log "  lifecycles on the documents:  $(($lifecyclesSeen.Keys | Sort-Object) -join ', ')" 'ERROR'
        Write-Log "  lifecycles in the rules:      $((@($rules.Values | ForEach-Object { $_.Lifecycle }) | Select-Object -Unique | Sort-Object) -join ', ')" 'ERROR'
        Write-Log '-DesiredFrom Lifecycle would assign NOTHING. Do not run it until these join.' 'ERROR'
    }
    if ($errors) { Write-Log "$errors document(s) could not be read - the figures above are incomplete" 'ERROR' }
    Write-Log ''
    Write-Log "Report:            $reportPath"
    if ($out.Count) { Write-Log "Starter defaults:  $defaultsPath" }
    return $errors
}

function Invoke-Roles {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][array]$Documents,
        [Parameter(Mandatory)][ValidateSet('Lifecycle', 'Document', 'Table')][string]$From,
        [AllowNull()]$Table,
        [AllowNull()]$Rules
    )

    $c   = $Context
    $dir = Get-Directory -Context $c

    # Lifecycle mode has to read each document: the rule that applies depends on the
    # document's own lifecycle and on the product/country/study an override turns on. A
    # subtype-keyed table needs the same read. Nothing else does, so nothing else pays.
    $needSubtype = ($From -eq 'Table') -and ($null -ne $Table) -and (@($Table | Where-Object { $_.Subtype }).Count -gt 0)
    $needInfo    = ($From -eq 'Lifecycle') -or $needSubtype -or $WithTypeDefaults

    $docs = $Documents
    if ($Limit -gt 0 -and $docs.Count -gt $Limit) {
        Write-Log "Limit $Limit - examining the first $Limit of $($docs.Count) document(s)" 'WARN'
        $docs = @($docs | Select-Object -First $Limit)
    }
    Write-Log "$($docs.Count) document(s) to examine"

    $res = New-Results -Path (Join-Path $c.Out 'role-results.csv')

    $stat = @{ Docs = 0; InStep = 0; NeedWork = 0; Changed = 0; Users = 0; Groups = 0
               Errors = 0; NoRoles = 0; RedundantUsers = 0 }
    $pending = New-Object System.Collections.ArrayList   # documents waiting for a batch
    $i = 0
    $stopped = $false

    function Submit-Pending {
        # Send everything queued, grouped by column shape, and record a row per document
        # and role. Called when a group fills up and once at the end.
        if (-not $pending.Count) { return }

        $groups = @{}
        foreach ($it in $pending) {
            $sig = ($it.Cells.Keys | Sort-Object) -join '|'
            if (-not $groups.ContainsKey($sig)) { $groups[$sig] = New-Object System.Collections.ArrayList }
            [void]$groups[$sig].Add($it)
        }

        foreach ($sig in $groups.Keys) {
            $items   = @($groups[$sig])
            $columns = @($sig -split '\|')
            for ($off = 0; $off -lt $items.Count; $off += $BatchSize) {
                $slice = @($items[$off..([math]::Min($off + $BatchSize - 1, $items.Count - 1))])
                $byDoc = @{}
                $failAll = ''
                try {
                    $byDoc = Send-RoleBatch -Context $c -Items $slice -Columns $columns
                }
                catch {
                    $failAll = "$_"
                    Write-Log "Batch of $($slice.Count) document(s) failed: $_" 'ERROR'
                }

                foreach ($it in $slice) {
                    $ok = $false; $msg = $failAll
                    if (-not $failAll) {
                        if ($byDoc.ContainsKey($it.DocId)) { $ok = $byDoc[$it.DocId].Ok; $msg = $byDoc[$it.DocId].Message }
                        else { $msg = 'Vault returned no result for this document' }
                    }
                    if ($ok) {
                        $stat.Changed++
                        Write-Log "  doc $($it.DocId) - assigned $($it.Summary)" 'OK'
                    }
                    else {
                        $stat.Errors++
                        Write-Log "  doc $($it.DocId) - FAILED: $msg" 'ERROR'
                    }
                    foreach ($row in $it.Rows) {
                        $row.Status  = if ($ok) { 'ASSIGNED' } else { 'ERROR' }
                        $row.Message = $msg
                        [void]$res.Rows.Add($row)
                    }
                }
                Save-Results -Results $res
            }
        }
        $pending.Clear()
    }

    :documents foreach ($doc in $docs) {
        $i++
        $docId  = $doc.TargetId
        $prefix = "[$i/$($docs.Count)] doc $docId"
        $stat.Docs++

        try { $roles = Get-DocumentRole -Context $c -DocId $docId }
        catch {
            Write-Log "$prefix - ERROR reading roles: $_" 'ERROR'
            $stat.Errors++
            # Same column set as every other row. Export-Csv takes its header from the
            # first object it sees, so a row of a different shape silently drops columns
            # from the whole file.
            [void]$res.Rows.Add([pscustomobject][ordered]@{
                Key = "$docId`:-"; DocId = $docId; SourceDocId = $doc.SourceId
                Lifecycle = ''; Role = ''; RoleLabel = ''
                RuleApplied = ''; RuleDetail = ''
                AssignedUsers = ''; AssignedGroups = ''; MissingUsers = ''; MissingGroups = ''
                Status = 'ERROR'; Message = "$_"; CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            })
            Save-Results -Results $res
            continue
        }
        if (-not $roles.Count) {
            $stat.NoRoles++
            Write-Log "$prefix - no roles reported" 'WARN'
            continue
        }

        $info    = if ($needInfo) { Get-DocumentInfo -Context $c -DocId $docId } else { $null }
        $subtype = if ($needSubtype) { ConvertTo-Key $info.Subtype } else { '' }

        $cells   = [ordered]@{}
        $rows    = New-Object System.Collections.ArrayList
        $summary = New-Object System.Collections.ArrayList
        $docNeedsWork = $false

        foreach ($r in $roles) {
            $name  = "$(Get-Field $r 'name' '')"
            $label = "$(Get-Field $r 'label' $name)"
            if (-not $name) { continue }

            $nk = ConvertTo-Key $name; $lk = ConvertTo-Key $label
            if ($Role.Count) {
                $wanted = @($Role | ForEach-Object { ConvertTo-Key $_ })
                if ($wanted -notcontains $nk -and $wanted -notcontains $lk) { continue }
            }
            if ($ExcludeRole.Count) {
                $skip = @($ExcludeRole | ForEach-Object { ConvertTo-Key $_ })
                if ($skip -contains $nk -or $skip -contains $lk) { continue }
            }

            $assignedUsers  = @(@(Get-Field $r 'assignedUsers'  @()) | ForEach-Object { "$_" })
            $assignedGroups = @(@(Get-Field $r 'assignedGroups' @()) | ForEach-Object { "$_" })
            $want = Get-DesiredForRole -From $From -RoleRecord $r -Table $Table -Rules $Rules `
                        -Subtype $subtype -DocumentInfo $info

            # Document type default security is a SECOND source, not an alternative one.
            # The lifecycle rules and the type's "Default Settings for New Documents" are
            # two different screens, both of which the UI applies when it creates a
            # document - so repairing only one of them leaves the job half done.
            if ($WithTypeDefaults -and $info) {
                $td = Get-DocTypeRoleDefault -Context $c -TypeLabel $info.Type `
                          -SubtypeLabel $info.Subtype -Directory $dir
                if ($td.ContainsKey($name)) {
                    $want = [pscustomobject]@{
                        Users   = @(@($want.Users)  + @($td[$name].Users)  | Select-Object -Unique)
                        Groups  = @(@($want.Groups) + @($td[$name].Groups) | Select-Object -Unique)
                        Which   = $(if ($want.Which -in @('NO_RULE_FOR_ROLE', 'NO_RULES', '')) { 'TYPE_DEFAULT' }
                                    else { "$($want.Which)+TYPE_DEFAULT" })
                        Message = $want.Message
                    }
                }
            }

            $missingUsers  = @($want.Users  | Where-Object { $assignedUsers  -notcontains $_ } | Select-Object -Unique)
            $missingGroups = @($want.Groups | Where-Object { $assignedGroups -notcontains $_ } | Select-Object -Unique)

            # How many of those direct user assignments are just the membership of the
            # groups going on at the same time. A direct assignment outlives the group -
            # take someone out of the group and they keep the access - so writing hundreds
            # of thousands of them by accident is a mess that is hard to unpick later.
            $stat.RedundantUsers += (Get-RedundantUserCount -Directory $dir -Groups $want.Groups -Users $missingUsers)

            if ($Assign -eq 'Groups') { $missingUsers  = @() }
            if ($Assign -eq 'Users')  { $missingGroups = @() }

            $row = [pscustomobject][ordered]@{
                Key = "$docId`:$name"; DocId = $docId; SourceDocId = $doc.SourceId
                Lifecycle = $(if ($info) { $info.Lifecycle } else { '' })
                Role = $name; RoleLabel = $label
                RuleApplied = $want.Which; RuleDetail = $want.Message
                AssignedUsers  = ($assignedUsers  | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                AssignedGroups = ($assignedGroups | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                MissingUsers   = ($missingUsers   | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'user'  -Id $_ }) -join '; '
                MissingGroups  = ($missingGroups  | ForEach-Object { Get-DisplayName -Directory $dir -Kind 'group' -Id $_ }) -join '; '
                Status = ''; Message = ''
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            }

            # A role whose rule could not be chosen is NOT the same as a role with nothing
            # to do, and must not be reported as in step. Nothing is written for it, and
            # it is counted as an error so the run's exit code is non-zero and the summary
            # says the figures are incomplete.
            if ($want.Which -in @('AMBIGUOUS_OVERRIDE', 'DOCUMENT_UNREADABLE', 'NO_LIFECYCLE', 'NO_DEFAULT_RULE')) {
                $row.Status  = 'UNRESOLVED'
                $row.Message = $want.Message
                $stat.Errors++
                Write-Log "$prefix  $name  - $($want.Which): $($want.Message)" 'ERROR'
                [void]$res.Rows.Add($row)
                continue
            }

            if (-not $missingUsers.Count -and -not $missingGroups.Count) {
                $row.Status = 'IN_STEP'
                [void]$res.Rows.Add($row)
                continue
            }

            $docNeedsWork = $true
            $stat.Users  += $missingUsers.Count
            $stat.Groups += $missingGroups.Count

            $parts = @()
            if ($missingUsers.Count)  { $parts += "users $($row.MissingUsers)" }
            if ($missingGroups.Count) { $parts += "groups $($row.MissingGroups)" }
            [void]$summary.Add("$label ($($parts -join ', '))")
            Write-Log "$prefix  $name  + $($parts -join ' + ')"

            if ($missingUsers.Count)  { $cells["$name.users"]  = $missingUsers }
            if ($missingGroups.Count) { $cells["$name.groups"] = $missingGroups }

            $row.Status = if ($Plan) { 'WOULD_ASSIGN' } elseif ($c.WhatIf) { 'WHATIF' } else { 'PENDING' }
            [void]$rows.Add($row)
        }

        if (-not $docNeedsWork) {
            $stat.InStep++
            Save-Results -Results $res
            continue
        }
        $stat.NeedWork++

        if ($Plan -or $c.WhatIf) {
            foreach ($row in $rows) { [void]$res.Rows.Add($row) }
            Save-Results -Results $res
        }
        else {
            [void]$pending.Add([pscustomobject]@{
                DocId = $docId; Cells = $cells; Rows = @($rows); Summary = ($summary -join '; ')
            })
            if ($pending.Count -ge $BatchSize) { Submit-Pending }
        }

        if ($Test -gt 0) {
            $done = if ($Plan -or $c.WhatIf) { $stat.NeedWork } else { $stat.Changed + $pending.Count }
            if ($done -ge $Test) {
                Write-Log "TEST: $done document(s) after examining $i - stopping" 'OK'
                $stopped = $true
                break documents
            }
        }
    }

    Submit-Pending
    Save-Results -Results $res

    Write-Log '----------------------------------------------------------------'
    Write-Log ("examined {0}   already in step {1}   needing work {2}   no roles {3}" -f `
               $stat.Docs, $stat.InStep, $stat.NeedWork, $stat.NoRoles)
    if ($Plan -or $c.WhatIf) {
        $what = if ($Plan) { 'PLAN' } else { 'WhatIf' }
        Write-Log "$what only - nothing was assigned. $($stat.Users) user and $($stat.Groups) group assignment(s) would be." 'OK'
        if ($stat.RedundantUsers -gt 0 -and $Assign -ne 'Groups') {
            Write-Log ''
            Write-Log "$($stat.RedundantUsers) of those $($stat.Users) user assignment(s) are people who are ALREADY" 'WARN'
            Write-Log 'members of a group being assigned on the same document. Assigning them directly as' 'WARN'
            Write-Log 'well outlives the group - take someone out of the group later and they keep the' 'WARN'
            Write-Log 'access, because the direct assignment is still there. -Assign Groups writes only the' 'WARN'
            Write-Log 'groups and leaves membership to do its job.' 'WARN'
        }
        # Errors are reported in every mode. A plan that could not read half the documents
        # is not a plan, and saying only "0 would be assigned" reads as good news rather
        # than as a run that never got off the ground.
        if ($stat.Errors) { Write-Log "$($stat.Errors) document(s) could not be read - the figures above are incomplete" 'ERROR' }
    }
    else {
        Write-Log ("Assigned on {0} document(s): {1} user and {2} group assignment(s). {3} failed." -f `
                   $stat.Changed, $stat.Users, $stat.Groups, $stat.Errors) $(if ($stat.Errors) { 'WARN' } else { 'OK' })
    }
    if ($stopped) { Write-Log "TEST run - stopped after $i of $($docs.Count) document(s). NOT the whole set." 'WARN' }
    Write-Log "Results: $($res.Path)"
    return $stat.Errors
}


# ======================================================================================
#  Run
# ======================================================================================

$exitCode = 0
try {
    # Before anything else, including the prompts: the whole point of -Version is to
    # answer "which copy of this file am I holding" without a vault or a login.
    if ($Version) { Write-Host $ScriptVersion; exit 0 }

    if ($Logout) {
        if (Clear-Sessions) { Write-Host "Deleted $(Get-SessionPath)" }
        else                { Write-Host 'No session file to delete.' }
        exit 0
    }

    if ($Map -and $Where) {
        throw '-Map and -Where both name the documents to repair. Pass one.'
    }

    $ctx = Resolve-Settings

    $mode = if ($Probe) { 'probe' } elseif ($Plan) { 'plan' } else { 'assign' }
    Write-Log "veeva-roles $ScriptVersion - $mode"
    Write-Log "  vault    $($ctx.VaultHost)"
    Write-Log "  api      $($ctx.Api)"
    Write-Log "  output   $($ctx.Out)"
    if ($ctx.WhatIf) { Write-Log '  -WhatIf: nothing will be written to Vault' 'WARN' }

    # Log in up front, and PROVE a cached session rather than assuming it. Failing here
    # costs seconds; failing an hour in costs the hour.
    [void](Get-SessionId -VaultHost $ctx.VaultHost -ApiVersion $ctx.Api)
    Test-Session -VaultHost $ctx.VaultHost -ApiVersion $ctx.Api

    # Scope is capped only where THIS SCRIPT guessed it, never where it was given. A probe
    # over a named scope surveys all of it: a survey that looked at twenty-five of 577
    # documents can miss a subtype entirely and then report that everything is consistent,
    # which is worse than not having run it. -Limit still cuts it down on request.
    $documents =
        if ($ctx.MapPath) { Import-TargetIds -Path $ctx.MapPath }
        elseif ($Where)   { Get-DocumentsByQuery -Context $ctx -Where $Where }
        elseif ($Probe)   {
            # Bare -Probe named no scope, so the script picks one - and that is the one
            # case where a cap is honest. Arbitrary order, said out loud: a subtype that
            # does not appear in the first 200 has not been ruled out.
            Write-Log 'No -Map or -Where given, so sampling the vault in whatever order it returns.'
            Write-Log 'This can miss a subtype entirely. Pass -Map or -Where to survey a real scope.' 'WARN'
            Get-DocumentsByQuery -Context $ctx -Where '' -Stop $(if ($Limit -gt 0) { $Limit } else { 200 })
        }
        else {
            # Assign and plan never default to "the whole vault". A probe writes nothing,
            # so guessing its scope costs an operator some time; guessing the scope of a
            # run that grants people access costs a great deal more.
            throw 'No documents named. Pass -Map <csv> or -Where "<VQL condition>".'
        }

    if ($Probe) {
        $exitCode = Invoke-Probe -Context $ctx -Documents $documents
    }
    else {
        # -Defaults names a table, so it settles the question on its own. Saying both
        # -Defaults and -DesiredFrom something else is a contradiction, not a preference.
        $from = $DesiredFrom
        if ($Defaults) {
            if ($PSBoundParameters.ContainsKey('DesiredFrom') -and $DesiredFrom -ne 'Table') {
                throw "-Defaults and -DesiredFrom $DesiredFrom contradict each other. Drop one."
            }
            $from = 'Table'
        }
        elseif ($from -eq 'Table') {
            throw '-DesiredFrom Table needs -Defaults to say which table.'
        }

        $table = $null
        $rules = $null
        switch ($from) {
            'Table' {
                $table = Import-DefaultsTable -Path $Defaults -Directory (Get-Directory -Context $ctx)
                Write-Log 'Desired state: the -Defaults table.'
            }
            'Lifecycle' {
                $rules = Get-RoleAssignmentRule -Context $ctx -Directory (Get-Directory -Context $ctx)
                Write-Log "Desired state: each document's lifecycle role assignment rules."
                if (-not $rules.Count) {
                    throw 'No lifecycle role assignment rules were returned, so there is nothing to apply. Check the account can read Admin configuration, or use -DesiredFrom Document.'
                }
            }
            default {
                Write-Log 'Desired state: the defaultUsers and defaultGroups Vault reports per document.'
                Write-Log 'Run -Probe if you have not - it says whether those carry the type defaults too.' 'WARN'
            }
        }

        $exitCode = Invoke-Roles -Context $ctx -Documents $documents -From $from -Table $table -Rules $rules
    }
    Write-Log "Log: $($script:LogFile)"
}
catch {
    Write-Log "$_" 'ERROR'
    $exitCode = 1
}
finally {
    # The password never touches disk. The SESSION does, on purpose, so the next run does
    # not stop to ask - so it is deliberately left alone here. -Logout removes it.
    $script:Cred = $null
}

exit $exitCode
