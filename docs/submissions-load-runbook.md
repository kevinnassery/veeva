# Loading a submissions application — step by step

*Updated 2026-09-06 12:27 EDT*

Copy and paste, one step at a time. Every command is safe to re-run.

This imports the dossiers of **one application** from a vault's File Staging into its RIM
Submissions Archive. Nothing is downloaded and nothing is uploaded — each dossier is
imported from where it already sits, so this touches one vault and never puts a dossier on
the workstation.

Every application folder and vault name below is a **placeholder**. Substitute your own.

| placeholder | what to put there |
| --- | --- |
| `your-vault-sbx.veevavault.com` | the vault instance you are importing **into** |
| `000000` | the application number, which is also the staging folder name |
| `/SubmissionsArchive` | the archive root, if yours is named differently |

---

## Before you start

- Windows, with **Windows PowerShell 5.1** — the one in the Start menu. Not PowerShell 7.
- A Vault account on the target instance with the RIM Submissions Archive import permission.
- The dossiers already on that vault's File Staging, under `/SubmissionsArchive/000000`.

Confirm the PowerShell version first. Copy this into a PowerShell window:

```powershell
$PSVersionTable.PSVersion
```

Expect `5` in the Major column.

---

## Step 1 — Make a working folder

Everything the run writes — scripts, config, logs, results — stays in this one folder.

```powershell
mkdir C:\vault-work
cd C:\vault-work
```

Already have one from a previous wave? Use it. Step 2 will not overwrite your config.

When you are done the folder holds two files — `vault.ps1` and `vault.ini` — plus the logs
and results the runs write.

---

## Step 2 — Download the script

`vault.ps1` is the whole tool — one self-contained file, nothing to install.

**This playbook installs one exact version.** Copy the line as it is, commit hash and all:

```powershell
curl.exe -sfLO https://raw.githubusercontent.com/kevinnassery/veeva/ce40dddec8fb29e152ca0349fda0c722448941fd/vault.ps1
```

Then let it fetch the README and a starter `vault.ini`, pinned to the same commit:

```powershell
powershell -ExecutionPolicy Bypass -File .\vault.ps1 update -Commit ce40dddec8fb29e152ca0349fda0c722448941fd
```

It will print the version. **It must say `2026.09.06-4`.** If it says anything else, stop
and ask — you are not running what these steps describe.

`update` never overwrites a `vault.ini` you have already filled in, and it downloads
everything to one side before replacing anything, so a failed update leaves the folder
exactly as it was.

> **Why the hash and not just `main`.** `raw.githubusercontent.com` caches a branch URL
> for about five minutes and ignores no-cache, so downloading from `/main` can hand back
> the *previous* version of a file — which looks exactly like a fix that did not work.
> A commit hash is immutable, so the CDN cannot serve anything else under it. It also
> means this playbook and the code it describes cannot drift apart: re-running the line
> above a year from now installs the same script.

To move to the current version later, run `.\vault.ps1 update` with no `-Commit` — it
resolves the head commit itself and prints the hash it used.

## Step 3 — Allow scripts for this window

Once per PowerShell window. It does not change any machine-wide setting.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

From here the commands are shorter: `.\vault.ps1 <command>`.

---

## Step 4 — Point it at the application

Open the config:

```powershell
notepad .\vault.ini
```

Set two things under `[submissions]` and save:

```ini
[submissions]
vault = your-vault-sbx.veevavault.com
path  = /SubmissionsArchive/000000
```

- **`vault`** is the instance you are importing into. Leave it blank and you will be asked
  in Step 6 — that works too, and it offers to save your answer here.
- **`path`** is the **application folder**. Its children are the submissions — `0000`,
  `0001`, and so on. The last segment of the path *is* the application number; there is no
  second setting for it, because two settings that have to agree are two settings that can
  disagree.

Leave everything else alone for now.

---

## Step 5 — Log in

```powershell
.\vault.ps1 login
```

Enter the account for the target instance. The session is cached in
`.vault-session.json` and reused by the commands that follow.

> `.vault-session.json` holds a live token. Treat it like a password, and run
> `.\vault.ps1 logout` when you are finished for the day.

---

## Step 6 — Confirm the vault and the folder

```powershell
.\vault.ps1 submissions list
```

**Read this block before answering.** File Staging is shared between the instances on a
domain, so the folder you picked looks the same from a sandbox as it does from production
— the path cannot tell you which one you are pointed at.

