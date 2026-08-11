# Veeva Vault RIM — Submissions Archive bulk import

Uploads a folder of downloaded submission archives to Vault's File Staging server and runs
**Import Submission** against each matching `submission__v` record, then writes one CSV row per
archive with the file name, job id, binder id and any validation messages.

## Download

| File | What it is | View | Download |
|---|---|---|---|
| `Import-VaultSubmissions.ps1` | The script. Windows PowerShell 5.1 or PowerShell 7. | [view](https://github.com/kevinnassery/veeva/blob/main/Import-VaultSubmissions.ps1) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/Import-VaultSubmissions.ps1) |
| `config.ini` | **The only file you edit.** All settings live here. | [view](https://github.com/kevinnassery/veeva/blob/main/config.ini) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/config.ini) |
| `Run-Import.bat` | Double-clickable launcher. Nothing to edit in it. | [view](https://github.com/kevinnassery/veeva/blob/main/Run-Import.bat) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/Run-Import.bat) |
| `manifest-template.csv` | Example mapping sheet (the script generates a real one for you). | [view](https://github.com/kevinnassery/veeva/blob/main/manifest-template.csv) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/manifest-template.csv) |

Repository: **https://github.com/kevinnassery/veeva**

Grab all three at once — keep the `.ps1` and `.bat` in the same folder, the wrapper looks for the
script beside itself:

```powershell
$base = 'https://raw.githubusercontent.com/kevinnassery/veeva/main'
'Import-VaultSubmissions.ps1','Run-Import.bat','config.ini','manifest-template.csv' | ForEach-Object {
    Invoke-WebRequest "$base/$_" -OutFile $_
}
```

Or clone it:

```
git clone https://github.com/kevinnassery/veeva.git
```

> Windows marks files downloaded from the internet as blocked. If PowerShell refuses to run the
> script, either unblock it — `Unblock-File .\Import-VaultSubmissions.ps1` — or use `Run-Import.bat`,
> which launches it with `-ExecutionPolicy Bypass` already set.

## What it does not do

It never writes to, moves, renames or deletes anything in the download folder. Source archives are
opened read-only (`FileShare.Read`). Everything the script produces goes to `-OutputRoot`, and the
script refuses to start if `-OutputRoot` is inside the download folder or inside any path passed to
`-ProtectedPath`.

## Before you start

Per Veeva's *Importing Submissions* documentation, these must already be true in Vault:

- The `application__v` and `submission__v` records exist, with identification fields populated.
- Your user has API access plus view/edit permission on the target `submission__v` records.
- If "Automatically populate records" is enabled in your Vault, you need a **Dossier Format**
  Controlled Vocabulary record id — put it in the manifest's `DossierFormatId` column, or pass
  `-DefaultDossierFormatId` once for all rows.

Expected download layout (one folder per application):

```
D:\SubmissionDownloads\
    nda123456\
        0000.zip
        0001.zip
    nda654321\
        0013.zip
```

A flat folder also works, as long as you fill in `ApplicationFolder` in the manifest.

## Three steps

## Configuration — one file

**`config.ini` is the only file you edit.** Both `Import-VaultSubmissions.ps1` and
`Run-Import.bat` read it, so there is never a second copy to keep in sync. `Run-Import.bat` has
nothing configurable in it at all.

```ini
VaultDNS   = mycompany-rim.veevavault.com
SourceRoot = D:\SubmissionDownloads          ; read-only to this script
OutputRoot = D:\ImportRun                    ; must not be inside SourceRoot

MODE = MANIFEST                              ; MANIFEST | DRYRUN | IMPORT

ApiVersion  = v26.2
SessionId   =                                ; blank = log in for me
StagingRoot = /SubmissionsArchive
```

Precedence is **command line → `config.ini` → built-in defaults**, so a one-off
`Run-Import.bat -WhatIf` overrides the file without editing it. `%USERPROFILE%`-style variables
are expanded, and unknown keys produce a warning naming the key rather than being ignored.

**`MODE`** replaces having to remember switches:

| MODE | What happens |
|---|---|
| `MANIFEST` | Scan the download, write `manifest.csv`, stop. No Vault calls. |
| `DRYRUN` | Authenticate, resolve every submission id, upload and import nothing. |
| `IMPORT` | Do it for real. |

`VaultDNS`, `SourceRoot` and `OutputRoot` have no safe default and are checked at startup with a
message naming the missing one. They're deliberately *not* `Mandatory` parameters — that would
prompt on every run even when `config.ini` already has the answer.

**API version.** Every request is built as `https://<VaultDNS>/api/<ApiVersion>/...`, so
`ApiVersion` moves the whole script between releases. It's validated against `v<major>.<minor>`,
so a typo fails at startup instead of 404-ing mid-upload.

**Session id.** `SessionId` in `config.ini` is the only place a session is configured. Leave it
blank for normal use — the script authenticates, holds the session in one script-scoped variable,
and replaces it automatically if Vault expires it mid-run. Set it only to reuse a session you
already hold. Internally it is written in exactly one function (`Connect-Vault`) and read in
exactly one place (the `Authorization` header in `Invoke-VaultApi`); no function takes a session
id as an argument, which is what makes the mid-run re-auth safe.

## Referencing the export output

How each downloaded archive maps to its `submission__v` record depends on where the download came
from. All three cases are handled without hand-mapping:

| Where the download came from | How files are named | What to pass |
|---|---|---|
| **Bulk Submission Export** | `<Application>-<Submission>.zip`, with `export_results.csv` in the matching `-export-summary.zip` | `-ExportResultsCsv <path>` |
| **Per-record attachment pull** (`/vobjects/submission__v/{id}/attachments/file`) | `<submission_id>.zip` | `-NameIsSubmissionId` |
| Anything else | arbitrary | `-Manifest` (built by `-GenerateManifest`) |

`export_results.csv` is Vault's own record of the export: one row per submission with the relative
path to its submission folder plus Submission record field values. Veeva does not publish the
column schema, so the script detects the id column (by name, then by `00S…` value shape) and the
folder-path column (by name, then by value shape), logs which two it picked, and accepts
`-IdColumn` / `-PathColumn` to override. From `nda123456/0000` it derives application `nda123456`,
submission `0000`, and the dossier name `nda123456-0000.zip`; it also indexes `0000.zip` and
`<id>.zip` so renamed downloads still match.

Combine `-ExportResultsCsv` with `-GenerateManifest` to get a manifest with `SubmissionId` already
filled in — review it, then run. A hand-edited manifest always overrides the export CSV.

### 1. Build the mapping sheet

```powershell
.\Import-VaultSubmissions.ps1 -VaultDNS mycompany-rim.veevavault.com `
    -SourceRoot D:\SubmissionDownloads -OutputRoot D:\ImportRun -GenerateManifest
```

No Vault calls, nothing uploaded. It writes `D:\ImportRun\manifest.csv` with `FileName`,
`RelativePath`, `SizeMB` and `ApplicationFolder` **already filled in** — so the file names never
have to be copy/pasted by hand. Add `SubmissionId` for each row.

If you would rather not look up ids, leave `SubmissionId` blank and put the submission's
`name__v` value in `SubmissionKey`; the script resolves it with a VQL query. Use `-LookupField`
to match on a different field (e.g. `submission_number__c`). A key that matches zero or more than
one record is reported as an error for that row rather than guessed at.

### 2. Dry run

```powershell
.\Import-VaultSubmissions.ps1 -VaultDNS mycompany-rim.veevavault.com `
    -SourceRoot D:\SubmissionDownloads -OutputRoot D:\ImportRun `
    -Manifest D:\ImportRun\manifest.csv -WhatIf
```

Authenticates, resolves every submission id, and prints the staging path each archive would go to.
Uploads and imports nothing. Fix anything that shows up as `ERROR` in the CSV before step 3.

### 3. Import

Drop `-WhatIf`. For each archive the script will:

1. `POST /services/file_staging/items` — create `/SubmissionsArchive/<application>/` if needed
2. `POST /services/file_staging/upload` — open a resumable upload session
3. `PUT  /services/file_staging/upload/{id}` — send 50 MB parts (`X-VaultAPI-FilePartNumber`, `Content-MD5`)
4. `POST /services/file_staging/upload/{id}` — commit
5. `POST /vobjects/submission__v/{id}/actions/import` — start the import, returns `job_id`
6. `GET  /services/jobs/{job_id}` — poll to completion
7. `GET  /vobjects/submission__v/{id}/actions/import/{job_id}/results` — binder id/version + messages

## Output

`D:\ImportRun\import-results.csv`, one row per archive:

```
FileName, SourcePath, SizeMB, ApplicationFolder, StagingPath, SubmissionKey, SubmissionId,
JobId, Status, BinderId, BinderVersion, Warnings, Messages, StartedUtc, FinishedUtc
```

The CSV is rewritten after every archive, so an interrupted run still leaves a usable file.
`import-<timestamp>.log` has the full trace.

## Re-running

Safe. Rows already recorded as `SUCCESS` in `import-results.csv` are skipped, so after a network
drop or a batch of fixed manifest rows you can just run it again. To force a re-import of one
archive, delete its row from the CSV.

## Useful switches

| Switch | Default | Notes |
|---|---|---|
| `-ApiVersion` | `v26.2` | Single knob for the whole script. Validated as `v<major>.<minor>`. |
| `-ExportResultsCsv` | — | Vault's export summary; supplies the archive → record mapping. |
| `-IdColumn` / `-PathColumn` | auto-detected | Force the columns if detection picks wrong. |
| `-NameIsSubmissionId` | off | Each file is named `<submission_id>.zip`. |
| `-StagingRoot` | `/SubmissionsArchive` | The Submissions Archive staging root. |
| `-Include` | `*.zip, *.tar.gz, *.tgz` | Vault accepts ZIP and TAR.GZ for API import. |
| `-PartSizeMB` | `50` | Vault's maximum. 2000 parts max ⇒ ~100 GB per archive. |
| `-JobTimeoutMinutes` | `120` | Per-submission job wait. Large dossiers are slow. |
| `-SessionId` | — | Reuse an existing session instead of prompting for credentials. |
| `-ProtectedPath` | `%USERPROFILE%\Documents\wave1` | Folders the script refuses to write into. |

## Things worth knowing

- **Credentials** are prompted for and held only in memory. Nothing is written to disk. If you
  script it unattended, pass `-Credential` from a `Get-Credential | Export-Clixml` file rather
  than putting a password in the `.bat`.
- **Session expiry** is handled — a `INVALID_SESSION_ID` response triggers a silent re-auth and retry.
- **Rate limits** — the script watches `X-VaultAPI-BurstLimitRemaining` and pauses when it runs
  low, and backs off on HTTP 429.
- **ZIP vs folder** — ZIP and TAR.GZ work from the `/SubmissionsArchive` root. Uncompressed folder
  imports are not supported from a user folder (`/u{id}/Submissions Archive Import/...`), which is
  why this script stages to the root.
- **Import warnings** like `APPLICATION_MISMATCH` / `SUBMISSION_MISMATCH` are non-fatal — the job
  still runs. They land in the `Warnings` column and mean the folder name didn't match the record.
- **Vault 26R3 (Dec 2026)** stops returning the `data` array from the import-results endpoint.
  The script tolerates that; `BinderId`/`BinderVersion` will simply be blank and `Messages` still
  populates.

## References

- [Importing Submissions (RIM) — Vault Help](https://regulatory.veevavault.help/en/gr/28082/)
- [Import Submission — API reference v26.1](https://general.veevavault.dev/regulatory/vault-api/api-reference/26.1/rim-submissions-archive/import-submission/)
- [Retrieve Submission Import Results — API reference v26.1](https://general.veevavault.dev/regulatory/vault-api/api-reference/26.1/rim-submissions-archive/retrieve-submission-import-results/)
- [Accessing Your Vault's File Staging](https://platform.veevavault.help/en/gr/38653/)
- [File Staging endpoints (VAPIL reference)](https://veeva.github.io/vault-api-library/javadoc/21.1.4/com/veeva/vault/vapil/api/request/FileStagingRequest.html)
