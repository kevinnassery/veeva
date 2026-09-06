# Load a submissions application

*Updated 2026-09-06 13:26 EDT — pinned to `48e9e00`, version `2026.09.06-10`*

One application per run. The dossiers are already on File Staging; nothing is uploaded.

**If any step does not match what is written here, stop and send the log file** from
`C:\vault-work`. Do not improvise past it.

---

## 1. Open PowerShell and allow scripts

```powershell
cd C:\vault-work
```

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

It asks a question. **Type `Y` and press Enter.** Pressing Enter alone answers No.

```powershell
Get-ExecutionPolicy -Scope Process
```

Must print `Bypass`. If it prints anything else, repeat this step.

---

## 2. Update, and check the version

```powershell
.\vault.ps1 update -Commit 48e9e00f81e77c56b1de0254728b72c7ddd2197b
```

```powershell
.\vault.ps1 version
```

Must print `2026.09.06-10`. **Anything else: stop.**

Ignore any line telling you to fill in `[vault] source` and `target`, or to run
`vault.ps1 login`. Neither applies here.

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

---

## 4. Plan the run

```powershell
.\vault.ps1 submissions import -Plan
```

Imports nothing. Then:

```powershell
Import-Csv .\submission-import-results.csv | Group-Object Status | Select-Object Count, Name
```

**Every row must say `WOULD_IMPORT`. If any row says anything else, stop** and send
`submission-import-results.csv` and the log.

---

## 5. Import one

```powershell
.\vault.ps1 submissions import -Test 1
```

Imports one dossier and stops. Check it in Vault before continuing.

---

## 6. Import the rest

```powershell
.\vault.ps1 submissions import
```

Leave the window open. Safe to stop with Ctrl-C and re-run — it skips what is done.

Then:

```powershell
Import-Csv .\submission-import-results.csv | Group-Object Status | Select-Object Count, Name
```

| status | do |
| --- | --- |
| `SUCCESS` | nothing — it is imported |
| `TIMEOUT_AFTER_<n>_MIN` | re-run step 6 |
| anything else | **stop**, send the CSV and the log |

---

## 7. Finish

```powershell
.\vault.ps1 logout
```

To load another application, go back to step 3 and answer `n` when it shows you this one.

---

## If something goes wrong

| what you see | do |
| --- | --- |
| `running scripts is disabled on this system` | step 1 again, answer `Y` |
| `>>` instead of a normal prompt | press Ctrl-C, paste **one** command at a time |
| version is not `2026.09.06-10` | step 2 again |
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
curl.exe -sfLO https://raw.githubusercontent.com/kevinnassery/veeva/48e9e00f81e77c56b1de0254728b72c7ddd2197b/vault.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\vault.ps1 update -Commit 48e9e00f81e77c56b1de0254728b72c7ddd2197b
```

Then start at step 1.
