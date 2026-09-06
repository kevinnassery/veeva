# Load a submissions application

*Updated 2026-09-06 15:02 EDT — pinned to `61462c6`, version `2026.09.06-14`*

One application per run. The dossiers are already on File Staging; nothing is uploaded.

**If any step does not match what is written here, stop and send the log file** from
`C:\vault-work`. Do not improvise past it.

---

## 1. Open PowerShell and see what you have

```powershell
cd C:\vault-work
```

```powershell
.\vault.ps1 version
```

**If that printed a version** — note it down and go to step 2.

**If it said `... cannot be loaded because running scripts is disabled on this system`** —
do the next three commands, then run `.\vault.ps1 version` again.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

**It asks you to confirm, and the default is No.** Type `Y` and press Enter:

```
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"): Y
```

```powershell
Get-ExecutionPolicy -Scope Process
```

Must print `Bypass`.

```powershell
.\vault.ps1 version
```

This is once per PowerShell window and changes no machine-wide setting.

---

## 2. Update, and check the version

```powershell
.\vault.ps1 update -Commit 61462c616e4f3f7507e022e1f2d32d15ba3f5eb8
```

```powershell
.\vault.ps1 version
```

Must print `2026.09.06-14`. **Anything else: stop.**

Ignore any line telling you to fill in `[vault] source` and `target`, or to run
`vault.ps1 login`. Neither applies here.

