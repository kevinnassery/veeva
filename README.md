# Veeva Vault RIM tooling

*Updated 2026-08-27 19:21 EDT*

Moves documents and their attachments between Vault instances over the API. Files stream
one at a time, so a 120 GB set needs a few GB of disk. Every run is resumable, writes its
results after each item, and is safe to re-run.

The document transfer is complete — 15,754 documents. Current work is attachments.

---

## Cheat sheet

| I want to... | Run |
| --- | --- |
| Get to the folder everything lives in | `cd /d %USERPROFILE%` |
| Update the scripts | `refresh.bat` |
| Clear out old files first | `starting-cleanup.bat`, then `refresh.bat` |
| Log in once, stop the prompts | `login.bat` |
| Check a vault, change nothing | `probe.bat` |
| See what attachments are missing | `Mode = REPORT`, `attachments.bat` |
| Deliver missing attachments | `Mode = SYNC`, `attachments.bat` |
| Prove it works on 5 first | `attachments.bat -Test` |
| Rehearse without writing | add `-WhatIf` |
| Cap a run | add `-MaxDocuments 10` |
| Start reports clean | add `-ExistingResults Restart` |
| Import submission dossiers | `submissions-import\Run-Import.bat` |

Scripts, configs and `map.csv` all live in your home folder — `cd /d %USERPROFILE%`
gets there from anywhere, and `/d` is what makes it work across a drive change.

Anything after a `.bat` passes through to the script. Settings you want to keep go in
the `.ini`. `refresh.bat` never overwrites an `.ini`, and refuses to run at all while a
transfer is active.

---

## Process: reconcile attachments

Compares both vaults and delivers only what the target is missing, so it is safe to
re-run.

1. Put the id map in `map.csv`, in the folder you run from — a header row plus the old
   and new document id columns, and nothing else needed. It defines which documents are
   in scope, so there is no separate id list. Comma, tab, semicolon or pipe; the
   delimiter and the column names are both detected.
2. Fetch the config once, then copy the shared values across from `transfer.ini`:

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/attachments/attachments.ini
```

3. `Mode = REPORT`, run `attachments.bat`. Nothing changes. Read the gap: how many
   attachments exist, how many are already there, how many are missing.
4. `Mode = SYNC`, run `attachments.bat -Test`. It keeps going until 5 attachments are
   staged *and* attached, however many documents that takes, then stops. Check those 5
   on the target.
5. Clear `MaxDocuments`, drop `-Test`, run `attachments.bat`.

Attachments match by filename, because that is Vault's own rule — a name that already
exists becomes a new *version*. A name present on both sides with a different MD5 is
reported `DIFFERS` and left alone unless `ReplaceDiffering` is set. If a run dies between
staging and attaching, `Mode = ATTACH` finishes without re-downloading.

Start at `Workers = 1`. Raise it once a sequential run is known good.

---

## Reference

| | |
| --- | --- |
| Attachments (current work) | [`attachments/`](attachments/) |
| Document transfer, complete — no longer shipped by `refresh.bat` | [`document-transfer/`](document-transfer/) |
| Submissions importer | [`submissions-import/`](submissions-import/README.md) |
| Vault API v26.2, offline | [`docs/api/`](docs/api/INDEX.md) |
| Why the VQL looks the way it does | [`docs/library-bulk-action-api-map.md`](docs/library-bulk-action-api-map.md) |

Windows PowerShell 5.1 or 7. No modules to install.
