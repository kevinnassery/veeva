# Document source files, from one vault into another vault's File Staging.
#
# Ported from Transfer-VaultDocuments.ps1. The shape is deliberately unchanged, because
# every rule below was paid for against a real vault:
#
#   1. GET /objects/documents/{id}/file on the SOURCE, straight to disk. Nothing is
#      written to the source vault's File Staging, so nothing has to be cleaned up there.
#   2. Upload to the TARGET vault's File Staging through a resumable session.
#   3. Delete the local copy.
#
# One file is on local disk at a time, so the disk needed is the size of the largest
# single document, not the size of the set.
#
# This is the opposite choice from the attachment sync, which bypasses File Staging
# entirely - and that is not an inconsistency. An attachment has somewhere to land the
# moment it arrives, so staging it first would only leave litter behind. A document
# source file has no such destination until someone runs the load that consumes it, and
# File Staging is where that load reads from.

# --------------------------------------------------------------------------------------
# Upload: always a resumable session
#
# One code path for every size. A single-part upload is legal because the 5MB minimum
# does not apply to the last part, and a single part is the last part. Parts are read
# from disk a chunk at a time, so a 2GB file never lands in memory.
# --------------------------------------------------------------------------------------

function ConvertTo-VaultStagingPath {
    # A staging path going into a URL PATH has to be escaped per segment - a document
    # called "Q1 Report (final).pdf" is ordinary, and both the space and the parentheses
    # matter. Escaping the whole string would take the separators with it.
    #
    # Only for URL paths. A staging path sent as a form field is escaped by the request
    # itself, and doing it here as well would double-encode it.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)
    $clean = $Path.Replace('\\', '/').Trim('/')
    if (-not $clean) { return '' }
    return (($clean -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
}

$script:VaultMadeFolders = @{}

function New-VaultStagingFolder {
    # Create every level, not just the leaf.
    #
    # Vault's Create Folder does NOT create intermediate folders: posting
    # /u123/wave1/87890 in one call fails with "The parent folder [/u123/wave1/] cannot
    # be found" unless each level above already exists. That took out every upload on
    # the first attachment sync run, and this port had reintroduced it - the transfer
    # script it came from never received the fix.
    #
    # Levels are remembered for the run, so sixteen documents under one wave folder
    # create that shared level once rather than sixteen times.
    #
    # A create that fails is still only a warning: on any re-run the folder is already
    # there, and the upload immediately after is the real test - if a level genuinely
    # could not be made, that fails loudly and with Vault's own message.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Path)

    $parts = @($Path.Trim('/') -split '/' | Where-Object { $_ })
    $cur = ''
    foreach ($part in $parts) {
        $cur = $cur + '/' + $part
        if ($script:VaultMadeFolders.ContainsKey($cur)) { continue }
        $script:VaultMadeFolders[$cur] = $true
        try {
            Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api `
                -Method POST -Path '/services/file_staging/items' `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body @{ kind = 'folder'; path = $cur; overwrite = 'false' } | Out-Null
        }
        catch {
            # Expected for levels that already exist, including the target path itself.
            Write-Verbose "Folder $cur not created (likely already there): $_"
        }
    }
}

function Send-VaultStagingPart {
    # One file part, over HttpWebRequest rather than Invoke-WebRequest.
    #
    # Invoke-WebRequest was sent $buf[0..($read-1)], which on a byte[] produces an
    # Object[], not a byte[]. It then stringifies that - so 877KB of binary went up as a
    # much larger text body and Vault rejected it with OPERATION_NOT_ALLOWED: "Unable to
    # upload additional file parts/bytes". Writing an exact byte count straight to the
    # request stream removes the conversion entirely, and matches how the download side
    # already works.
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$SessionId,
        [Parameter(Mandatory)][byte[]]$Buffer,
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][int]$PartNumber,
        [int]$MaxRetries = 4
    )

    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        $sid = Get-VaultSessionId -VaultHost $Context.TargetHost -ApiVersion $Context.Api

        $uri = "https://$($Context.TargetHost)/api/$($Context.Api)/services/file_staging/upload/$SessionId"
        $req = [Net.HttpWebRequest]::Create($uri)
        $req.Method           = 'PUT'
        $req.ContentType      = 'application/octet-stream'
        $req.ContentLength    = $Count
        $req.Timeout          = 900000
        $req.ReadWriteTimeout = 900000
        # Accept is a RESTRICTED header on HttpWebRequest - Headers.Add throws
        # "The 'Accept' header must be modified using the appropriate property or
        # method". It has to go through the property. Same family as Content-Type and
        # Content-Length, both already set as properties above. Authorization and the
        # X-VaultAPI-* headers are not restricted, so those are fine via Headers.Add.
        $req.Accept = 'application/json'
        $req.Headers.Add('Authorization', $sid)
        $req.Headers.Add('X-VaultAPI-FilePartNumber', "$PartNumber")

        try {
            $rs = $req.GetRequestStream()
            try { $rs.Write($Buffer, 0, $Count) } finally { $rs.Dispose() }

            $resp = $req.GetResponse()
            try {
                $sr   = New-Object IO.StreamReader($resp.GetResponseStream())
                $body = $sr.ReadToEnd(); $sr.Dispose()
                $json = $null
                try { $json = $body | ConvertFrom-Json } catch { }
                if ($json -and (Get-VaultField $json 'responseStatus') -eq 'FAILURE') {
                    $errs = @(Get-VaultField $json 'errors' @())
                    throw 'part ' + $PartNumber + ' rejected -- ' +
                          (($errs | ForEach-Object { "$(Get-VaultField $_ 'type'): $(Get-VaultField $_ 'message')" }) -join '; ')
                }
                return
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
                Write-VaultLog "$($Context.TargetHost) HTTP 429 on part $PartNumber - waiting 60s" 'WARN'
                Start-Sleep -Seconds 60
                continue
            }
            if (((-not $status) -or ($status -ge 500)) -and $attempt -lt $MaxRetries) {
                $wait = [math]::Pow(2, $attempt) * 5
                Write-VaultLog "$($Context.TargetHost) transient error on part $PartNumber (HTTP $status) - retry $attempt/$MaxRetries in ${wait}s" 'WARN'
                Start-Sleep -Seconds $wait
                continue
            }
            throw "part $PartNumber failed (HTTP $status): $($_.Exception.Message) $detail"
        }
    }
    throw "part $PartNumber failed after $MaxRetries attempts"
}