```
  submissions  your-vault-sbx.veevavault.com
               someone@example.com  userId 11280389  vaultId 8
Is this the vault to import into? [y/N]
```

**`vaultId` is the field to read.** The host names on a domain are near-misses of each
other; the vault id is not, and it comes from the session that will do the writing rather
than from the config.

Answer **`n`** and it asks for a different vault and offers to save it. It does not stop
the run. Wrong vault is the one mistake nothing downstream can catch, so changing your
mind here is meant to be easy.

Then it shows the folder:

```
  staging     /SubmissionsArchive/000000
  application 000000
Is this the right application? [y/N]
```

Then it lists what is actually there and writes `submission-manifest.csv`. This step makes
**no vault writes and runs no VQL** — it answers "did I point it at the right folder"
before anything costs anything.

Check the count against what you expect. `SubmissionId` is blank in that file on purpose;
filling it in needs the vault, which is Step 7.

> If it reports loose files beside the dossiers, or `0 dossiers`, the path is pointed one
> level too high or too low. An application folder that lists nothing is the commonest way
> a run does nothing and reports success.

---

## Step 7 — Plan the run

```powershell
.\vault.ps1 submissions import -Plan
```

**This is the pass that matters.** Resolving a submission id is read-only, so a plan run
does the entire lookup for real and imports nothing. Every `ERROR` row here is a dossier
that would fail the same way for real, found now instead of part way through a wave.

Open the results:

```powershell
Import-Csv .\submission-import-results.csv | Group-Object Status | Select-Object Count, Name
```

You want every row `WOULD_IMPORT`. Investigate anything else before continuing:

| row | what it means |
| --- | --- |
| no record matched | the folder name is not a submission on this vault — or you are on the wrong vault |
| two records matched | the name does not identify one; the log names both |
| application not resolved | the folder name is not an application number on this vault |

---

## Step 8 — Import one, and look at it

```powershell
.\vault.ps1 submissions import -Test 1
```

One dossier, then stop. Go and look at it in Vault before committing to the wave. An
import is an asynchronous **job**: the run starts it and waits, so this takes as long as
Vault takes.

---

## Step 9 — Run the wave

```powershell
.\vault.ps1 submissions import
```

Anything already `SUCCESS` is skipped, so this picks up where Step 8 left off, and the
command is safe to re-run after an interruption.

This one is deliberately **sequential** and has no `-Workers`. Eight parallel processes
would queue eight jobs on the same vault rather than finishing eight times sooner.

Leave the window open. If you must stop it, Ctrl-C is safe — re-run this same command.

---

## Step 10 — Account for every dossier

```powershell
Import-Csv .\submission-import-results.csv | Group-Object Status | Select-Object Count, Name
```

| status | meaning |
| --- | --- |
| `SUCCESS` | imported |
| `TIMEOUT_AFTER_<n>_MIN` | **not a failure** — the job is still running in Vault. Re-run to pick it up |
| `ERROR` | read the row's message and the log |

The run log and a stamped copy of the results are in the same folder, sharing a timestamp.
Keep both — they are the record of what this wave did.

---

## When you are done

```powershell
.\vault.ps1 logout
```

---

## If something goes wrong

**"Is this the right application?" shows a folder from last wave.** You answered `y` to a
saved value. Answer `n`, or edit `[submissions] path`.

**Everything errors with the same message.** Almost always the wrong vault or the wrong
application, not the dossiers. Re-run Step 6 and read the `vaultId`.

**A folder named `VFMTemp`.** That is Vault File Manager's own scratch folder. It is
skipped by name and needs nothing from you.

**`export_results.csv` sitting beside the dossiers.** The run warns that it does **not**
read it — submissions resolve by folder name and application via VQL. The file is
harmless; the warning is there so it does not look like it was consulted.

**The results CSV is open in Excel.** Preflight stops the run rather than discovering it
after the imports have happened. Close Excel and re-run.

**You are not sure which version you ran.** Every run logs it on the first line, and
`.\vault.ps1 version` prints it on its own. This playbook is written against
**`2026.09.06-4`**, commit `ce40dddec8fb`. To get back to exactly that, re-run the
`update -Commit` line in Step 2.

---

## What this does not do

- It does not move files. The dossiers must already be on that vault's File Staging.
- It does not load documents. That is `documents stage`, a different workflow.
- It does one application per run. For several, repeat from Step 4 with the next
  application number.