**Steps 1 and 2 are once per PowerShell window, not once per application.** Loading
several in a row, start at step 3 each time — see [Loading the next
application](#loading-the-next-application).

---

## 3. List what is there

```powershell
.\vault.ps1 submissions list
```

This writes nothing to Vault. It asks you these, in this order:

| it asks | you type |
| --- | --- |
| `Vault host` | the sandbox host name, no `https://` |
| a credential box | your account on that vault |
| `Is this the vault to import into? [y/n]` | `y` **only if `vaultId` is the sandbox's** — otherwise `n`, and it asks again |
| `Save this to [submissions] vault in vault.ini? [Y/n]` | `Y` |
| `Submissions Archive path` | `/SubmissionsArchive/<application>` |
| `Save this to [submissions] path in vault.ini? [Y/n]` | `Y` |
| `Is this the right application? [y/n]` | `y` if the application number is the one you are loading — otherwise `n` |

Saying `Y` to the two save questions is what makes the next run show your answers back for
a `y` instead of asking for them again.

It ends with a count of dossiers. **If the count is 0, stop.**

Folders that are not submissions — `Correspondence`, Vault's own `VFMTemp` — are
skipped and named in the output, so the count is of real dossiers only.

---

## 4. Check inside the dossiers

Vault imports everything inside a submission folder. If a folder such as
`Correspondence` is sitting in there, it comes in with the submission whether you want it
or not — nothing downstream can filter it, so it has to go before the import.

```powershell
.\vault.ps1 submissions scan
```

Read-only. It looks one level inside every dossier and lists anything that should not be
imported with it.

**If it says `nothing to remove`, go to step 5.**

If it lists folders, remove them:

```powershell
.\vault.ps1 submissions clean
```

It prints every folder it would delete, then asks:

```
  This deletes those folders and everything in them from File Staging.
  It cannot be undone from here.

Type the number 7 to delete them, or anything else to stop:
```

**Read the list first.** Type the number it gives you to go ahead; type anything else and
nothing is deleted. What it removed is recorded in `submission-correspondence.csv`.

Then run `.\vault.ps1 submissions scan` again — it must say `nothing to remove`.

---

## 5. Plan the run

> **Every command from here on confirms the vault and the application first.** Steps 4, 5
> and 6 each start by showing your saved answers back:
>
> ```
> Is this the vault to import into? [y/n]:
> Is this the right application? [y/n]:
> ```
>
> Read them, then type `y` to each. They are shown every time on purpose — this is the
> point at which a wave can be sent at the wrong vault or the wrong application, and it is
> cheaper to read two lines than to undo an import.

```powershell
.\vault.ps1 submissions import -Plan
```

Imports nothing — it only works out which submission record each folder belongs to.

One results file holds every application you have loaded, so **filter it to this one** —
put your application number in place of `000000`:

```powershell
Import-Csv .\submission-import-results.csv | Where-Object { $_.StagingPath -like '*/000000/*' } | Group-Object Status | Select-Object Count, Name
```

**Every row must say `PLANNED`.** The run's last lines state the sum — resolved, plus
any already imported by an earlier run — and it must equal the dossier count from
step 3. If the tool says anything is unexplained, **stop**.
Anything else — `ERROR`, or a smaller count — **stop** and send
`submission-import-results.csv` and the log.

Then check *how* each one was matched:

```powershell
Import-Csv .\submission-import-results.csv | Where-Object { $_.StagingPath -like '*/000000/*' } | Group-Object MatchedBy | Select-Object Count, Name
```

| `MatchedBy` | do |
| --- | --- |
| `exact name` | nothing, this is normal |
| `name prefix` | nothing, this is normal — folder `0000` matched `0000 - Something` |
| anything starting `serial` | **stop and send the CSV.** The folder name did not match any submission name, so it was matched on a serial number instead. Do not import these without someone checking them |

---

## 6. Import one

```powershell
.\vault.ps1 submissions import -Test 1
```

Confirm the vault and the application again (`y`, `y`). Imports one dossier and stops. Its row goes from `PLANNED` to `SUCCESS`.

Before continuing, open that application in Vault and confirm the submission is listed
under it. **If it is not there, stop** — whatever the CSV says.

---

## 7. Import the rest

```powershell
.\vault.ps1 submissions import
```

Confirm the vault and the application again (`y`, `y`). Leave the window open. Safe to stop with Ctrl-C and re-run — it skips what is done.

Then, filtered to this application again:

```powershell
Import-Csv .\submission-import-results.csv | Where-Object { $_.StagingPath -like '*/000000/*' } | Group-Object Status | Select-Object Count, Name
```

| status | do |
| --- | --- |
| `SUCCESS` | nothing — it is imported |
| `TIMEOUT_AFTER_<n>_MIN` | not a failure. The job is still running in Vault. Re-run step 7 |
| anything else | **stop**, send the CSV and the log |

**`SUCCESS` must equal the dossier count from step 3.** A clean-looking table with a short
count means dossiers were never attempted, which is the failure that looks most like
success.

---

## 8. Finish

Only when you are finished for the day:

```powershell
.\vault.ps1 logout
```

---

## Loading the next application

Do **not** repeat steps 1 and 2. Go straight to:

```powershell
.\vault.ps1 submissions list
```

It shows the last application back at you:

```
  staging     /SubmissionsArchive/<the one you just did>
  application <the one you just did>
Is this the right application? [y/n]:
```

Answer **`n`**. It asks for the new path, offers to save it (`Y`), and gives the new
dossier count. Then carry on from step 4.

Answer `y` to the vault question before it — that does not change — and you are not asked
for credentials again while the window is open.

---

## If something goes wrong

| what you see | do |
| --- | --- |
| `running scripts is disabled on this system` | step 1, the second half — answer `Y` |
| `>>` instead of a normal prompt | press Ctrl-C, paste **one** command at a time |
| version is not `2026.09.06-14` | step 2 again |
| `0 dossiers` | wrong path — step 3 again, answer `n` at the application question |
| `is not set in ... vault.ini` | run the command from `C:\vault-work` |
| `It is the login that was refused` | host is fine, the account is not. **Do not retry** — repeated attempts lock it. Stop, send the log |
| `Could not reach <host>` then `Try a different vault host? [y/n]` | wrong or unreachable host name. Answer `y` and type it again |
| anything else | stop, send the log |

Log files are in `C:\vault-work`, named `submissions-list-<date>.log` and
`submissions-import-<date>.log`.

---

## First time on a machine

Only if `C:\vault-work\vault.ps1` does not exist.

```powershell
mkdir C:\vault-work
```

```powershell
cd C:\vault-work
```

```powershell
curl.exe -sfLO https://raw.githubusercontent.com/kevinnassery/veeva/61462c616e4f3f7507e022e1f2d32d15ba3f5eb8/vault.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\vault.ps1 update -Commit 61462c616e4f3f7507e022e1f2d32d15ba3f5eb8
```

Then start at step 1.
