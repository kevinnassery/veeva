# Loading a submissions application — step by step

*Updated 2026-09-06 12:55 EDT*

Copy and paste, one step at a time. Every command is safe to re-run.

This imports the dossiers of **one application** from a vault's File Staging into its RIM
Submissions Archive. Nothing is downloaded and nothing is uploaded — each dossier is
imported from where it already sits, so this touches one vault and never puts a dossier on
the workstation.

**These steps assume you already have `C:\vault-work` with `vault.ps1` in it** from a
previous wave. If you are starting on a machine that has never run this, do
[Appendix A](#appendix-a--starting-from-nothing) first — it installs the same version —
then do Step 1 and skip to Step 3.

Every application folder and vault name below is a **placeholder**. Substitute your own.

| placeholder | what to put there |
| --- | --- |
| `your-vault-sbx.veevavault.com` | the vault instance you are importing **into** |
| `000000` | the application number, which is also the staging folder name |
| `/SubmissionsArchive` | the archive root, if yours is named differently |

---

## Before you start

- Windows, with **Windows PowerShell 5.1** — the one in the Start menu. Not PowerShell 7.
- A Vault account on the instance you are importing into, with the RIM Submissions Archive
  import permission.
- The dossiers already on that vault's File Staging, under `/SubmissionsArchive/000000`.

Confirm the PowerShell version. Copy this into a PowerShell window:

```powershell
$PSVersionTable.PSVersion
```

Expect `5` in the Major column.

---

## Step 1 — Allow scripts for this window

Once per PowerShell window. It does not change any machine-wide setting.

```powershell
cd C:\vault-work
Set-ExecutionPolicy -Scope Process Bypass
```

**It will ask you to confirm, and the default is No.** Type **`Y`** and press Enter:

```
Do you want to change the execution policy?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): Y
```

Pressing Enter on its own answers **No**, and every command after this fails with a
message about scripts being disabled. Check it took:

```powershell
Get-ExecutionPolicy -Scope Process
```

It should say `Bypass`. If it says `Undefined`, run the line above again and answer `Y`.

---

## Step 2 — Check your version, then update

**First, what have you got?**

```powershell
.\vault.ps1 version
```

It prints one line, e.g. `2026.09.05-3`. Note it — if anything goes wrong later, the first
question anyone asks is which version was running, and this is the only place the answer is
free.

**Then update to the version these steps describe:**

```powershell
.\vault.ps1 update -Commit 9bd8ac513b93a563529c4a99f533cfb1a1f59886
```

The update ends by naming what it installed:

```
All files at version 2026.09.06-8.
```

**Confirm it yourself** — the update said what it wrote, this asks the script that will
actually run:

```powershell
.\vault.ps1 version
```

**It must print `2026.09.06-8`.** If it does not, stop and ask — you are not running what these
steps describe, and everything below is about a different script.

**Your `vault.ini` is not touched.** `update` replaces `vault.ps1` and `README.md` only,
and it downloads everything to one side before replacing anything, so a failed update
leaves the folder exactly as it was. Nothing you answered on a previous wave is lost.

> **If it mentions a `VaultKit\` folder.** That is from an older layout, where the tool
> shipped as thirteen files. Nothing loads it now — the whole tool is inside `vault.ps1` —
> so you can delete the folder once you are sure nothing of yours is in it. Worth doing:
> editing a file in there changes nothing, which is a confusing thing to discover later.

> **Why the commit hash and not just `main`.** `raw.githubusercontent.com` caches a branch
> URL for about five minutes and ignores no-cache, so an update from `/main` can hand back
> the *previous* version — which looks exactly like a fix that did not work. A commit hash
> is immutable, so the CDN cannot serve anything else under it. It also means this playbook
> and the code it describes cannot drift apart.

To move to the current version some other day, run `.\vault.ps1 update` with no `-Commit`;
it resolves the head commit itself and prints the hash it used.

---

## Step 3 — Confirm the vault and the application

There is no file to fill in. **The tool asks for what it needs and remembers your
answers**, so this step is also the setup step.

```powershell
.\vault.ps1 submissions list
```

It makes **no vault writes and runs no VQL**. It answers "am I pointed at the right folder,
on the right vault" before anything costs anything.

**If you ran a previous wave from this folder**, your answers are already saved. It shows
them back and waits for a `y` on each — so read them, because the last wave's application
is exactly what will be sitting there. Answer **`n`** to either one and it asks for the new
value, then offers to remember that instead. Skip to *"4. Which application"* below for
what that looks like.

**On a machine that has never run this**, it asks four things, in this order.

**1. Which vault.** File Staging is shared between the instances on a domain, so the same
Submissions Archive listing is visible from a sandbox and from production and looks
identical in both — the folder cannot tell you which one you are on. Type the host name,
no `https://`:

```
Vault host: your-vault-sbx.veevavault.com
```

**2. Your credentials.** A Windows credential dialog appears. This is the account on the
vault you just named.

**3. Confirm it is the right one.**

```
  submissions  your-vault-sbx.veevavault.com
               someone@example.com  userId 11280389  vaultId 8
Is this the vault to import into? [y/N]
```

**`vaultId` is the field to read.** The host names on a domain are near-misses of each
other; the vault id is not, and it comes from the session that will do the writing rather
than from anything you typed. Answer **`n`** and it asks for a different vault — it does
not stop the run. Wrong vault is the one mistake nothing downstream can catch, so changing
your mind here is meant to be easy.

Say `y` and it offers to remember it. Say yes.

**4. Which application.** The folder on File Staging whose children are the submissions:

```
  The application folder on the TARGET vault's File Staging, under the
  Submissions Archive root. Its children are the submissions:

      /SubmissionsArchive/000000        <- this
      /SubmissionsArchive/000000/0000
      /SubmissionsArchive/000000/0001

Submissions Archive path: /SubmissionsArchive/000000
```

The last segment **is** the application number — it is not asked for twice, because two
settings that have to agree are two settings that can disagree. It offers to remember this
too, then shows it back for confirmation:

```
  staging     /SubmissionsArchive/000000
  application 000000
Is this the right application? [y/N]
```

Then it lists what is actually there and writes `submission-manifest.csv`. Check the count
against what you expect. `SubmissionId` is blank in that file on purpose — filling it in
needs the vault, which is Step 4.

> **Every run after this one confirms rather than asks.** Your answers are written to
> `vault.ini` beside the script, and each run shows them back and waits for a `y`. To load
> a different application, answer `n` and give the new one; you never edit a file by hand.

> If it reports loose files beside the dossiers, or `0 dossiers`, the path is pointed one
> level too high or too low. An application folder that lists nothing is the commonest way
> a run does nothing and reports success.

---

## Step 4 — Plan the run

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

## Step 5 — Import one, and look at it

```powershell
.\vault.ps1 submissions import -Test 1
```

One dossier, then stop. Go and look at it in Vault before committing to the wave. An
import is an asynchronous **job**: the run starts it and waits, so this takes as long as
Vault takes.

---

## Step 6 — Run the wave

```powershell
.\vault.ps1 submissions import
```

Anything already `SUCCESS` is skipped, so this picks up where Step 5 left off, and the
command is safe to re-run after an interruption.

This one is deliberately **sequential** and has no `-Workers`. Eight parallel processes
would queue eight jobs on the same vault rather than finishing eight times sooner.

Leave the window open. If you must stop it, Ctrl-C is safe — re-run this same command.

---

## Step 7 — Account for every dossier

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

Your session is cached in `.vault-session.json` so the commands above do not ask for
credentials again. **It holds a live token — treat it like a password**, and run `logout`
when you are finished for the day. Your answers in `vault.ini` are not secret and stay put.

---

## If something goes wrong

**"Is this the right application?" shows a folder from last wave.** That is your saved
answer being shown back, which is what it is for. Answer **`n`** and give the new one.
Same for the vault. Nothing needs editing by hand.

**Everything errors with the same message.** Almost always the wrong vault or the wrong
application, not the dossiers. Re-run Step 3 and read the `vaultId`.

**A folder named `VFMTemp`.** That is Vault File Manager's own scratch folder. It is
skipped by name and needs nothing from you.

**`export_results.csv` sitting beside the dossiers.** The run warns that it does **not**
read it — submissions resolve by folder name and application via VQL. The file is
harmless; the warning is there so it does not look like it was consulted.

**The results CSV is open in Excel.** Preflight stops the run rather than discovering it
after the imports have happened. Close Excel and re-run.

**"... cannot be loaded because running scripts is disabled on this system."** Step 1's
prompt was answered No — pressing Enter does that. Run `Set-ExecutionPolicy -Scope Process
Bypass` again and type `Y`.

**`update` says "fill in [vault] source and target".** Older wording, and not for this
workflow. To import submissions there is nothing to fill in: Step 3 asks for the vault and
the application and saves your answers. `[vault] source` and `target` belong to the
document transfer.

**You are not sure which version you ran.** Every run logs it on the first line, and
`.\vault.ps1 version` prints it on its own. This playbook is written against
**`2026.09.06-8`**, commit `9bd8ac513b93`. To get back to exactly that, re-run the
`update -Commit` line in Step 2.

---

## Appendix A — Starting from nothing

Only for a machine that has never run this. If `C:\vault-work\vault.ps1` exists, you want
Step 1 instead.

`vault.ps1` is the whole tool — one self-contained file, nothing to install.

```powershell
mkdir C:\vault-work
cd C:\vault-work
curl.exe -sfLO https://raw.githubusercontent.com/kevinnassery/veeva/9bd8ac513b93a563529c4a99f533cfb1a1f59886/vault.ps1
```

Then let it fetch the README and a starter `vault.ini`, pinned to the same commit. This one
spells out `-ExecutionPolicy Bypass`, because you have not done Step 1 yet:

```powershell
powershell -ExecutionPolicy Bypass -File .\vault.ps1 update -Commit 9bd8ac513b93a563529c4a99f533cfb1a1f59886
```

It must print `2026.09.06-8`. When it is done the folder holds two files, `vault.ps1` and
`vault.ini`, plus whatever the runs write. There is nothing to fill in — go to Step 2, and
Step 3 will ask you for the vault and the application and remember them.

---

## What this does not do

- It does not move files. The dossiers must already be on that vault's File Staging.
- It does not load documents. That is `documents stage`, a different workflow.
- It does one application per run. For several, repeat from Step 3 — answer `n` at
  "Is this the right application?" and give the next application number. You never edit
  a file to change it.
