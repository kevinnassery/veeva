# Veeva Vault RIM — Submissions Archive bulk import

Imports exported submission dossiers into Submissions Archive **entirely on the File Staging
server**. Nothing is downloaded, nothing is uploaded, no local disk is involved beyond a log and a
results CSV.

## Why there's a move step

Bulk Submission Export leaves its output on File Staging, under:

```
/u{UserID}/Submissions Archive Export/{JobID}/...
```

Import Submission can only read from one of two places:

| Location | Accepts |
|---|---|
| `/SubmissionsArchive/{application}/{submission}` | folder, `.zip` or `.tar.gz` |
| `/u{ID}/Submissions Archive Import/{application}/{submission}` | folder only — *"Vault does not support importing .zip or .tar.gz files from user folders."* |

The export writes to a third location, and the folder is literally named `Export`, not `Import`. So
the dossiers are already on the server, just in the wrong drawer. This tool relocates each one into
`/SubmissionsArchive/<application>/` with a single `PUT /services/file_staging/items` — server-side,
zero bytes across the network — then imports it.

That move is asynchronous (Vault returns a job id, which the script polls), and **the File Staging
API has no copy operation, only move**. So the relocation is one-way unless you set
`MoveBack = true`, which returns each dossier to its export path after a successful import.

## Download

