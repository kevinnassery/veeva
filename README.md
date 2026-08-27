# Veeva Vault RIM tooling

*Updated 2026-08-27 18:48 EDT*

## Get the scripts

Once:

```
curl.exe -sLo refresh.bat https://raw.githubusercontent.com/kevinnassery/veeva/main/refresh.bat
```

Then `refresh.bat` pulls everything else, and pulls it again whenever you want the latest.
It overwrites the scripts and README. It never touches `documents.ini`,
`sourcedocids.txt`, `session.txt`, or anything in `OutputRoot`.

Individually, if you prefer:

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/document-transfer/probe.bat
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/document-transfer/Probe-Vault.ps1
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/document-transfer/Run-Documents.bat
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/document-transfer/Invoke-VaultDocumentAction.ps1
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/document-transfer/documents.ini
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/README.md
```

Re-downloading `documents.ini` overwrites your settings. Skip that line after the first pull.

| I want to... | Run |
| --- | --- |
| Log in once, stop the password prompts | `login.bat` |
| Copy documents to another vault | `transfer.bat` |
| List a document set's attachments | `Mode = REPORT`, `attachments.bat` |
| Copy attachments to another vault | `Mode = TRANSFER`, `attachments.bat` |
| Probe the vault, change nothing | `probe.bat` |
| See what a view matches | `MODE = REPORT`, `Run-Documents.bat` |
| Rehearse without writing | `Run-Documents.bat -WhatIf`, or `DryRun = true` |
| Size the export before running it | `MODE = REPORT`, or any `-WhatIf` run |
| Update 10 documents | `Run-Documents.bat -MaxDocuments 10` |
| Update everything matched | `MODE = UPDATE`, `Run-Documents.bat` |
| Export to File Staging | `MODE = EXPORT`, `Run-Documents.bat` |
| Spot-check 10% | `Run-Documents.bat -SamplePercent 10` |
| Start reports clean | `Run-Documents.bat -ExistingResults Restart` |
| Import submission dossiers | `submissions-import\Run-Import.bat` |
| Import many applications | `submissions-import\Run-Apps.bat` |

## Fetch things

```bash
V=mallinckrodt-rim.veevavault.com; A=v26.2
S=$(curl.exe -s -X POST "https://$V/api/$A/auth" -d "username=USER&password=PASS" | jq -r .sessionId)
G() { curl.exe -s -H "Authorization: $S" "https://$V/api/$A$1"; }
Q() { curl.exe -s -X POST -H "Authorization: $S" --data-urlencode "q=$1" --data-urlencode "pagesize=1000" "https://$V/api/$A/query"; }
```

Windows: `curl.exe`, not `curl` — `curl` is an alias for `Invoke-WebRequest` in PowerShell 5.1.

| Fetch | Command |
| --- | --- |
| Who am I, my user id | `G /objects/users/me` |
| My permissions | `G /objects/users/me/permissions` |
| API versions | `curl.exe -s -H "Authorization: $S" "https://$V/api/"` — not versioned, so `G` does not fit |
| Document fields (`editable`, `queryable`) | `G /metadata/objects/documents/properties` |
| Document types, by label and name | `G /metadata/objects/documents/types` |
| Object fields | `G /metadata/vobjects/submission__v` |
| One document | `G /objects/documents/123` |
| A document version's text | `G /objects/documents/123/versions/1/0/text` |
| Job status | `G /services/jobs/36203` |
| Export results | `G /objects/documents/batch/actions/fileextract/36203/results` |
| Staging folder listing | `G "/services/file_staging/items/u11280389?recursive=false&limit=50"` |
| Staged file | `G /services/file_staging/items/content/u11280389/wave1/f.pdf` |
| Documents matching a view | `Q "SELECT id, name__v, type__v FROM documents WHERE product__v = '00P1110'"` |
| Product ids | `Q "SELECT id, name__v FROM product__v"` |
| Application ids | `Q "SELECT id, name__v FROM application__v"` |
| Submission ids | `Q "SELECT id, name__v FROM submission__v"` |
| Just the match count | `Q "SELECT id FROM documents WHERE ..." \| jq .responseDetails.total` |

Paging: follow `responseDetails.next_page`, which already carries `/api/v26.2` —
fetch it as `https://$V{next_page}`.

