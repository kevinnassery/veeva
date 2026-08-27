# Veeva Vault RIM tooling

*Updated 2026-08-26 22:14 EDT*

## Get the scripts

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/probe.bat
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/Probe-Vault.ps1
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/Run-Documents.bat
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/Invoke-VaultDocumentAction.ps1
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/documents.ini
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/README.md
```

Re-downloading `documents.ini` overwrites your settings. Skip that line after the first pull.

| I want to... | Run |
| --- | --- |
| Probe the vault, change nothing | `probe.bat` |
| See what a view matches | `MODE = REPORT`, `Run-Documents.bat` |
| Rehearse an update | `Run-Documents.bat -WhatIf` |
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
2. Run `probe.bat`. Read `probe-output.txt`.
3. Set the filters:

```
Product      = 00P000000000310
Where        = binder__v = false
ExcludeTypes = Audit Trail, Device Submissions, Staged, Submission Receipt Binder, Submissions Archive
```

4. `MODE = REPORT`, run `Run-Documents.bat`. Confirm the `documents.csv` row count matches
   the Library view. If it does not, go back to step 3.
5. `MODE = EXPORT`, `MaxDocuments = 10`. Run. Check the staged paths in `document-results.csv`.
6. Clear `MaxDocuments`. Run.

Source files only is the default:

```
ExportSource      = true
ExportRenditions  = false
ExportAllVersions = false
ExportText        = false
```

Files land on the source vault's File Staging under a job-id folder. Re-runs skip rows
already `SUCCESS`; old reports are renamed, never deleted.

## Update document fields

Not needed for extraction. `MODE = UPDATE` with `SetFields = field=value` if it ever is —
field names are checked against the vault before the first batch, and repeating
(multi-value) fields are refused unless `AllowRepeatingFields = true`.

## Move files to another vault

Not implemented — endpoints only. Export in the source vault, download, upload to the target.

| Step | Endpoint |
| --- | --- |
| Download staged file | `GET /services/file_staging/items/content/{path}` |
| Upload ≤50MB | `POST /services/file_staging/items` (multipart: `kind`, `path`, `overwrite`, `file`) |
| Upload >50MB | `POST /services/file_staging/upload` → `PUT …/upload/{id}` per part → `POST …/upload/{id}` |
| Ingest | `submissions-import\Run-Import.bat` |

User folders are `/u{user_id}`. Admin paths start at the staging root, non-Admin at their own
folder. `Inbox` creates *Staged* documents.

---

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
| Tools | `probe.bat`, `Run-Documents.bat` → `documents.ini` |
| Submissions importer | [`submissions-import/`](submissions-import/README.md) |
| Vault API v26.2, offline | [`docs/api/`](docs/api/INDEX.md) |
| UI → endpoint mapping, and why the VQL looks the way it does | [`docs/library-bulk-action-api-map.md`](docs/library-bulk-action-api-map.md) |

Windows PowerShell 5.1 or 7. No modules to install.
