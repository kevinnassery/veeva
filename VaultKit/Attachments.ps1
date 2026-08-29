# Document attachments: reconcile one vault against another, and prove the result.
#
# Both commands compare before acting, which is what makes them safe to run repeatedly.
# A document already in step costs two listing calls and nothing else.

function Get-VaultDocumentAttachment {
    # Every attachment on the latest version of a document, from either vault. The
    # listing carries name, size and MD5, so both the comparison and the size projection
    # come free - no file has to be fetched to find out what is there.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][string]$DocId
    )
    $r = Invoke-VaultApi -VaultHost $VaultHost -ApiVersion $ApiVersion -Method GET `
            -Path "/objects/documents/$DocId/attachments"
    $out = New-Object System.Collections.ArrayList
    foreach ($a in @(Get-VaultField $r 'data' @())) {
        $aid = "$(Get-VaultField $a 'id' '')"
        if (-not $aid) { continue }
        [void]$out.Add([pscustomobject]@{
            Id       = $aid
            Name     = "$(Get-VaultField $a 'filename__v' "attachment-$aid")"
            Size     = [long]"$(Get-VaultField $a 'size__v' 0)"
            Version  = "$(Get-VaultField $a 'version__v' '')"
            Checksum = "$(Get-VaultField $a 'md5checksum__v' '')"
        })
    }
    return $out
}

function Send-VaultDocumentAttachment {
    # Upload straight onto the target document - no File Staging anywhere.
    #
    # POST /objects/documents/{id}/attachments takes the file as multipart/form-data, up
    # to 2GB, and attaches it in the same call. That replaces open a resumable session,
    # create each folder level, upload parts, commit, then a separate bulk attach - five
    # steps, of which the folder step failed every upload the first time it ran.
    #
    # HttpWebRequest with buffering off so the body streams from disk: a 2GB attachment
    # must never be assembled in memory. PowerShell 5.1 has no -Form, so the multipart
    # envelope is built by hand.
    param(
        [Parameter(Mandatory)][string]$VaultHost,
        [Parameter(Mandatory)][string]$ApiVersion,
        [Parameter(Mandatory)][string]$DocId,
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$FileName,
        [int]$MaxRetries = 4
    )
    $fileLen = (Get-Item -LiteralPath $LocalPath).Length

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sid      = Get-VaultSessionId -VaultHost $VaultHost -ApiVersion $ApiVersion
        $boundary = '----VaultKit' + [guid]::NewGuid().ToString('N')
        $pre  = "--$boundary`r`n" +
                "Content-Disposition: form-data; name=`"file`"; filename=`"$FileName`"`r`n" +
                "Content-Type: application/octet-stream`r`n`r`n"
        $post = "`r`n--$boundary--`r`n"
        $preB  = [Text.Encoding]::UTF8.GetBytes($pre)
        $postB = [Text.Encoding]::UTF8.GetBytes($post)

        $req = [Net.HttpWebRequest]::Create("https://$VaultHost/api/$ApiVersion/objects/documents/$DocId/attachments")
        $req.Method                    = 'POST'
        $req.ContentType               = "multipart/form-data; boundary=$boundary"
        $req.ContentLength             = $preB.Length + $fileLen + $postB.Length
        $req.AllowWriteStreamBuffering = $false
        $req.Timeout                   = 900000
        $req.ReadWriteTimeout          = 900000
        # Accept is a RESTRICTED header: Headers.Add throws on .NET Framework with "The
        # 'Accept' header must be modified using the appropriate property or method".
        $req.Accept = 'application/json'
        $req.Headers.Add('Authorization', $sid)

        try {
            $rs = $req.GetRequestStream()
            try {
                $rs.Write($preB, 0, $preB.Length)
                $fs = [IO.File]::OpenRead($LocalPath)
                try {
                    $buf = New-Object byte[] 1048576
                    while (($read = $fs.Read($buf, 0, $buf.Length)) -gt 0) { $rs.Write($buf, 0, $read) }
                }
                finally { $fs.Dispose() }
                $rs.Write($postB, 0, $postB.Length)
            }
            finally { $rs.Dispose() }

            $resp = $req.GetResponse()
            try {
                $sr = New-Object IO.StreamReader($resp.GetResponseStream())
                $body = $sr.ReadToEnd(); $sr.Dispose()
                $json = $null
                try { $json = $body | ConvertFrom-Json } catch { }
                if ($null -eq $json) { throw "attachment upload returned no JSON: $body" }
                if ((Get-VaultField $json 'responseStatus') -ne 'SUCCESS') {
                    $errs = @(Get-VaultField $json 'errors' @())
                    throw (($errs | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join '; ')
                }
                $d = Get-VaultField $json 'data' $null
                return [pscustomobject]@{
                    AttachmentId = "$(Get-VaultField $d 'id' '')"
                    Version      = "$(Get-VaultField $d 'version__v' (Get-VaultField $d 'version' ''))"
                }
            }
            finally { $resp.Dispose() }
        }
        catch [Net.WebException] {
            $status = $null
            try { if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode } } catch { }
            $detail = ''
            try {
                $er = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $er.ReadToEnd(); $er.Dispose()
            } catch { }

            if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                Write-VaultLog "HTTP 429 attaching $FileName - waiting 60s" 'WARN'
                Start-Sleep -Seconds 60; continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = [math]::Pow(2, $attempt) * 5
                Write-VaultLog "Transient error attaching $FileName (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait; continue
            }
            throw "attach failed (HTTP $status): $($_.Exception.Message) $detail"
        }
    }
    throw "attach of $FileName failed after $MaxRetries attempts"
}