| File | What it is | View | Download |
|---|---|---|---|
| `Import-VaultSubmissions.ps1` | The script. Windows PowerShell 5.1 or PowerShell 7. | [view](https://github.com/kevinnassery/veeva/blob/main/Import-VaultSubmissions.ps1) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/Import-VaultSubmissions.ps1) |
| `config.ini` | **The only file you edit.** All settings live here. | [view](https://github.com/kevinnassery/veeva/blob/main/config.ini) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/config.ini) |
| `Run-Import.bat` | Double-clickable launcher. Nothing to edit in it. | [view](https://github.com/kevinnassery/veeva/blob/main/Run-Import.bat) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/Run-Import.bat) |
| `manifest-template.csv` | Example mapping sheet (the script generates a real one for you). | [view](https://github.com/kevinnassery/veeva/blob/main/manifest-template.csv) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/manifest-template.csv) |

Repository: **https://github.com/kevinnassery/veeva**

```powershell
$base = 'https://raw.githubusercontent.com/kevinnassery/veeva/main'
'Import-VaultSubmissions.ps1','Run-Import.bat','config.ini','manifest-template.csv' | ForEach-Object {
    Invoke-WebRequest "$base/$_" -OutFile $_
}
```

Or `git clone https://github.com/kevinnassery/veeva.git`

> Windows marks files downloaded from the internet as blocked. If PowerShell refuses to run the
> script, either unblock it — `Unblock-File .\Import-VaultSubmissions.ps1` — or use `Run-Import.bat`,
> which launches it with `-ExecutionPolicy Bypass` already set.

## Configuration — one file

**`config.ini` is the only file you edit.** Both the script and the `.bat` read it, so there is
never a second copy to keep in sync.

```ini
VaultDNS          = mycompany-rim.veevavault.com
SourceStagingPath = /u5678/Submissions Archive Export/727301
OutputRoot        = D:\ImportRun

MODE = MANIFEST              ; MANIFEST | DRYRUN | IMPORT

ApiVersion  = v26.2
SessionId   =                ; blank = log in for me
StagingRoot = /SubmissionsArchive
MoveBack    = false
```

Precedence is **command line → `config.ini` → built-in defaults**, so `Run-Import.bat -WhatIf`
gives a one-off dry run without editing the file. `%USERPROFILE%`-style variables are expanded, and
unknown keys warn by name rather than being silently ignored.

| MODE | What happens |
|---|---|
| `MANIFEST` | List the export, write `manifest.csv`, stop. Nothing is moved. |
| `DRYRUN` | Resolve every submission id and show the moves. Nothing changes. |
| `IMPORT` | Do it for real. |

**API version.** Every request is built as `https://<VaultDNS>/api/<ApiVersion>/...`, so
`ApiVersion` moves the whole script between releases. It's validated against `v<major>.<minor>`, so
a typo fails at startup instead of 404-ing mid-run.

**Session id.** `SessionId` is the only place a session is configured. Leave it blank for normal
use — the script authenticates, holds the session in one script-scoped variable, and replaces it
automatically if Vault expires it mid-run. Internally it is written in exactly one function
(`Connect-Vault`) and read in exactly one place (the `Authorization` header in `Invoke-VaultApi`);
no function takes a session id as an argument, which is what makes the mid-run re-auth safe.

## Mapping dossiers to submission records

You should not have to type anything in. The export already wrote `export_results.csv` next to the
dossiers — one row per submission, with the relative path to its submission folder plus Submission
record field values. The script **reads it in place off File Staging**, so no local copy is needed.
Leave `ExportResultsCsv` blank and it finds the file under `SourceStagingPath`.

Veeva does not publish the column schema for that CSV, so the script detects the id column (by
name, then by `00S…` value shape) and the folder-path column (by name, then by value shape), logs
which two it picked, and accepts `IdColumn` / `PathColumn` to override. From `nda123456/0000` it
derives application `nda123456`, submission `0000`, and indexes the entry under several likely file
names so renamed dossiers still match.

Fallbacks, in precedence order:

1. `Manifest` — a hand-filled sheet; overrides everything for the file names it lists
2. `export_results.csv` — read off staging, automatic
3. `NameIsSubmissionId = true` — each dossier is named `<submission_id>.zip`
4. VQL lookup on `LookupField` (default `name__v`) using the file's base name

## Three steps

1. **`MODE = MANIFEST`** — lists the export folder and writes `manifest.csv` with `FileName`,
   `StagingPath`, `SizeMB`, `ApplicationFolder` and `SubmissionId` already filled in wherever
   `export_results.csv` could supply them. No changes to anything.
2. **`MODE = DRYRUN`** — authenticates, resolves every submission id (the VQL lookup is read-only,
   so it genuinely runs), and prints the move each dossier would make. Nothing is moved or imported.
   Fix anything showing `ERROR` before step 3.
3. **`MODE = IMPORT`** — for real.

## Output

`import-results.csv` in `OutputRoot`, one row per dossier:

```
FileName, SourceStagingPath, SizeMB, ApplicationFolder, ImportStagingPath, SubmissionKey,
SubmissionId, MoveJobDone, JobId, Status, BinderId, BinderVersion, Warnings, Messages,
StartedUtc, FinishedUtc
```

Both staging paths are recorded, so a one-way move is always traceable. The CSV is rewritten after
every dossier, so an interrupted run still leaves a usable file, and re-running skips anything
already `SUCCESS`.

## Prerequisites

- `application__v` and `submission__v` records already exist with identification fields populated
- API access, plus view/edit on the target `submission__v` records
- **RIM Submissions Archive: Export** and **File Staging: Access** permissions
- A Dossier Format Controlled Vocabulary record id if "Automatically populate records" is enabled —
  per-row in the manifest, or `DefaultDossierFormatId` for all

## Things worth knowing

- **Export size caps.** A single Bulk Submission Export tops out at 50,000 files / 5.3 GB, so a
  large wave arrives as several export jobs. Run the script once per job folder.
- **Spaces in staging paths** — the export folder is literally named `Submissions Archive Export`.
  Path segments are URL-escaped, which matters because unescaped spaces 404.
- **Import warnings** like `APPLICATION_MISMATCH` / `SUBMISSION_MISMATCH` are non-fatal; the job
  still runs. They land in the `Warnings` column and mean the folder name didn't match the record.
- **Vault 26R3 (Dec 2026)** stops returning the `data` array from the import-results endpoint. The
  script tolerates that: `BinderId` / `BinderVersion` go blank, `Messages` still populates.
- **Rate limits** — the script watches `X-VaultAPI-BurstLimitRemaining`, pauses when it runs low,
  and backs off on HTTP 429.

## Status

Written and checked against the v26.1 / v26.2 API documentation. **It has not been run against a
live vault.** Do the `DRYRUN` pass on two or three dossiers before turning it loose on a full wave.

## References

- [Importing Submissions (RIM)](https://regulatory.veevavault.help/en/gr/28082/)
- [Using Bulk Submission Export (RIM)](https://regulatory.veevavault.help/en/gr/42262/)
- [Import Submission — API v26.1](https://general.veevavault.dev/regulatory/vault-api/api-reference/26.1/rim-submissions-archive/import-submission/)
- [Retrieve Submission Import Results — API v26.1](https://general.veevavault.dev/regulatory/vault-api/api-reference/26.1/rim-submissions-archive/retrieve-submission-import-results/)
- [Accessing Your Vault's File Staging](https://platform.veevavault.help/en/gr/38653/)
- [File Staging endpoints (VAPIL reference)](https://veeva.github.io/vault-api-library/javadoc/21.1.4/com/veeva/vault/vapil/api/request/FileStagingRequest.html)
