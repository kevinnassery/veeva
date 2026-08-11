# Veeva Vault RIM — Submissions Archive bulk import

Imports submission dossiers that are **already on File Staging** into RIM Submissions Archive.
Nothing is moved, downloaded or uploaded — each dossier is imported from where it sits.

## How it works

The dossiers live on File Staging under the Submissions Archive root, e.g.

```
/SubmissionsArchive/e157135/nda123456/0000.zip
```

Import Submission reads them straight from there. For each dossier the script calls Import
Submission on the matching `submission__v` record, polls the import job, retrieves the results, and
writes a row to a CSV — file name, staging path, job id, status, binder id/version and any
validation messages.

The archive → submission mapping comes from `export_results.csv`, which Bulk Submission Export
wrote next to the dossiers. It's read **in place off File Staging**, so no local copy is needed and
nothing has to be typed in by hand.

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
VaultDNS          = sb-endo-endo-rim-sbx.veevavault.com
SourceStagingPath = /SubmissionsArchive/e157135
OutputRoot        = C:\Users\Sarah.Nassery

MODE = MANIFEST              ; MANIFEST | DRYRUN | IMPORT

ApiVersion = v26.2
SessionId  =                 ; blank = log in for me
```

Precedence is **command line → `config.ini` → built-in defaults**, so `Run-Import.bat -WhatIf`
gives a one-off dry run without editing the file. `%USERPROFILE%`-style variables are expanded, and
unknown keys warn by name rather than being silently ignored.

| MODE | What happens |
|---|---|
| `MANIFEST` | List the dossiers, write `manifest.csv`, stop. Nothing imported. |
| `DRYRUN` | Resolve every submission id. Import nothing. |
| `IMPORT` | Do it for real. |

**API version.** Every request is built as `https://<VaultDNS>/api/<ApiVersion>/...`, so
`ApiVersion` moves the whole script between releases. It's validated against `v<major>.<minor>`, so
a typo fails at startup instead of 404-ing mid-run.

**Session id.** `SessionId` is the only place a session is configured. Leave it blank for normal
use — the script authenticates, holds the session in one script-scoped variable, and replaces it
automatically if Vault expires it mid-run. Paste a value in to reuse a session you already hold.
Internally it is written in exactly one function (`Connect-Vault`) and read in exactly one place
(the `Authorization` header in `Invoke-VaultApi`); no function takes a session id as an argument,
which is what makes the mid-run re-auth safe.

## Mapping dossiers to submission records

You should not have to type anything in. The export already wrote `export_results.csv` next to the
dossiers — one row per submission, with the relative path to its submission folder plus Submission
record field values. The script reads it in place off File Staging; leave `ExportResultsCsv` blank
and it finds the file under `SourceStagingPath`.

Veeva does not publish the column schema for that CSV, so the script detects the id column (by
name, then by `00S…` value shape) and the folder-path column (by name, then by value shape), logs
which two it picked, and accepts `IdColumn` / `PathColumn` to override.

Fallbacks, in precedence order:

1. `Manifest` — a hand-filled sheet; overrides everything for the file names it lists
2. `export_results.csv` — read off staging, automatic
3. `NameIsSubmissionId = true` — each dossier is named `<submission_id>.zip`
4. VQL lookup on `LookupField` (default `name__v`) using the file's base name

## Three steps

1. **`MODE = MANIFEST`** — writes `manifest.csv`, the worklist: one row per dossier found under
   `SourceStagingPath`, each of which will be imported. Columns are `FileName`, `StagingPath`,
   `SubmissionId`, `SubmissionKey`, `ActualSubmissionDate`, `DossierFormatId` — `SubmissionId` is
   filled in wherever `export_results.csv` could supply it; a blank one is a row that needs
   attention. `FileName` is the join key and `StagingPath` identifies the dossier (file names can
   repeat across applications); the rest are what import actually consumes. Imports nothing.
2. **`MODE = DRYRUN`** — authenticates and resolves every submission id (the VQL lookup is
   read-only, so it genuinely runs). Imports nothing. Fix anything showing `ERROR` first.
3. **`MODE = IMPORT`** — for real.

## Output

`import-results.csv` in `OutputRoot`, one row per dossier:

```
FileName, StagingPath, SizeMB, SubmissionKey, SubmissionId, JobId, Status,
BinderId, BinderVersion, Warnings, Messages, StartedUtc, FinishedUtc
```

Rewritten after every dossier, so an interrupted run still leaves a usable file, and re-running
skips anything already `SUCCESS`.

## Worked example

[`examples/`](https://github.com/kevinnassery/veeva/tree/main/examples) shows three dossiers
carried through the run:

- [`manifest.example.csv`](https://github.com/kevinnassery/veeva/blob/main/examples/manifest.example.csv)
  — the worklist you'd review before importing: `SubmissionId` filled in per row.
- [`import-results.example.csv`](https://github.com/kevinnassery/veeva/blob/main/examples/import-results.example.csv)
  — the output. Two `SUCCESS` (one carrying a non-fatal `SUBMISSION_MISMATCH` warning — the import
  still ran) and one `ERROR` with the reason (`invalid or missing index.xml`) in `Messages`.

That's the whole loop: a `SUCCESS` row gets a `BinderId` and version; a warning is advisory; an
`ERROR` row tells you what to fix and is retried on the next run.

## Prerequisites

- The dossiers are staged under the Submissions Archive root (`.zip`/`.tar.gz` can only be
  imported from there — Vault does not import archives from user folders)
- `application__v` and `submission__v` records already exist with identification fields populated
- API access, plus view/edit on the target `submission__v` records
- **RIM Submissions Archive: Export** and **File Staging: Access** permissions
- A Dossier Format Controlled Vocabulary record id if "Automatically populate records" is enabled —
  per-row in the manifest, or `DefaultDossierFormatId` for all

## Things worth knowing

- **Spaces in staging paths** — path segments are URL-escaped, which matters because unescaped
  spaces 404.
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