Writes (update, export, upload, import) are in [curl](#curl) below.

Args after a `.bat` pass through to the script. Settings you want to keep go in `documents.ini`.

Written to `OutputRoot`: `probe-output.txt`, `document-fields.csv`, `document-types.csv`,
`products.csv`, `documents.csv`, `document-results.csv`, `documents-<timestamp>.log`.

---

## Export source documents

1. In `documents.ini` set `VaultDNS` and `OutputRoot`. Leave `SessionId` blank.
2. Run `login.bat` once. It caches the session in `session.txt`, so the runs below do
   not each ask for a password. `login.bat -Clear` deletes it.
3. Run `probe.bat` to confirm the vault answers.
4. Put the document ids in a `.txt`, one per line, next to the scripts:

```
id
771
772
773
```

5. Check the list is read correctly. `sourcedocids.txt` beside the scripts is picked up
   automatically - no ini line needed:

```
MODE = REPORT
```

Run `Run-Documents.bat`. Confirm the `documents.csv` count.

6. `MODE = EXPORT`, `MaxDocuments = 2`. Run. Check the staged paths in
   `document-results.csv`.
7. Clear `MaxDocuments`. Run.

Source files only is the default:

```
ExportSource      = true
ExportRenditions  = false
ExportAllVersions = false
ExportText        = false
```

Files land on the source vault's File Staging under a job-id folder. Re-runs skip rows
already `SUCCESS`; old reports are renamed, never deleted.

With `IdFile` set, nothing is queried and no type filtering happens. To have the script
find the documents itself instead, leave `IdFile` blank and use `Product`,
`IncludeTypes`, `Where`, or `Vql`.

## Update document fields

Not needed for extraction. `MODE = UPDATE` with `SetFields = field=value` if it ever is —
field names are checked against the vault before the first batch, and repeating
(multi-value) fields are refused unless `AllowRepeatingFields = true`.

## Move files to another vault

Streams one file at a time: download from the source vault, upload to the target vault's
File Staging, delete the local copy. Nothing is written to the source vault's staging, so
there is nothing to clean up there, and the disk you need is the size of the largest
single document rather than the whole set.

1. In `transfer.ini` set `SourceVaultDNS`, `TargetVaultDNS`, `TargetPath`, `OutputRoot`.
2. Put the ids in `sourcedocids.txt`.
3. `MaxDocuments = 2`, run `transfer.bat`. Confirm the two arrive in the target vault.
4. Clear `MaxDocuments`. Run.

One login is used for both vaults. Each document lands in its own folder named for its
source id:

```
<TargetPath>/<source doc id>/<original filename>
```

so two files called `Cover Letter.pdf` cannot overwrite each other.

`ReserveMB` (default 2048) stops the run rather than filling the volume. Uploads always
use a resumable session, so a 2 GB file streams from disk in parts instead of loading
into memory. Re-runs skip anything already `SUCCESS`.

`TargetVaultDNS` is the vault host, not the sandbox's display name — the part of the
browser URL before `/ui/` when you are logged into that vault.

`TargetPath` ships blank on purpose. The user folder id is per-vault, so a path that is
right on one vault is wrong on another. Run `probe.bat` against the target once for the
real user id, whether that account is Admin there, and which staging folders exist.

## Attachments

The unit of work is the attachment, not the document. Most documents carry none, some
carry many, and the document count says nothing about the volume — so this always starts
with a report.

1. In `attachments.ini` set `SourceVaultDNS` and `OutputRoot`. Leave `SessionId` blank.
2. `Mode = REPORT`, `MaxDocuments = 200`, run `attachments.bat`. Nothing is moved and the
   target vault is not contacted.
3. Read the summary: how many attachments across those documents, and their total size.
   Multiply out against your full id list before going further.
4. Set `TargetVaultDNS` and `TargetPath`, then `Mode = TRANSFER`, `MaxDocuments = 5`. Run.
   Confirm the files arrive.
5. Clear `MaxDocuments`. Run.

Each attachment lands at:

```
<TargetPath>/<source doc id>/attachments/<attachment id>/<filename>
```

The attachment id is in the path because one document can carry two attachments with the
same filename, which the document folder alone would not keep apart.

`Workers` applies to `TRANSFER` only and shards by document, so one document's
attachments stay on one worker. Everything else behaves like the document transfer:
bounded local disk, resumable, re-runs skip anything already `SUCCESS`.

**Getting the files onto target documents is a separate step and is not built.**
`POST /objects/documents/attachments/batch` takes a CSV of `document_id__v`,
`filename__v`, `file` (a staging path), 500 per batch — but it needs the *target*
document id for each source document, and nothing here builds that mapping yet.
`attachment-results.csv` records the source document id and staged path for every file,
which is the half of the mapping that can be produced without it.

## curl

Windows: `curl.exe`, not `curl`.

```bash
V=mallinckrodt-rim.veevavault.com
A=v26.2

# log in
S=$(curl.exe -s -X POST "https://$V/api/$A/auth" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "username=USER&password=PASS" | jq -r .sessionId)

# who am I (id = the /u{user_id} staging folder)
curl.exe -s -H "Authorization: $S" "https://$V/api/$A/objects/users/me"

# the view, as VQL. next_page already carries /api/v26.2
curl.exe -s -X POST -H "Authorization: $S" \
  --data-urlencode "q=SELECT id, name__v, type__v FROM documents WHERE product__v = '00P1110' AND type__v != 'Migrated Document'" \
  --data-urlencode "pagesize=1000" "https://$V/api/$A/query"

# metadata
curl.exe -s -H "Authorization: $S" "https://$V/api/$A/metadata/objects/documents/properties"
curl.exe -s -H "Authorization: $S" "https://$V/api/$A/metadata/objects/documents/types"
curl.exe -s -X POST -H "Authorization: $S" \
  --data-urlencode "q=SELECT id, name__v FROM product__v" "https://$V/api/$A/query"

# bulk update, max 1000 per call. Check the per-row responseStatus, not just the top one
curl.exe -s -X PUT -H "Authorization: $S" -H "Content-Type: text/csv" \
  --data-binary $'id,product__v\n771,00P1110\n772,00P1110' \
  "https://$V/api/$A/objects/documents/batch"

# export, then poll, then results
JOB=$(curl.exe -s -X POST -H "Authorization: $S" -H "Content-Type: application/json" \
  --data-raw '[{"id":"58"},{"id":"134"}]' \
  "https://$V/api/$A/objects/documents/batch/actions/fileextract?source=true&text=false" | jq -r .job_id)
curl.exe -s -H "Authorization: $S" "https://$V/api/$A/services/jobs/$JOB"
curl.exe -s -H "Authorization: $S" "https://$V/api/$A/objects/documents/batch/actions/fileextract/$JOB/results"

# file staging
curl.exe -s -H "Authorization: $S" "https://$V/api/$A/services/file_staging/items/u11280389?recursive=false&limit=50"
curl.exe -s -H "Authorization: $S" -o out.pdf "https://$V/api/$A/services/file_staging/items/content/u11280389/wave1/file.pdf"
curl.exe -s -X POST -H "Authorization: $S" -F "kind=file" -F "path=/u11280389/wave1/file.pdf" \
  -F "overwrite=true" -F "file=@file.pdf" "https://$V/api/$A/services/file_staging/items"

# end session
curl.exe -s -X DELETE -H "Authorization: $S" "https://$V/api/$A/session"
```

---

## Reference

| | |
| --- | --- |
| Document tooling | [`document-transfer/`](document-transfer/) — probe, extractor, cross-vault transfer |
| Attachments | [`attachments/`](attachments/) |
| Submissions importer | [`submissions-import/`](submissions-import/README.md) |
| Vault API v26.2, offline | [`docs/api/`](docs/api/INDEX.md) |
| UI → endpoint mapping, and why the VQL looks the way it does | [`docs/library-bulk-action-api-map.md`](docs/library-bulk-action-api-map.md) |

Windows PowerShell 5.1 or 7. No modules to install.