function Compare-VaultAttachmentSet {
    # Match by filename, because that is Vault's own rule: posting a name that already
    # exists on a document creates a new VERSION of that attachment, not a second one.
    # Matching on anything looser would silently produce version churn.
    param([Parameter(Mandatory)][AllowEmptyCollection()][array]$Target)
    $byName = @{}
    foreach ($t in $Target) { $byName[$t.Name.ToLowerInvariant()] = $t }
    return $byName
}

function Invoke-VaultAttachmentsSync {
    param(
        [Parameter(Mandatory)]$Context,
        [switch]$Plan,
        [switch]$ReplaceDiffering,
        [int]$TestCount = 0,
        [int]$Limit = 0
    )
    $c   = $Context
    $map = $c.Map
    $ids = @($map.Keys)
    if ($Limit -gt 0 -and $ids.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - examining the first $Limit of $($ids.Count) mapped document(s)" 'WARN'
        $ids = @($ids | Select-Object -First $Limit)
    }
    Write-VaultLog "$($ids.Count) mapped document(s) to examine"

    # Sharded by DOCUMENT, because that is what the map keys are and what a worker can be
    # handed. The rows it produces are per attachment, which is why the supervisor is
    # told not to treat one as the other.
    if ($c.Workers -gt 1 -and $ids.Count -gt 1 -and $TestCount -le 0 -and -not ($Plan -or $c.WhatIf)) {
        $pairs = @($ids | ForEach-Object { [pscustomobject]@{ Source = $_; Target = $map[$_] } })
        $extra = @()
        if ($ReplaceDiffering) { $extra += '-ReplaceDiffering' }
        return Invoke-VaultShardedRun -Context $c -Pending $pairs -Workers $c.Workers `
                   -Command @('attachments', 'sync') -LogPattern 'attachments-sync-*.log' `
                   -ResultsName 'attachment-results.csv' -KeyColumn 'Key' `
                   -SuccessStatus 'ATTACHED' -Verb 'Attached' -ShardKind 'map' `
                   -RowsAreItems $false -ExtraArgs $extra
    }

    $res = New-VaultResults -Path (Join-Path $c.Out 'attachment-results.csv') -KeyColumn 'Key' `
              -DoneStatuses @('ATTACHED') -Existing $c.Existing

    $stat = @{ Src = 0; Present = 0; Missing = 0; Differs = 0; Attached = 0; NoAtt = 0; Errors = 0 }
    $moved = [long]0
    $i = 0
    $stopped = $false

    :documents foreach ($srcId in $ids) {
        $i++
        $tgtId  = $map[$srcId]
        $prefix = "[$i/$($ids.Count)] $srcId -> $tgtId"

        try { $srcAtt = @(Get-VaultDocumentAttachment -VaultHost $c.SourceHost -ApiVersion $c.Api -DocId $srcId) }
        catch { Write-VaultLog "$prefix - ERROR listing source: $_" 'ERROR'; $stat.Errors++; continue }
        if ($srcAtt.Count -eq 0) { $stat.NoAtt++; continue }
        $stat.Src += $srcAtt.Count

        try { $tgtAtt = @(Get-VaultDocumentAttachment -VaultHost $c.TargetHost -ApiVersion $c.Api -DocId $tgtId) }
        catch { Write-VaultLog "$prefix - ERROR listing target: $_" 'ERROR'; $stat.Errors++; continue }
        $byName = Compare-VaultAttachmentSet -Target $tgtAtt

        foreach ($att in $srcAtt) {
            $key   = "$srcId`:$($att.Id)"
            $lname = $att.Name.ToLowerInvariant()
            $have  = if ($byName.ContainsKey($lname)) { $byName[$lname] } else { $null }

            $state = 'MISSING'
            if ($have) {
                $state = 'PRESENT'
                if ($att.Checksum -and $have.Checksum -and $att.Checksum -ne $have.Checksum) { $state = 'DIFFERS' }
            }
            switch ($state) {
                'PRESENT' { $stat.Present++ }
                'DIFFERS' { $stat.Differs++ }
                default   { $stat.Missing++ }
            }
            if ($res.Done.ContainsKey($key)) { continue }

            $row = [pscustomobject][ordered]@{
                Key = $key; SourceDocId = $srcId; TargetDocId = $tgtId
                AttachmentId = $att.Id; Name = $att.Name; SizeBytes = $att.Size
                Version = $att.Version; Checksum = $att.Checksum
                Status = $state; Message = ''
                StartedUtc = (Get-Date).ToUniversalTime().ToString('s'); FinishedUtc = ''
            }

            $wanted = ($state -eq 'MISSING') -or ($state -eq 'DIFFERS' -and $ReplaceDiffering)
            if ($Plan -or -not $wanted) {
                if ($state -eq 'DIFFERS' -and -not $ReplaceDiffering) {
                    $row.Message = 'same name, different MD5 - left alone. -ReplaceDiffering sends it as a new version.'
                    Write-VaultLog "$prefix - DIFFERS $($att.Name)" 'WARN'
                }
                $row.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
                Add-VaultResult -Results $res -Row $row
                continue
            }

            $local = $null
            $work  = ''
            try {
                # $c.WhatIf rather than $PSCmdlet.ShouldProcess: $PSCmdlet only exists
                # inside an advanced function, and these are plain functions dot-sourced
                # from the dispatcher - referencing it would be a StrictMode error.
                if (-not $c.WhatIf) {
                    Assert-VaultDiskBudget -Path $c.Scratch -Needed $att.Size -ReserveMB $c.ReserveMB
                    Write-VaultLog "$prefix - $state $($att.Name) ($(Format-VaultBytes $att.Size)) - downloading"
                    # A folder per document. Attachment names repeat across documents far
                    # more than document filenames do - "Cover Letter.pdf" on a hundred
                    # documents is ordinary - so one flat scratch folder means one
                    # document's leftover file is the path the next one tries to create.
                    $work  = New-VaultScratch -Root $c.Scratch -Name $srcId
                    $local = Save-VaultFile -VaultHost $c.SourceHost -ApiVersion $c.Api `
                                -Path "/objects/documents/$srcId/attachments/$($att.Id)/file" `
                                -Destination $work -FileName $att.Name
                    $row.SizeBytes = $local.Size

                    # Vault's ORIGINAL name, not the scrubbed local one. Uploading under a
                    # scrubbed name means the target holds "RE_ [EXTERNAL]..." where the
                    # source has "RE: [EXTERNAL]...", the names never match again, and
                    # every later run sends another copy.
                    $up = Send-VaultDocumentAttachment -VaultHost $c.TargetHost -ApiVersion $c.Api `
                             -DocId $tgtId -LocalPath $local.Path -FileName $local.OriginalName
                    $row.Status  = 'ATTACHED'
                    $row.Message = "attachment $($up.AttachmentId) v$($up.Version)"
                    $moved += $local.Size
                    $stat.Attached++
                    Write-VaultLog "$prefix - OK $($att.Name) attached as $($up.AttachmentId) v$($up.Version) ($(Format-VaultBytes $local.Size))" 'OK'
                }
                else {
                    $row.Status  = 'WHATIF'
                    $row.Message = "would deliver $(Format-VaultBytes $att.Size)"
                    Write-VaultLog "$prefix - WhatIf: would deliver $($att.Name)"
                }
            }
            catch {
                $row.Status = 'ERROR'; $row.Message = "$_"; $stat.Errors++
                Write-VaultLog "$prefix - ERROR on $($att.Name): $_" 'ERROR'
            }
            finally {
                Remove-VaultScratchFile -File $local -Scratch $c.Scratch -Prefix "$prefix -"
                if ($work) { Remove-VaultScratchDir -Path $work }
            }

            $row.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
            Add-VaultResult -Results $res -Row $row

            if ($TestCount -gt 0) {
                $done = if ($Plan) { $stat.Missing } else { $stat.Attached }
                if ($done -ge $TestCount) {
                    Write-VaultLog "TEST: $done after $i document(s) - stopping" 'OK'
                    $stopped = $true
                    break documents
                }
            }
        }
    }

    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog ("source {0}   present {1}   missing {2}   different MD5 {3}   no attachments {4}" -f `
                    $stat.Src, $stat.Present, $stat.Missing, $stat.Differs, $stat.NoAtt)
    if ($Plan) {
        Write-VaultLog "PLAN only - nothing was delivered. $($stat.Missing) attachment(s) would be." 'OK'
        # Errors must be reported in every mode. A plan that failed to reach half the
        # documents is not a plan, and saying only "0 would be delivered" reads as good
        # news rather than as a run that never got off the ground.
        if ($stat.Errors) { Write-VaultLog "$($stat.Errors) document(s) could not be read - the figures above are incomplete" 'ERROR' }
    }
    else {
        Write-VaultLog "Attached $($stat.Attached), $($stat.Errors) failed, $(Format-VaultBytes $moved) transferred" $(if ($stat.Errors) { 'WARN' } else { 'OK' })
    }
    if ($stopped) { Write-VaultLog "TEST run - stopped after $i of $($ids.Count) document(s). NOT the whole set." 'WARN' }
    Write-VaultLog "Results: $($res.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($res.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return $stat.Errors
}

function Invoke-VaultAttachmentsVerify {
    param(
        [Parameter(Mandatory)]$Context,
        [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
        [int]$TestCount = 0,
        [int]$Limit = 0
    )
    $c   = $Context
    $map = $c.Map
    $ids = @($map.Keys)
    if ($Limit -gt 0 -and $ids.Count -gt $Limit) { $ids = @($ids | Select-Object -First $Limit) }
    Write-VaultLog "$($ids.Count) mapped document(s) to check by $Depth"

    # Nothing is skipped on a re-run: the point of a check is the CURRENT state, and a
    # MATCH recorded yesterday says nothing about today.
    if ($c.Workers -gt 1 -and $ids.Count -gt 1 -and $TestCount -le 0) {
        $pairs = @($ids | ForEach-Object { [pscustomobject]@{ Source = $_; Target = $map[$_] } })
        return Invoke-VaultShardedRun -Context $c -Pending $pairs -Workers $c.Workers `
                   -Command @('attachments', 'verify') -LogPattern 'attachments-verify-*.log' `
                   -ResultsName 'attachment-validate-results.csv' -KeyColumn 'Key' `
                   -SuccessStatus 'MATCH' -Verb 'Checked' -ShardKind 'map' `
                   -RowsAreItems $false -ExtraArgs @('-Depth', $Depth)
    }

    $res = New-VaultResults -Path (Join-Path $c.Out 'attachment-validate-results.csv') -KeyColumn 'Key' -Existing $c.Existing

    $stat = @{ Match = 0; Mismatch = 0; MissingOnTarget = 0; MissingOnSource = 0; NoChecksum = 0; Errors = 0 }
    $hashed = [long]0
    $i = 0
    $stopped = $false

    function Get-Md5 {
        param([string]$VaultHostName, [string]$DocId, [string]$AttId, [string]$Name, [long]$Size)
        Assert-VaultDiskBudget -Path $c.Scratch -Needed $Size -ReserveMB $c.ReserveMB
        $work = New-VaultScratch -Root $c.Scratch -Name "$VaultHostName-$DocId"
        $f = $null
        try {
            $f = Save-VaultFile -VaultHost $VaultHostName -ApiVersion $c.Api `
                    -Path "/objects/documents/$DocId/attachments/$AttId/file" `
                    -Destination $work -FileName "$VaultHostName-$AttId-$Name"
            return [pscustomobject]@{ Md5 = (Get-FileHash -LiteralPath $f.Path -Algorithm MD5).Hash; Size = $f.Size }
        }
        finally {
            Remove-VaultScratchFile -File $f -Scratch $c.Scratch
            if ($work) { Remove-VaultScratchDir -Path $work }
        }
    }

    :documents foreach ($srcId in $ids) {
        $i++
        $tgtId  = $map[$srcId]
        $prefix = "[$i/$($ids.Count)] $srcId -> $tgtId"

        try { $srcAtt = @(Get-VaultDocumentAttachment -VaultHost $c.SourceHost -ApiVersion $c.Api -DocId $srcId) }
        catch { Write-VaultLog "$prefix - ERROR listing source: $_" 'ERROR'; $stat.Errors++; continue }
        try { $tgtAtt = @(Get-VaultDocumentAttachment -VaultHost $c.TargetHost -ApiVersion $c.Api -DocId $tgtId) }
        catch { Write-VaultLog "$prefix - ERROR listing target: $_" 'ERROR'; $stat.Errors++; continue }
        if ($srcAtt.Count -eq 0 -and $tgtAtt.Count -eq 0) { continue }

        $byName  = Compare-VaultAttachmentSet -Target $tgtAtt
        $matched = @{}

        foreach ($att in $srcAtt) {
            $lname = $att.Name.ToLowerInvariant()
            $row = [pscustomobject][ordered]@{
                Key = "$srcId`:$($att.Id)"; SourceDocId = $srcId; TargetDocId = $tgtId
                Name = $att.Name
                SourceAttachmentId = $att.Id; TargetAttachmentId = ''
                SourceSize = $att.Size; TargetSize = ''
                SourceMd5 = ''; TargetMd5 = ''; Method = $Depth
                Status = ''; Message = ''
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            }

            if (-not $byName.ContainsKey($lname)) {
                $row.Status = 'MISSING_ON_TARGET'; $stat.MissingOnTarget++
                Write-VaultLog "$prefix $($att.Name) - MISSING_ON_TARGET" 'WARN'
                Add-VaultResult -Results $res -Row $row
                continue
            }
            $have = $byName[$lname]
            $matched[$lname] = $true
            $row.TargetAttachmentId = $have.Id
            $row.TargetSize         = $have.Size

            try {
                if ($Depth -eq 'DEEP') {
                    # Hash what each vault actually hands back rather than trusting either
                    # one's record. Sequential so only one file is ever on disk.
                    $a = Get-Md5 -VaultHostName $c.SourceHost -DocId $srcId -AttId $att.Id  -Name $att.Name -Size $att.Size
                    $b = Get-Md5 -VaultHostName $c.TargetHost -DocId $tgtId -AttId $have.Id -Name $att.Name -Size $have.Size
                    $row.SourceMd5 = $a.Md5; $row.TargetMd5 = $b.Md5
                    $row.SourceSize = $a.Size; $row.TargetSize = $b.Size
                    $hashed += $a.Size + $b.Size
                }
                else {
                    $row.SourceMd5 = $att.Checksum; $row.TargetMd5 = $have.Checksum
                }

                if (-not $row.SourceMd5 -or -not $row.TargetMd5) {
                    $row.Status = 'NO_CHECKSUM'
                    $row.Message = 'a side recorded no MD5 - use DEEP to hash the bytes'
                    $stat.NoChecksum++
                    Write-VaultLog "$prefix $($att.Name) - NO_CHECKSUM" 'WARN'
                }
                elseif ($row.SourceMd5 -ieq $row.TargetMd5) {
                    $row.Status = 'MATCH'; $stat.Match++
                    Write-VaultLog "$prefix $($att.Name) - MATCH $($row.SourceMd5)" 'OK'
                }
                else {
                    # Equal sizes with different digests points at repackaging - Office
                    # files are ZIP containers and re-save with new timestamps and entry
                    # order - whereas different sizes mean the content itself differs.
                    $note = if ($row.SourceSize -eq $row.TargetSize) { "same size $(Format-VaultBytes $row.SourceSize)" }
                            else { "source $(Format-VaultBytes $row.SourceSize) vs target $(Format-VaultBytes $row.TargetSize)" }
                    $row.Status = 'MISMATCH'
                    $row.Message = "$note | source $($row.SourceMd5) target $($row.TargetMd5)"
                    $stat.Mismatch++
                    Write-VaultLog "$prefix $($att.Name) - MISMATCH $note | source $($row.SourceMd5) target $($row.TargetMd5)" 'ERROR'
                }
            }
            catch {
                $row.Status = 'ERROR'; $row.Message = "$_"; $stat.Errors++
                Write-VaultLog "$prefix $($att.Name) - ERROR: $_" 'ERROR'
            }
            Add-VaultResult -Results $res -Row $row

            if ($TestCount -gt 0) {
                $done = $stat.Match + $stat.Mismatch + $stat.NoChecksum
                if ($done -ge $TestCount) {
                    Write-VaultLog "TEST: $done compared after $i document(s) - stopping" 'OK'
                    $stopped = $true
                    break documents
                }
            }
        }

        # The other direction. Missing is reported whichever side it is missing from: a
        # file only on the target may predate the migration, but a check that looked one
        # way would never show it.
        foreach ($t in $tgtAtt) {
            if ($matched.ContainsKey($t.Name.ToLowerInvariant())) { continue }
            $stat.MissingOnSource++
            Add-VaultResult -Results $res -Row ([pscustomobject][ordered]@{
                Key = "$srcId`:extra:$($t.Id)"; SourceDocId = $srcId; TargetDocId = $tgtId
                Name = $t.Name
                SourceAttachmentId = ''; TargetAttachmentId = $t.Id
                SourceSize = ''; TargetSize = $t.Size
                SourceMd5 = ''; TargetMd5 = $t.Checksum; Method = $Depth
                Status = 'MISSING_ON_SOURCE'; Message = 'on the target, no attachment of this name on the source'
                CheckedUtc = (Get-Date).ToUniversalTime().ToString('s')
            })
        }
    }

    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog ("{0} compared by {1}" -f ($stat.Match + $stat.Mismatch + $stat.NoChecksum), $Depth)
    Write-VaultLog ("  MATCH              {0}" -f $stat.Match) 'OK'
    if ($stat.Mismatch)        { Write-VaultLog ("  MISMATCH           {0}  - same name, DIFFERENT bytes" -f $stat.Mismatch) 'ERROR' }
    if ($stat.MissingOnTarget) { Write-VaultLog ("  MISSING_ON_TARGET  {0}  - on the source, not the target" -f $stat.MissingOnTarget) 'WARN' }
    if ($stat.MissingOnSource) { Write-VaultLog ("  MISSING_ON_SOURCE  {0}  - on the target, not the source" -f $stat.MissingOnSource) 'WARN' }
    if ($stat.NoChecksum)      { Write-VaultLog ("  NO_CHECKSUM        {0}  - re-run with DEEP" -f $stat.NoChecksum) 'WARN' }
    if ($stat.Errors)          { Write-VaultLog ("  ERROR              {0}" -f $stat.Errors) 'ERROR' }
    if ($Depth -eq 'DEEP')     { Write-VaultLog ("  {0} downloaded and hashed from both vaults" -f (Format-VaultBytes $hashed)) }
    if ($stopped)              { Write-VaultLog "TEST run - stopped after $i of $($ids.Count) document(s). NOT the whole set." 'WARN' }
    if ($stat.Mismatch -eq 0 -and $stat.Errors -eq 0 -and $stat.MissingOnTarget -eq 0 -and $stat.MissingOnSource -eq 0) {
        Write-VaultLog 'Every attachment compared is byte-identical on both vaults.' 'OK'
    }
    Write-VaultLog "Results: $($res.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($res.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return ($stat.Mismatch + $stat.Errors)
}
