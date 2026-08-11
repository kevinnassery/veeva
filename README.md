# Veeva Vault RIM — Submissions Archive bulk import

Imports submission dossiers that are **already on File Staging** into RIM Submissions Archive.
Nothing is moved, downloaded or uploaded — each dossier is imported from where it sits.

## How it works

The submissions live on File Staging under the Submissions Archive root, one folder per submission
inside the application folder:

```
/SubmissionsArchive/e157135/0000      <- application e157135, submission 0000
/SubmissionsArchive/e157135/0001
/SubmissionsArchive/e157135/0002
...
```

Point `SourceStagingPath` at the application folder (`/SubmissionsArchive/e157135`). The script
lists its children over the API — each folder (or `.zip`/`.tar.gz`) is one submission — and for each
one it:

1. Resolves the `submission__v` record by looking it up in Vault: folder name `0000` is the
   submission number, `e157135` is the application. **No manifest, no CSV, nothing typed in.**
2. Calls Import Submission on that record, pointing at the folder's staging path.
3. Polls the import job, retrieves the results, and writes a row to `import-results.csv` — name,
   staging path, job id, status, binder id/version and any validation messages.

Submissions import in place; nothing is moved, downloaded or uploaded.

## Download

| File | What it is | View | Download |
|---|---|---|---|
| `Import-VaultSubmissions.ps1` | The script. Windows PowerShell 5.1 or PowerShell 7. | [view](https://github.com/kevinnassery/veeva/blob/main/Import-VaultSubmissions.ps1) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/Import-VaultSubmissions.ps1) |
| `config.ini` | **The only file you edit.** All settings live here. | [view](https://github.com/kevinnassery/veeva/blob/main/config.ini) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/config.ini) |
| `Run-Import.bat` | Double-clickable launcher for one application. | [view](https://github.com/kevinnassery/veeva/blob/main/Run-Import.bat) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/Run-Import.bat) |
| `Run-Apps.bat` + `Process-Apps.ps1` | Batch launcher: process every application in `apps.txt`. | [view](https://github.com/kevinnassery/veeva/blob/main/Run-Apps.bat) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/Run-Apps.bat) |
| `apps.txt` | List of applications for the batch launcher, one per line. | [view](https://github.com/kevinnassery/veeva/blob/main/apps.txt) | [raw](https://raw.githubusercontent.com/kevinnassery/veeva/main/apps.txt) |
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

## Mapping submissions to records — automatic

By default you type nothing. Each submission's `submission__v` record is found by VQL from the
staging layout itself: the folder name is the submission number, the application folder is the
application. The query is

```
SELECT id FROM submission__v
WHERE <LookupField> = '0000' AND <ApplicationRefField>.<ApplicationKeyField> = 'e157135'
```

scoping the number to one application so repeats across applications stay unambiguous. Three
`config.ini` settings say how your vault names those fields — **confirm they match your object
model**:

| Setting | Default | Is |
|---|---|---|
| `LookupField` | `name__v` | the `submission__v` field holding the folder name (`0000`) |
| `ApplicationRefField` | `application__v` | the `submission__v` → application reference |
| `ApplicationKeyField` | `name__v` | the `application__v` field holding `e157135` |

If a folder name matches zero or more than one record, that submission errors (rather than
guessing) and you can pin it with a manifest. Override the automatic lookup, in precedence order:

1. `Manifest` — a hand-filled `FileName,SubmissionId,…` sheet; wins for any row it lists
2. `ExportResultsCsv` — if you happen to have one; columns auto-detected (`IdColumn`/`PathColumn` to force)
3. `NameIsSubmissionId = true` — each submission is named for its record id

## Three steps

1. **`MODE = MANIFEST`** — writes `manifest.csv`, the worklist: one row per dossier found under
   `SourceStagingPath`, each of which will be imported. Columns are `FileName`, `SubmissionId`,
   `SubmissionKey`, `ActualSubmissionDate`, `DossierFormatId` — exactly what import reads, nothing
   else. `SubmissionId` is filled in wherever `export_results.csv` could supply it; a blank one is a
   row that needs attention. `FileName` is the join key back to the live staging listing, so the
   dossier's real path isn't carried in the sheet. Imports nothing.
2. **`MODE = DRYRUN`** — authenticates and resolves every submission id (the VQL lookup is
   read-only, so it genuinely runs). Imports nothing. Fix anything showing `ERROR` first.
3. **`MODE = IMPORT`** — for real.

## Processing many applications — `apps.txt`

To process several applications in one go, list them in **`apps.txt`** (one per line) and run
**`Run-Apps.bat`** instead of `Run-Import.bat`:

```
# apps.txt - one application (Submissions Archive folder) per line
e157135
e157136
e157140
```

`Run-Apps.bat` (set `MODE` at its top: `MANIFEST` | `DRYRUN` | `IMPORT`) runs the import for each
application in turn. It:

- asks for your Vault credentials **once** and reuses them for every application;
- inherits everything else from `config.ini` (VaultDNS, field mappings, …) — you do **not** set
  `SourceStagingPath` per app, the wrapper does that from each line;
- writes each application's results to its **own** folder, so nothing overwrites:
  `<OutputRoot>\<app>\import-results.csv`;
- prints a per-application pass/fail summary at the end;
- on `IMPORT`, asks you to type `YES` once before doing anything real.

A line starting with `/` is treated as a full staging path; otherwise it's taken as a folder under
`/SubmissionsArchive`. Lines beginning with `#` are comments.

For a single application, `Run-Import.bat` + `config.ini` is still the simplest path — `apps.txt` is
just the batch form of the same run.

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
