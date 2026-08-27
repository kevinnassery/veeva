# Veeva Vault RIM — Submissions Archive bulk import

Imports submission dossiers that are **already on File Staging** into RIM Submissions Archive.
Nothing is moved, downloaded or uploaded — each dossier is imported from where it sits.

## Updating and running

### Update to the latest version

The scripts are replaced, not patched. Open PowerShell **in the folder that holds them** and
run this — it overwrites each file with the current version from GitHub:

```powershell
$base = 'https://raw.githubusercontent.com/kevinnassery/veeva/main'
'Import-VaultSubmissions.ps1','Process-Apps.ps1','Run-Import.bat','Run-Apps.bat','apps.txt' |
    ForEach-Object { Invoke-WebRequest "$base/$_" -OutFile $_ }
```

**`config.ini` is deliberately not in that list** — updating never overwrites your settings.
When a release adds a setting, fetch the new file *beside* yours and copy the lines you want:

```powershell
Invoke-WebRequest "$base/config.ini" -OutFile config.ini.new    # $base from above
```

Then re-run whatever you were running. Nothing else is installed and there is no state to
migrate; the script's only inputs are `config.ini` and what it reads from Vault.

> If PowerShell refuses to run a freshly downloaded file, Windows has marked it as blocked.
> Either `Unblock-File .\*.ps1`, or use the `.bat` launchers — they already pass
> `-ExecutionPolicy Bypass`.

### Example usage

| What you want | How |
|---|---|
| One application, settings from `config.ini` | Double-click **`Run-Import.bat`** |
| One application, list what's there | `Run-Import.bat -GenerateManifest` |
| One application, one-off dry run | `Run-Import.bat -WhatIf` (needs `MODE = DRYRUN` or `IMPORT`) |
| One application, spot-check ~10% of it | `Run-Import.bat -SamplePercent 10` |
| Every application in `apps.txt` | Double-click **`Run-Apps.bat`** (set `MODE` at its top) |
| Every application, sampling 10% of each | Set `SAMPLE=10` at the top of `Run-Apps.bat` |
| Ignore an earlier run's reports, start clean | `Run-Import.bat -ExistingResults Restart` |
| Direct, no launcher | `.\Import-VaultSubmissions.ps1 -WhatIf -SamplePercent 25` |

Two things to know about how `MODE` and the switches interact:

- **`SamplePercent` narrows whichever `MODE` you're in** — it never starts an import on its
  own. Under the shipped `MODE = MANIFEST`, `-SamplePercent 10` writes a manifest of a random
  10%; under `IMPORT` it imports that 10%.
- **`MODE = MANIFEST` stops after writing the manifest.** It wins over `-WhatIf`, so a dry run
  needs `MODE = DRYRUN` or `MODE = IMPORT` in `config.ini`. Set `MODE` first, then use the
  switches to vary a single run.

### Continuing or starting fresh

If the CSV reports this run writes — `import-results.csv` and `manifest.csv` — are already in
`OutputRoot` from an earlier run, the script says what it found and asks, **before it
authenticates or touches Vault**:

```
[WARN] Reports from an earlier run are already in C:\Users\Sarah.Nassery :
[WARN]   import-results.csv - 21 row(s), 18 SUCCESS, application e134128, written 2026-08-11 16:03
[WARN]   manifest.csv - 21 row(s), 0 SUCCESS, application e134128, written 2026-08-11 15:58
[C]ontinue this run (skip what already succeeded), or [R]estart (rotate these aside and begin fresh)? [C]
```

The summary is there so you can answer without opening the file — the row count, how many
landed, **which application they belong to**, and when they were written. That last pair is
usually the deciding factor: reports naming a different application are from a different wave.

| Answer | What happens |
|---|---|
| **`C`** (or Enter) | Continue. Submissions already `SUCCESS` are skipped, their rows preserved. |
| **`R`** | Restart. The reports are rotated aside and this run starts with an empty sheet. |

**Restart renames, it never deletes.** Each report is moved to a name carrying the time it was
*written* — not the time you restarted — so the file is labelled by the run whose data it holds:

```
import-results.csv  ->  import-results-20260811-160312.csv
manifest.csv        ->  manifest-20260811-155841.csv
```

Rotating twice in the same second appends `-2`, `-3`, … so nothing is ever overwritten.

To skip the question, set it in `config.ini` or pass it on the command line:

```ini
ExistingResults = Prompt      ; Prompt (default) | Resume | Restart
```

