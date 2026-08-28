# One HTTP layer for every command.
#
# Written once here because it had been written three times before, and the copies had
# drifted: one still caught only System.Net.WebException, which is a .NET Framework type,
# so on PowerShell 7 it had no retry and no 429 handling at all.

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

            $remaining = $resp.Headers['X-VaultAPI-BurstLimitRemaining']
            if ($remaining -and [int]$remaining -lt 200) {
                Write-VaultLog "$VaultHost burst limit low ($remaining) - pausing 30s" 'WARN'
                Start-Sleep -Seconds 30
            }

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

            if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                Write-VaultLog "$VaultHost HTTP 429 - waiting 60s (attempt $attempt/$MaxRetries)" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = [math]::Pow(2, $attempt) * 5
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
        if (-not $name) {
            $cd = $resp.Headers['Content-Disposition']
            if ($cd -and $cd -match 'filename\*?=(?:UTF-8'''')?"?([^";]+)"?') {
                $name = [Uri]::UnescapeDataString($Matches[1]).Trim('"')
            }
        }
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
