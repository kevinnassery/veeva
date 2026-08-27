# Veeva Vault — attachment sync

*Updated 2026-08-27 19:22 EDT*

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
curl.exe -sLO https://raw.githubusercontent.com/kevinnassery/veeva/main/attachments/attachments.ini
```

Put `map.csv` in the same folder — a header row plus the old and new document id columns,
exported from Excel. It defines which documents are in scope.

In `attachments.ini` fill in `SourceVaultDNS`, `TargetVaultDNS`, `TargetPath`,
`OutputRoot`. Leave the session ids blank.

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
| `-Test` | stop after 5 are reconciled |
| `-WhatIf` | rehearse, write nothing |
| `-MaxDocuments 50` | cap the documents examined |
| `Mode = ATTACH` | finish files a stopped run had staged |

## Worth knowing

Attachments match by **filename**, because that is Vault's own rule — a name that already
exists becomes a new *version*. Same name with a different MD5 is reported `DIFFERS` and
left alone unless `ReplaceDiffering` is set.

Each file goes source vault → workstation → target File Staging → attached. One file on
disk at a time. Results are written after every attachment, so any run can be stopped and
re-run.

`Workers` starts at 1. Raise it once a sequential run is known good.

## Reference

| | |
| --- | --- |
| Scripts and config | [`attachments/`](attachments/) |
| Vault API v26.2, offline | [`docs/api/`](docs/api/INDEX.md) |
| Document transfer, complete | [`document-transfer/`](document-transfer/) |
