# Veeva Vault — migration tools

*Updated 2026-08-28 13:23 EDT*

Two jobs, each safe to run repeatedly because each compares before it acts:

- **Attachment sync** — copies document attachments from one Vault to another, delivering
  only what the target is missing.
- **Sharing settings** — fills in the document roles a migration left empty. Documents
  created through the API or Vault Loader do not get users populated into their Sharing
  Settings the way UI-created documents do, so migrated documents arrive with their roles
  unfilled. [`veeva-roles.ps1`](veeva-roles.ps1) puts them back.

# Attachment sync

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

# Sharing settings

One file, nothing to install, no ini. Download it and run it:

```
curl.exe -sfL -o veeva-roles.ps1 https://raw.githubusercontent.com/kevinnassery/veeva/main/veeva-roles.ps1
```

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File veeva-roles.ps1 -Probe
```

It asks for the vault, the map CSV and your login. The map is the same
`attachments-map.csv`; its **target** id column names the documents to repair.

Three steps, in order. Nothing is written to Vault until the third.

| | |
| --- | --- |
| `-Probe` | survey the vault — subtypes, roles, and where the defaults come from. Writes nothing |
| `-Plan` | exactly who would be added to which role, per document. Writes nothing |
| *(neither)* | assign them |

Permissions come from each document's **lifecycle role assignment rules**. Where a role
has override rules, the override matching that document's product, country or study wins
over the default, as it does in Vault. Two overrides matching equally well is reported
`UNRESOLVED` and left alone rather than guessed at — and so is a document that could not
be read.

`-Probe` also answers the question the API documentation does not: whether the
`defaultUsers`/`defaultGroups` Vault reports per document carry the document **type's**
default security as well as the lifecycle's rules. It compares the two on live data and
says which case you are in. If the type defaults are not reachable, transcribe the Admin
screen into a small CSV and pass `-Defaults`:

```
role,groups
editor__v,"Business Administrators,Label Authors,Label Editors"
viewer__v,"Regulatory Users,Submission Managers"
consumer__v,"Document Users"
```

Roles, users and groups may be given by API name or by the label the UI shows. A name
that matches nothing in the vault stops the run rather than quietly shrinking a role.
`-Probe` writes `discovered-defaults.csv` in exactly this shape as a starting point —
check it against the Admin screen before using it.

Assignment is additive and it never removes anyone, so a second run over the same map is
a no-op. Per document and role, `role-results.csv` records what was assigned, what was
already there, and which rule was applied.

| | |
| --- | --- |
| `-Limit 5` | cap the documents examined |
| `-Test 5` | stop once 5 documents have been changed |
| `-Role viewer__v` | only this role |
| `-ExcludeRole owner__v` | leave this role alone |
| `-WhatIf` | rehearse, write nothing |
| `-DesiredFrom Document` | use Vault's own per-document defaults instead of the rules |

## Reference

| | |
| --- | --- |
| Attachment tools | [`legacy/attachments/`](legacy/attachments/) |
| Sharing settings | [`veeva-roles.ps1`](veeva-roles.ps1) |
| Vault API v26.2, offline | [`docs/api/`](docs/api/INDEX.md) |
| Document transfer, complete | [`legacy/document-transfer/`](legacy/document-transfer/) |
