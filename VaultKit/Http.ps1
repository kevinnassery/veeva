# One HTTP layer for every command.
#
# Written once here because it had been written three times before, and the copies had
# drifted: one still caught only System.Net.WebException, which is a .NET Framework type,
# so on PowerShell 7 it had no retry and no 429 handling at all.

# What Vault last said was left of the burst allowance, per host. Kept because the
# decision "should this run use more workers" is answerable from it and guesswork
# otherwise: the documented limit is 2,000 calls per five minutes per user, and a run
# that never drops below a few hundred remaining has headroom while one that keeps
# bottoming out is already being throttled and would only thrash with more workers.
$script:VaultBurstRemaining = @{}
$script:VaultBurstLowest    = @{}

function Get-VaultBurstReport {
    # A line per vault, or nothing if no response ever carried the header.
    $out = New-Object System.Collections.ArrayList
    foreach ($h in ($script:VaultBurstRemaining.Keys | Sort-Object)) {
        [void]$out.Add(('{0}  burst remaining {1}, lowest seen {2} of 2000 per 5 min' -f `
                        $h, $script:VaultBurstRemaining[$h], $script:VaultBurstLowest[$h]))
    }
    return @($out)
}

function Register-VaultBurstLimit {
    # Record what a response said was left of the allowance, and ease off if it is low.
    #
    # A function rather than a few lines inside Invoke-VaultApi, because not every call
    # goes through Invoke-VaultApi: the attachment upload builds its own HttpWebRequest
    # so a 2GB body can stream from disk, and while it recorded nothing the end-of-run
    # "lowest seen" was blind to the calls the workers spend their time in - so the one
    # number that answers "should this run use more workers" was reading only the cheap
    # listing calls beside them.
    #
    # The value arrives as whatever the response type hands back: a string from
    # WebHeaderCollection on 5.1, a single-element string[] from Invoke-WebRequest on 7.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [AllowNull()][AllowEmptyString()]$HeaderValue
    )
    if ($null -eq $HeaderValue) { return }
    $val = "$(@($HeaderValue)[0])".Trim()
    if ($val -notmatch '^\d+$') { return }
    $n = [int]$val

    $script:VaultBurstRemaining[$VaultHost] = $n
    if (-not $script:VaultBurstLowest.ContainsKey($VaultHost) -or
        $n -lt $script:VaultBurstLowest[$VaultHost]) {
        $script:VaultBurstLowest[$VaultHost] = $n
    }

    # Eased off from 400 rather than stopped dead at 200: the allowance is 2,000 every
    # five minutes, and a run that keeps reaching the floor is one already being delayed
    # 500ms a call by Vault - which looks like slowness, not like throttling, and is the
    # failure this is meant to stay ahead of.
    if ($n -lt 400) {
        $wait = Get-VaultThrottleDelay -Kind 'burst' -Remaining $n
        Write-VaultLog "$VaultHost burst allowance low ($n of 2000) - easing off ${wait}s" 'WARN'
        Start-Sleep -Seconds $wait
    }
}

# --------------------------------------------------------------------------------------
# Backing off without thrashing
#
# Eight workers that all pause for exactly sixty seconds resume in the same instant and
# hit the vault together, which is the behaviour that turns "throttled" into "thrashing".
# Every wait here is therefore jittered: the point is not the length of the pause, it is
# that the workers stop agreeing on when it ends.
# --------------------------------------------------------------------------------------

$script:VaultJitter = New-Object System.Random

function Get-VaultThrottleDelay {
    # Seconds to wait, jittered. Returns a whole number so it can be logged plainly.
    param(
        [Parameter(Mandatory)][ValidateSet('burst', 'throttled', 'transient')][string]$Kind,
        [int]$Attempt = 1,
        [int]$Remaining = -1,
        [int]$RetryAfter = 0,
        [int]$Cap = 120
    )
    # Vault said how long: that is an instruction, not an opinion. Jitter still applies,
    # because the workers must not resume together - but upward only. Waiting LESS than
    # you were told is the one direction that cannot help.
    if ($RetryAfter -gt 0) {
        $up = [int][math]::Ceiling($RetryAfter * (1.0 + $script:VaultJitter.NextDouble() * 0.5))
        return [math]::Min([math]::Max($up, $RetryAfter), [math]::Max($Cap, $RetryAfter))
    }

    $base =
        if ($false) { 0 }
        else {
            switch ($Kind) {
                'burst' {
                    # Proportional to how little is left, not a cliff at one value. The
                    # allowance is 2,000 per five minutes; easing off from 400 remaining
                    # keeps a run away from the floor instead of pausing hard once it is
                    # already there.
                    $r = if ($Remaining -lt 0) { 0 } else { [math]::Min(400, $Remaining) }
                    [math]::Max(3, [int](3 + (400 - $r) / 400.0 * 45))
                }
                'throttled' { 60 }
                default     { [math]::Min($Cap, [int]([math]::Pow(2, $Attempt) * 5)) }
            }
        }
    if ($base -gt $Cap) { $base = $Cap }

    # Half to one and a half times the base. Not full jitter down to zero: a wait of
    # nothing is not a wait, and the reason for pausing has not gone away.
    $factor = 0.5 + $script:VaultJitter.NextDouble()
    $delay  = [int][math]::Round($base * $factor)
    if ($delay -lt 1) { $delay = 1 }
    return $delay
}

function Get-VaultRetryAfter {
    # Vault's own answer, when it gives one.
    param($Response)
    try {
        $v = $Response.Headers['Retry-After']
        if ($v -and ($v -match '^\d+$')) { return [int]$v }
    } catch { }
    return 0
}

function Invoke-VaultApi {
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        $Body,
        [string]$ContentType,
        [hashtable]$ExtraHeaders = @{},
        [int]$TimeoutSec = 900,
        [int]$MaxRetries = 4
    )

    # Three shapes of Path arrive here and they are not interchangeable:
    #   https://...       a full URL, which File Staging pagination returns
    #   /api/v26.2/query  host-relative and ALREADY carrying the api prefix, which VQL
    #                     next_page returns - prefixing again gives /api/v26.2/api/v26.2
    #   /objects/...      our own calls, relative to the versioned base
    $uri =
        if     ($Path -match '^https?://') { $Path }
        elseif ($Path -match '^/api/')     { "https://$VaultHost$Path" }
        else                               { "https://$VaultHost/api/$ApiVersion$Path" }

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sid = Get-VaultSessionId -VaultHost $VaultHost -ApiVersion $ApiVersion
        $headers = @{ Authorization = $sid; Accept = 'application/json' }
        foreach ($k in $ExtraHeaders.Keys) { $headers[$k] = $ExtraHeaders[$k] }

        try {
            $req = @{ Method = $Method; Uri = $uri; Headers = $headers
                      TimeoutSec = $TimeoutSec; UseBasicParsing = $true }
            if ($null -ne $Body) { $req['Body'] = $Body }
            if ($ContentType)    { $req['ContentType'] = $ContentType }

            $resp = Invoke-WebRequest @req

            Register-VaultBurstLimit -VaultHost $VaultHost `
                -HeaderValue $resp.Headers['X-VaultAPI-BurstLimitRemaining']

            $json = $null
            if ($resp.Content) { try { $json = $resp.Content | ConvertFrom-Json } catch { } }
            if ($null -eq $json) { return [pscustomobject]@{ responseStatus = 'SUCCESS'; raw = $resp.Content } }

            if ((Get-VaultField $json 'responseStatus') -eq 'FAILURE') {
                $errs  = @(Get-VaultField $json 'errors' @())
                $types = @($errs | ForEach-Object { Get-VaultField $_ 'type' })
                if ($types -contains 'INVALID_SESSION_ID') {
                    [void](Reset-VaultSession -VaultHost $VaultHost -ApiVersion $ApiVersion)
                    continue
                }
                throw "$VaultHost $Method $Path -- " +
                      (($errs | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join '; ')
            }
            return $json
        }
        catch {
            # 5.1 raises WebException; 7 raises HttpResponseException for a status and
            # HttpRequestException for a transport failure. Matching on the type NAME
            # covers all three without needing System.Net.Http loadable on 5.1. Anything
            # else is a bug in this code and is rethrown rather than retried four times.
            $ex   = $_.Exception
            $name = $ex.GetType().Name
            if ($name -notin @('WebException', 'HttpResponseException', 'HttpRequestException')) { throw }

            $status = $null
            try { if ($ex.Response) { $status = [int]$ex.Response.StatusCode } } catch { }

            if ($status -eq 401 -and $attempt -lt $MaxRetries) {
                # A raw 401 carries no JSON body, so the INVALID_SESSION_ID handling
                # above never sees it - that only fires when Vault answers 200 with a
                # FAILURE payload. Without this a session expiring mid-run fails every
                # remaining call instead of renewing once.
                Write-VaultLog "$VaultHost HTTP 401 - renewing the session" 'WARN'
                [void](Reset-VaultSession -VaultHost $VaultHost -ApiVersion $ApiVersion)
                continue
            }
            if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                $wait = Get-VaultThrottleDelay -Kind 'throttled' -Attempt $attempt -RetryAfter (Get-VaultRetryAfter $ex.Response)
                Write-VaultLog "$VaultHost HTTP 429 - waiting ${wait}s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = Get-VaultThrottleDelay -Kind 'transient' -Attempt $attempt -RetryAfter (Get-VaultRetryAfter $ex.Response)
                Write-VaultLog "$VaultHost transient error on $Method $Path (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
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

function Invoke-VaultQuery {
    # One VQL query, all its pages, as rows.
    #
    # Page 1 is a POST carrying the query; every page after it is a GET on the URL Vault
    # hands back, which already has the query baked in. That asymmetry has been written
    # out by hand in four places in this kit; this is the one that new code should use.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][string]$Vql,
        # A cap, not a limit: pages, not rows. Stops a mistyped query from paging a
        # 500,000-record object to the end, and says that it stopped.
        [int]$MaxPages = 50
    )
    $rows  = New-Object System.Collections.ArrayList
    $path  = '/query'
    $body  = "q=$([Uri]::EscapeDataString($Vql))"
    $pages = 0
    $truncated = $false
    while ($path) {
        $pages++
        if ($pages -gt $MaxPages) { $truncated = $true; break }
        $r = if ($pages -eq 1) {
                Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method POST `
                    -Path $path -ContentType 'application/x-www-form-urlencoded' -Body $body
             } else {
                Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET -Path $path
             }
        foreach ($row in @(Get-VaultField $r 'data' @())) { [void]$rows.Add($row) }
        $path = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }
    if ($truncated) { Write-VaultLog "Stopped at the $MaxPages-page cap - this is NOT the whole result." 'WARN' }
    return @($rows)
}

function Get-VaultAttachmentName {
    # The filename out of a Content-Disposition header, decoded properly.
    #
    # Two traps, both of which produce a wrong name rather than an error:
    #
    # RFC 5987 puts the reliable value in filename*, percent-encoded and tagged with its
    # charset, and servers send a plain ASCII-mangled filename beside it for old clients.
    # A regex that takes whichever comes first takes the mangled one.
    #
    # .NET decodes header bytes as latin-1. A UTF-8 name therefore arrives as mojibake -
    # an e-acute comes back as two characters - and it is a valid string, so nothing
    # complains. Re-reading those bytes as UTF-8 recovers it; if that fails, the name was
    # genuinely latin-1 and is kept as it was.
    #
    # This file stays ASCII. Windows PowerShell 5.1 reads a .ps1 with no BOM as ANSI, so
    # a non-ASCII character here - even in a comment - is not the character that was
    # written.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Header)
    if (-not $Header) { return '' }

    if ($Header -match "filename\*\s*=\s*(?:UTF-8|utf-8)''([^;]+)") {
        try { return [Uri]::UnescapeDataString($Matches[1].Trim()) } catch { }
    }
    if ($Header -match 'filename\s*=\s*"?([^";]+)"?') {
        $raw = $Matches[1].Trim().Trim('"')
        try {
            $bytes = [Text.Encoding]::GetEncoding(28591).GetBytes($raw)   # latin-1, as .NET read it
            $utf8  = [Text.Encoding]::UTF8.GetString($bytes)
            if ($utf8 -and ($utf8 -notmatch [char]0xFFFD)) { return $utf8 }
        }
        catch { }
        return $raw
    }
    return ''
}

function Save-VaultFile {
    # Streamed to disk via HttpWebRequest. Invoke-WebRequest -OutFile buffers the whole
    # response on Windows PowerShell 5.1, which a 2GB attachment would not survive.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Destination,
        [string]$FileName
    )
    $sid = Get-VaultSessionId -VaultHost $VaultHost -ApiVersion $ApiVersion
    $uri = if ($Path -match '^https?://') { $Path } else { "https://$VaultHost/api/$ApiVersion$Path" }

    $req = [Net.HttpWebRequest]::Create($uri)
    $req.Method           = 'GET'
    $req.Timeout          = 900000
    $req.ReadWriteTimeout = 900000
    $req.Headers.Add('Authorization', $sid)

    $resp = $req.GetResponse()
    try {
        $name = $FileName
        if (-not $name) { $name = Get-VaultAttachmentName -Header "$($resp.Headers['Content-Disposition'])" }
        if (-not $name) { $name = 'download' }

        # Scrub for the local filesystem only. Whatever goes back OUT to Vault must use
        # the original name: uploading under a scrubbed name means the names stop
        # matching, so the next run judges the file missing and sends another copy.
        $safe = $name
        foreach ($bad in [IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace($bad, '_') }

        $out = Join-Path $Destination $safe
        $in  = $resp.GetResponseStream()
        $fs  = [IO.File]::Create($out)
        try {
            $buf = New-Object byte[] 1048576
            while (($read = $in.Read($buf, 0, $buf.Length)) -gt 0) { $fs.Write($buf, 0, $read) }
        }
        finally { $fs.Dispose(); $in.Dispose() }

        return [pscustomobject]@{
            Path         = $out
            Name         = $safe          # on disk
            OriginalName = $name          # on the wire
            Size         = (Get-Item -LiteralPath $out).Length
        }
    }
    finally { $resp.Dispose() }
}