function Send-VaultStagingFile {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$RemotePath,
        [Parameter(Mandatory)][long]$Size,
        [int]$PartSizeMB = 25
    )
    $open = Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api `
                -Method POST -Path '/services/file_staging/upload' `
                -ContentType 'application/x-www-form-urlencoded' `
                -Body @{ path = $RemotePath; size = $Size; overwrite = 'true' }
    $sid = "$(Get-VaultField (Get-VaultField $open 'data' $null) 'id' '')"
    if (-not $sid) { throw "Target did not return an upload session id: $($open | ConvertTo-Json -Depth 5 -Compress)" }

    try {
        $part     = 0
        $partSize = $PartSizeMB * 1MB
        $sent     = [long]0
        $fs = [IO.File]::OpenRead($LocalPath)
        try {
            $buf = New-Object byte[] $partSize
            while (($read = $fs.Read($buf, 0, $buf.Length)) -gt 0) {
                $part++
                Send-VaultStagingPart -Context $Context -SessionId $sid -Buffer $buf -Count $read -PartNumber $part
                $sent += $read
            }
        }
        finally { $fs.Dispose() }
        if ($sent -ne $Size) { throw "uploaded $sent bytes but the session declared $Size" }

        $commit = Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api `
                     -Method POST -Path "/services/file_staging/upload/$sid"
        return [pscustomobject]@{ Parts = $part; Session = $sid; Response = $commit }
    }
    catch {
        # Leave no half-finished session behind - they hold quota and expire slowly.
        try {
            Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api `
                -Method DELETE -Path "/services/file_staging/upload/$sid" | Out-Null
        }
        catch { Write-VaultLog "Could not abort upload session ${sid}: $_" 'WARN' }
        throw
    }
}

# --------------------------------------------------------------------------------------
# The workflow
# --------------------------------------------------------------------------------------

function Invoke-VaultDocumentsStage {
    param(
        [Parameter(Mandatory)]$Context,
        [switch]$Plan,
        [int]$TestCount = 0,
        [int]$Limit = 0
    )
    $c = $Context
    if (-not $c.TargetPath) {
        throw @'
No target staging path is set.

Uploading to the staging ROOT is almost never what is wanted, so this will not guess.
Run `vault probe` against the target vault to get its user folder id and whether your
account is Admin there, then set it in vault.ini:

  [documents]
  path = /u<target user id>/wave1     an Admin gives an absolute path
  path = /wave1                       a non-Admin gives one relative to their folder

Uploading into Inbox is not neutral - it creates Staged documents.
'@
    }

    $ids = @($c.Ids)
    if ($Limit -gt 0 -and $ids.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - examining the first $Limit of $($ids.Count) document(s)" 'WARN'
        $ids = @($ids | Select-Object -First $Limit)
    }
    Write-VaultLog "$($c.SourceHost)  ->  $($c.TargetHost)$($c.TargetPath)"
    Write-VaultLog "$($ids.Count) document(s) to examine"

    $results = New-VaultResults -Path (Join-Path $c.Out 'document-results.csv') `
                   -KeyColumn 'Id' -DoneStatuses @('SUCCESS') -Existing $c.Existing

    # Above one worker this process moves nothing itself: it shards what is still
    # outstanding and supervises. Deliberately not done for -Plan or -WhatIf, where there
    # is nothing to parallelise, nor for -Test, whose whole job is to make five documents
    # easy to follow.
    $pending = @($ids | Where-Object { -not $results.Done.ContainsKey("$_") })
    if ($c.Workers -gt 1 -and $pending.Count -gt 1 -and $TestCount -le 0 -and -not ($Plan -or $c.WhatIf)) {
        return Invoke-VaultShardedRun -Context $c -Pending $pending -Workers $c.Workers `
                   -Command @('documents', 'stage') -LogPattern 'documents-stage-*.log' `
                   -ResultsName 'document-results.csv' -KeyColumn 'Id' `
                   -ExtraArgs @('-TargetPath', "`"$($c.TargetPath)`"")
    }

    $i = 0; $done = 0; $bad = 0; $moved = [long]0
    foreach ($id in $ids) {
        if ($results.Done.ContainsKey("$id")) { continue }
        if ($TestCount -gt 0 -and $done -ge $TestCount) {
            Write-VaultLog "-Test $TestCount reached - stopping with $done document(s) delivered" 'WARN'
            break
        }
        $i++
        $prefix = "[$i/$($ids.Count)] doc $id"
        $record = [ordered]@{
            Id = $id; Name = ''; SizeBytes = 0; TargetPath = ''; Parts = 0
            Status = ''; Message = ''
            StartedUtc = (Get-Date).ToUniversalTime().ToString('s'); FinishedUtc = ''
        }
        $local = $null
        try {
            # Size first, so the disk check happens before anything is downloaded.
            $meta = Invoke-VaultApi -VaultHost $c.SourceHost -ApiVersion $c.Api -Method GET -Path "/objects/documents/$id"
            $doc  = Get-VaultField $meta 'document' $null
            $size = [long]"$(Get-VaultField $doc 'size__v' 0)"
            $record.Name = "$(Get-VaultField $doc 'name__v' '')"

            Assert-VaultDiskBudget -Path $c.Scratch -Needed $size -ReserveMB $c.ReserveMB

            # Every document gets its own folder named for its SOURCE id. Two documents
            # called "Cover Letter.pdf" are common; one overwriting the other after a
            # 12-hour transfer is not something you want to discover afterwards.
            $folder = $c.TargetPath.TrimEnd('/') + '/' + $id

            if ($Plan -or $c.WhatIf) {
                $record.TargetPath = $folder + '/'
                $record.SizeBytes  = $size
                $record.Status     = 'PLAN'
                $record.Message    = "would move $(Format-VaultBytes $size)"
                Write-VaultLog "$prefix - would move $(Format-VaultBytes $size) to $folder/"
            }
            else {
                Write-VaultLog "$prefix - downloading $(Format-VaultBytes $size)"
                $local = Save-VaultFile -VaultHost $c.SourceHost -ApiVersion $c.Api `
                             -Path "/objects/documents/$id/file" -Destination $c.Scratch
                $record.SizeBytes = $local.Size
                $record.Name      = $local.OriginalName

                # The name that goes back out to Vault is the one Vault gave us, not the
                # one scrubbed for the local filesystem. Uploading the scrubbed name
                # means the names stop matching and a later run cannot tell what landed.
                $remote = $folder + '/' + $local.OriginalName
                $record.TargetPath = $remote
                New-VaultStagingFolder -Context $c -Path $folder

                Write-VaultLog "$prefix - uploading to $remote"
                $up = Send-VaultStagingFile -Context $c -LocalPath $local.Path -RemotePath $remote `
                          -Size $local.Size -PartSizeMB $c.PartSizeMB
                $record.Parts  = $up.Parts
                $record.Status = 'SUCCESS'
                $moved += $local.Size
                $done++
                Write-VaultLog "$prefix - OK ($($local.Name), $(Format-VaultBytes $local.Size), $($up.Parts) part(s))" 'OK'
            }
        }
        catch {
            $record.Status  = 'ERROR'
            $record.Message = "$_"
            $bad++
            Write-VaultLog "$prefix - ERROR: $_" 'ERROR'
        }
        finally {
            Remove-VaultScratchFile -File $local -Scratch $c.Scratch -Prefix "$prefix -"
        }
        $record.FinishedUtc = (Get-Date).ToUniversalTime().ToString('s')
        Add-VaultResult -Results $results -Row ([pscustomobject]$record)
    }

    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "Moved $done document(s), $bad failed, $(Format-VaultBytes $moved) transferred" $(if ($bad) { 'WARN' } else { 'OK' })
    Write-VaultLog "Results: $($results.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($results.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return $bad
}

# --------------------------------------------------------------------------------------
# The validator
#
# A separate command, run when the operator chooses to run it - never chained onto the
# end of a transfer. A check that only ever runs as the last step of the thing it is
# checking cannot be re-run against a finished migration, cannot be run by someone other
# than whoever did the transfer, and stops running at exactly the moment the transfer
# fails - which is when it matters most.
# --------------------------------------------------------------------------------------

function Get-VaultStagingItems {
    # The files directly inside one staging folder. A folder that does not exist is not
    # an error here - it is the answer, and the caller reports it as missing.
    param([Parameter(Mandatory)]$Context, [Parameter(Mandatory)][string]$Path)
    $items = @()
    $next  = "/services/file_staging/items/$(ConvertTo-VaultStagingPath $Path)?recursive=false&limit=1000"
    while ($next) {
        $r = Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api -Method GET -Path $next
        foreach ($d in @(Get-VaultField $r 'data' @())) {
            if ("$(Get-VaultField $d 'kind' '')" -ne 'file') { continue }
            $items += [pscustomobject]@{
                Name = "$(Get-VaultField $d 'name' '')"
                Size = [long]"$(Get-VaultField $d 'size' 0)"
                Path = "$(Get-VaultField $d 'path' '')"
            }
        }
        $next = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }
    return $items
}

function Get-VaultStagedDocumentIds {
    # What is on the target, according to the target - not according to our own results
    # file. Each per-document folder under the wave path is named for its SOURCE document
    # id, which is what makes this answerable in one listing.
    #
    # recursive=false on purpose: this wants the folder names, and enumerating every file
    # inside 15,000 of them to count the folders would be thousands of pages of response
    # to answer a question the folder names already answer.
    param([Parameter(Mandatory)]$Context)
    $ids = New-Object System.Collections.ArrayList
    $odd = New-Object System.Collections.ArrayList
    $next = "/services/file_staging/items/$(ConvertTo-VaultStagingPath $Context.TargetPath)?recursive=false&limit=1000"
    while ($next) {
        $r = Invoke-VaultApi -VaultHost $Context.TargetHost -ApiVersion $Context.Api -Method GET -Path $next
        foreach ($d in @(Get-VaultField $r 'data' @())) {
            $name = "$(Get-VaultField $d 'name' '')"
            if ("$(Get-VaultField $d 'kind' '')" -ne 'folder') {
                if ($name) { [void]$odd.Add($name) }
                continue
            }
            if ($name -match '^\d+$') { [void]$ids.Add($name) }
            elseif ($name) { [void]$odd.Add($name) }
        }
        $next = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }
    if ($odd.Count) {
        Write-VaultLog "$($odd.Count) item(s) under $($Context.TargetPath) are not document folders: $(($odd | Select-Object -First 5) -join ', ')" 'WARN'
    }
    return @($ids)
}

function Invoke-VaultDocumentsList {
    # How much is already on the target, and whether it looks right.
    param([Parameter(Mandatory)]$Context)
    $c = $Context
    if (-not $c.TargetPath) { throw 'No target staging path is set. See [documents] path in the config.' }
    Write-VaultLog "$($c.TargetHost)$($c.TargetPath)"

    $ids = Get-VaultStagedDocumentIds -Context $c
    Write-VaultLog "$($ids.Count) document folder(s) on the target" 'OK'
    if (-not $ids.Count) { return 0 }

    # Now the files, which needs the recursive listing. Reported per document so a folder
    # holding none - a transfer that made the folder and then failed - is visible rather
    # than averaged away.
    # Only files inside the document folders are counted. The wave path may hold plenty
    # that is not ours - Inbox, other waves, anything a person put there - and folding
    # that into the totals reports someone else's 8,000 files as this migration's work.
    $known = @{}
    foreach ($i in $ids) { $known["$i"] = $true }

    $files = 0; $bytes = [long]0; $skipped = 0
    $perDoc = @{}
    $next = "/services/file_staging/items/$(ConvertTo-VaultStagingPath $c.TargetPath)?recursive=true&limit=1000"
    while ($next) {
        $r = Invoke-VaultApi -VaultHost $c.TargetHost -ApiVersion $c.Api -Method GET -Path $next
        foreach ($d in @(Get-VaultField $r 'data' @())) {
            if ("$(Get-VaultField $d 'kind' '')" -ne 'file') { continue }
            $path = "$(Get-VaultField $d 'path' '')"
            $rel  = $path.Substring([math]::Min($path.Length, $c.TargetPath.TrimEnd('/').Length)).Trim('/')
            $docId = ($rel -split '/')[0]
            if (-not $docId -or -not $known.ContainsKey($docId)) { $skipped++; continue }
            $files++
            $bytes += [long]"$(Get-VaultField $d 'size' 0)"
            $perDoc[$docId] = 1 + [int]$perDoc[$docId]
        }
        $next = "$(Get-VaultField (Get-VaultField $r 'responseDetails' $null) 'next_page' '')"
    }

    $empty = @($ids | Where-Object { -not $perDoc.ContainsKey($_) })
    $multi = @($perDoc.Keys | Where-Object { $perDoc[$_] -gt 1 })

    Write-VaultLog "$files file(s) in those folders, $(Format-VaultBytes $bytes)" 'OK'
    if ($skipped) {
        Write-VaultLog "$skipped file(s) under $($c.TargetPath) are outside the document folders and were not counted"
    }
    if ($empty.Count) {
        Write-VaultLog "$($empty.Count) folder(s) hold no file - a transfer made the folder and did not finish: $(($empty | Select-Object -First 5) -join ', ')" 'WARN'
    }
    if ($multi.Count) {
        Write-VaultLog "$($multi.Count) folder(s) hold more than one file - an earlier run landed a different filename: $(($multi | Select-Object -First 5) -join ', ')" 'WARN'
    }
    Write-VaultLog 'Check these with: documents verify -Staged'
    return 0
}

function Invoke-VaultDocumentsVerify {
    param(
        [Parameter(Mandatory)]$Context,
        [ValidateSet('FAST', 'DEEP')][string]$Depth = 'DEEP',
        [int]$TestCount = 0,
        [int]$Limit = 0,
        [switch]$Staged
    )
    $c = $Context
    if (-not $c.TargetPath) { throw 'No target staging path is set. See [documents] path in the config.' }

    if ($Staged) {
        # Check what is actually there, rather than what was asked for. Verifying the
        # whole input list after moving part of it reports every document not yet sent
        # as MISSING_ON_TARGET, which buries the real failures in thousands of rows
        # saying nothing more than "not done yet".
        $ids = Get-VaultStagedDocumentIds -Context $c
        Write-VaultLog "-Staged: checking the $($ids.Count) document(s) on the target, not the $(@($c.Ids).Count) in the id list"
        if (-not $ids.Count) { Write-VaultLog "Nothing is staged under $($c.TargetPath)" 'WARN'; return 0 }
    }
    else { $ids = @($c.Ids) }
    if ($Limit -gt 0 -and $ids.Count -gt $Limit) {
        Write-VaultLog "Limit $Limit - checking the first $Limit of $($ids.Count) document(s)" 'WARN'
        $ids = @($ids | Select-Object -First $Limit)
    }
    Write-VaultLog "$($c.SourceHost)  vs  $($c.TargetHost)$($c.TargetPath)"
    if ($Depth -eq 'FAST') {
        # Said plainly rather than left to be discovered: File Staging's listing returns
        # kind, name, size and modified date, and no checksum of any kind. FAST therefore
        # compares sizes, which catches a truncated or absent file and nothing subtler.
        Write-VaultLog 'FAST: File Staging reports no checksum, so this compares NAME and SIZE only.' 'WARN'
        Write-VaultLog 'Use DEEP to download both copies and compare the bytes.' 'WARN'
    }
    Write-VaultLog "$($ids.Count) document(s) to check ($Depth)"

    $results = New-VaultResults -Path (Join-Path $c.Out 'document-validate-results.csv') `
                   -KeyColumn 'Id' -DoneStatuses @() -Existing $c.Existing

    $i = 0; $checked = 0; $bad = 0
    foreach ($id in $ids) {
        if ($TestCount -gt 0 -and $checked -ge $TestCount) {
            Write-VaultLog "-Test $TestCount reached - stopping after $checked document(s)" 'WARN'
            break
        }
        $i++
        $prefix = "[$i/$($ids.Count)] doc $id"
        $folder = $c.TargetPath.TrimEnd('/') + '/' + $id
        $row = [ordered]@{
            # Seeded with the folder so a document that never arrived still records
            # where it was looked for. Replaced with the file's full path the moment one
            # is found, which is what `stage` writes and what can be pasted into a
            # staging listing or a load.
            Id = $id; Name = ''; SourceBytes = 0; TargetBytes = 0; TargetPath = $folder
            SourceMd5 = ''; TargetMd5 = ''; Method = $Depth; Status = ''; Message = ''
        }
        $srcFile = $null; $tgtFile = $null
        try {
            $srcName = ''; $srcSize = [long]0; $haveSource = $true
            try {
                $meta = Invoke-VaultApi -VaultHost $c.SourceHost -ApiVersion $c.Api -Method GET -Path "/objects/documents/$id"
                $doc  = Get-VaultField $meta 'document' $null
                $srcName = "$(Get-VaultField $doc 'filename__v' '')"
                if (-not $srcName) { $srcName = "$(Get-VaultField $doc 'name__v' '')" }
                $srcSize = [long]"$(Get-VaultField $doc 'size__v' 0)"
            }
            catch { $haveSource = $false; $row.Message = "source: $_" }
            $row.Name        = $srcName
            $row.SourceBytes = $srcSize

            # NOT $staged: PowerShell variable names are case-insensitive, so a local
            # $staged and the -Staged parameter are one variable. Assigning the folder
            # listing to it threw "Cannot convert System.Object[] to SwitchParameter" on
            # every single document, the moment -Staged was added.
            $onTarget = @()
            try { $onTarget = @(Get-VaultStagingItems -Context $c -Path $folder) }
            catch { $onTarget = @() }

            if (-not $haveSource) {
                $row.Status = 'MISSING_ON_SOURCE'
                if ($onTarget.Count) {
                    $row.TargetBytes = $onTarget[0].Size
                    $row.TargetPath  = $onTarget[0].Path
                    if (-not $row.Name) { $row.Name = $onTarget[0].Name }
                }
                Write-VaultLog "$prefix - MISSING_ON_SOURCE" 'ERROR'
            }
            elseif (-not $onTarget.Count) {
                $row.Status  = 'MISSING_ON_TARGET'
                $row.Message = "nothing in $folder"
                Write-VaultLog "$prefix - MISSING_ON_TARGET ($folder is empty or absent)" 'ERROR'
            }
            else {
                # One file per folder is what the transfer writes. More than one means a
                # re-run under a changed filename, and reporting the first silently would
                # hide it.
                if ($onTarget.Count -gt 1) {
                    $row.Message = "$($onTarget.Count) files in ${folder}: " + (($onTarget | ForEach-Object { $_.Name }) -join ', ')
                }
                $match = @($onTarget | Where-Object { $_.Name -eq $srcName }) | Select-Object -First 1
                if (-not $match) { $match = $onTarget[0] }
                $row.TargetBytes = $match.Size
                $row.TargetPath  = $match.Path

                if ($Depth -eq 'DEEP') {
                    Assert-VaultDiskBudget -Path $c.Scratch -Needed ($srcSize * 2) -ReserveMB $c.ReserveMB
                    $srcFile = Save-VaultFile -VaultHost $c.SourceHost -ApiVersion $c.Api `
                                   -Path "/objects/documents/$id/file" -Destination $c.Scratch
                    $tgtFile = Save-VaultFile -VaultHost $c.TargetHost -ApiVersion $c.Api `
                                   -Path "/services/file_staging/items/content/$(ConvertTo-VaultStagingPath $match.Path)" `
                                   -Destination $c.Scratch -FileName ('staged-' + $match.Name)
                    $row.SourceMd5   = (Get-FileHash -LiteralPath $srcFile.Path -Algorithm MD5).Hash
                    $row.TargetMd5   = (Get-FileHash -LiteralPath $tgtFile.Path -Algorithm MD5).Hash
                    $row.SourceBytes = $srcFile.Size
                    $row.TargetBytes = $tgtFile.Size

                    if ($row.SourceMd5 -ieq $row.TargetMd5) {
                        $row.Status = 'MATCH'
                        Write-VaultLog "$prefix - MATCH $($row.SourceMd5)" 'OK'
                    }
                    else {
                        $row.Status  = 'MISMATCH'
                        $row.Message = "source $($row.SourceBytes) B / $($row.SourceMd5), target $($row.TargetBytes) B / $($row.TargetMd5)"
                        Write-VaultLog "$prefix - MISMATCH $($row.Message)" 'ERROR'
                    }
                }
                else {
                    if ($srcSize -gt 0 -and $match.Size -eq $srcSize) {
                        $row.Status = 'MATCH'
                        Write-VaultLog "$prefix - MATCH $($match.Name) ($(Format-VaultBytes $match.Size), size only)" 'OK'
                    }
                    elseif ($srcSize -le 0) {
                        $row.Status  = 'UNKNOWN'
                        $row.Message = 'source recorded no size - use DEEP'
                        Write-VaultLog "$prefix - UNKNOWN (source recorded no size, use DEEP)" 'WARN'
                    }
                    else {
                        $row.Status  = 'MISMATCH'
                        $row.Message = "source $srcSize B, target $($match.Size) B"
                        Write-VaultLog "$prefix - MISMATCH $($row.Message)" 'ERROR'
                    }
                }
            }
        }
        catch {
            $row.Status  = 'ERROR'
            $row.Message = "$_"
            Write-VaultLog "$prefix - ERROR: $_" 'ERROR'
        }
        finally {
            Remove-VaultScratchFile -File $srcFile -Scratch $c.Scratch -Prefix "$prefix -"
            Remove-VaultScratchFile -File $tgtFile -Scratch $c.Scratch -Prefix "$prefix -"
        }
        if ($row.Status -notin @('MATCH')) { $bad++ }
        $checked++
        Add-VaultResult -Results $results -Row ([pscustomobject]$row)
    }

    Report-VaultLeftovers -Scratch $c.Scratch
    Write-VaultLog '----------------------------------------------------------------'
    Write-VaultLog "Checked $checked document(s), $bad not matching" $(if ($bad) { 'WARN' } else { 'OK' })
    Write-VaultLog "Results: $($results.Path)"
    $snap = Copy-VaultResultsSnapshot -Path $($results.Path)
    if ($snap) { Write-VaultLog "This run : $snap" }
    return $bad
}
