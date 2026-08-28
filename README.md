# Veeva Vault — attachment sync

*Updated 2026-08-28 12:08 EDT*

Copies document attachments from one Vault to another. It compares both sides first and
delivers only what the target is missing, so it is safe to run repeatedly.

## Setup

```
cd /d %USERPROFILE%
```

```
curl.exe -sfL -o refresh.bat https://raw.githubusercontent.com/kevinnassery/veeva/main/refresh.bat
```

```
refresh.bat
```

```
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/legacy/attachments/attachments.ini
```

Put `attachments-map.csv` in the same folder — a header row plus the old and new document id columns,
exported from Excel. It defines which documents are in scope.

In `attachments.ini` fill in `SourceVaultDNS`, `TargetVaultDNS` and `OutputRoot`.
Leave the session ids blank.

## Run

```
attachments.bat
```

with `Mode = REPORT` — changes nothing, reports how many attachments exist, how many are
already on the target, and how many are missing.

```
attachments.bat -Test
```

with `Mode = SYNC` — delivers 5, however many documents that takes, then stops. Check
those 5 on the target.

```
attachments.bat
```

with `Mode = SYNC` — delivers the rest.

## Cheat sheet

| | |
| --- | --- |
| `cd /d %USERPROFILE%` | get to the folder |
| `refresh.bat` | update the scripts |
| `starting-cleanup.bat` | set old files aside, then `refresh.bat` |
| `attachments.bat` | run whatever `Mode` says |
| `validator.bat` | prove both sides hold identical files |
| `-Test` | stop after 5 are reconciled |
| `-WhatIf` | rehearse, write nothing |
| `-MaxDocuments 50` | cap the documents examined |

## Verify

```
validator.bat
```

Downloads each attachment from **both** vaults, hashes them, and compares. Changes
nothing. `Mode = FAST` in `attachments.ini` compares the MD5 Vault already records on
each side instead, with no downloads.

Per attachment in `validate-results.csv`: `MATCH`, `MISMATCH`, `MISSING_ON_TARGET`,
`MISSING_ON_SOURCE`. Missing is reported whichever side it is missing from.

`validator.bat -Test` checks five and stops. DEEP is bandwidth-bound, so `Workers = 8`
helps it more than it helps the sync.

## Worth knowing

Attachments match by **filename**, because that is Vault's own rule — a name that already
exists becomes a new *version*. Same name with a different MD5 is reported `DIFFERS` and
left alone unless `ReplaceDiffering` is set.

Each file goes source vault → workstation → attached to the target document, in one
upload. No File Staging is involved and nothing is left behind on either vault. One file
on disk at a time, deleted as soon as it lands. Results are written after every
attachment, so any run can be stopped and re-run.

`Workers` starts at 1. Raise it once a sequential run is known good.

## Reference

| | |
| --- | --- |
| Attachment tools | [`legacy/attachments/`](legacy/attachments/) |
| Vault API v26.2, offline | [`docs/api/`](docs/api/INDEX.md) |
| Document transfer, complete | [`legacy/document-transfer/`](legacy/document-transfer/) |