```powershell
Run-Import.bat -ExistingResults Restart
```

Two behaviours worth knowing:

- **`Run-Apps.bat` asks once for the whole batch.** It checks every application's folder up
  front and applies your single answer to all of them, so a twelve-application wave doesn't stop
  twelve times. The importer is always handed an explicit answer and never prompts mid-run.
- **Non-interactive runs never block.** A scheduled task, or any run with input redirected,
  continues rather than waiting for an answer nobody is there to give, and logs that it did.
  Pass `-ExistingResults Restart` explicitly if an unattended run should start clean.

A typical first pass on a new application, start to finish:

```powershell
# 1. See what's there - writes manifest.csv, imports nothing   (MODE = MANIFEST)
.\Import-VaultSubmissions.ps1 -GenerateManifest

# 2. Resolve every submission id for real, still importing nothing
.\Import-VaultSubmissions.ps1 -WhatIf

# 3. Set MODE = IMPORT in config.ini, then import a random 10% and read the results CSV
.\Import-VaultSubmissions.ps1 -SamplePercent 10

# 4. Import the rest - anything already SUCCESS is skipped
.\Import-VaultSubmissions.ps1
```

Steps 1 and 2 need no edit: `-GenerateManifest` and `-WhatIf` override `MODE` from the command
line. Turning a real import **on** is the one thing that isn't a switch — it needs
`MODE = IMPORT` in `config.ini` (or `Run-Apps.bat`), which is deliberate: nothing you can type
by accident starts importing.

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

MODE            = MANIFEST   ; MANIFEST | DRYRUN | IMPORT
SamplePercent   =            ; blank = all of them; 1-100 = a random sample
ExistingResults = Prompt     ; reports already there: Prompt | Resume | Restart

ApiVersion = v26.2
SessionId  =                 ; blank = log in for me
```

Precedence is **command line → `config.ini` → built-in defaults**, so `Run-Import.bat -WhatIf`
gives a one-off dry run without editing the file — with the caveat that `MODE = MANIFEST` writes
the manifest and stops, so switch `MODE` off `MANIFEST` first. `%USERPROFILE%`-style variables are
expanded, and unknown keys warn by name rather than being silently ignored.

| MODE | What happens |
|---|---|
| `MANIFEST` | List the dossiers, write `manifest.csv`, stop. Nothing imported. |
| `DRYRUN` | Resolve every submission id. Import nothing. |
| `IMPORT` | Do it for real. |

### Sampling — `SamplePercent`

`SamplePercent` takes a whole number 1–100 and processes only that percentage of the
submissions found, chosen at random. Blank or `0` processes all of them. It applies to
whichever `MODE` you're in, so a sampled `MANIFEST`, `DRYRUN` and `IMPORT` all describe the
same kind of subset.

```ini
SamplePercent = 10
```

or, without editing anything, `Run-Import.bat -SamplePercent 10`.

- **Rounded up.** 10% of 11 submissions is 2, not 1 — a small percentage of a small
  application never selects nothing.
- **Fresh sample every run.** It is not a stable subset: running twice at 10% gives two
  independent draws that may overlap. Sampling is for spot-checking, not for splitting a
  wave into chunks — to do that, run the whole application and let the skip logic work.
- **Loud in the log.** The selected folder names are printed up front and the summary ends
  with a `SAMPLE n%` line, so a sampled run can't be mistaken for a full one.
- **Safe to repeat.** Submissions already recorded `SUCCESS` are still skipped, and results
  from earlier runs are carried forward rather than overwritten — a 10% run never erases
  the record of the other 90%.

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

To sample, set `SAMPLE` next to `MODE` at the top of `Run-Apps.bat`:

```bat
set "MODE=DRYRUN"
set "SAMPLE=10"
```

That takes a random 10% of **each** application in `apps.txt` — every app is still visited,
each one partially — which is what you want for a spot-check across a wave.

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
skips anything already `SUCCESS`. Rows an earlier run wrote for dossiers this run didn't touch —
skipped, or not picked by `SamplePercent` — are carried through, so the file accumulates the
whole application rather than being replaced by whatever the last run happened to cover. A
re-processed dossier is replaced where it already sat, so the file keeps its order run to run.

That accumulation is what you're choosing between in the
[continue-or-restart](#continuing-or-starting-fresh) prompt: continuing adds to this file,
restarting rotates it aside and begins a new one.

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
