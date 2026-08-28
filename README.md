# Veeva Vault — migration tools

*Updated 2026-08-28 13:53 EDT*

Two jobs, each safe to run repeatedly because each compares before it acts:

- **Attachment sync** — copies document attachments from one Vault to another, delivering
  only what the target is missing.
- **Sharing settings** — fills in the document roles a migration left empty. Documents
  created through the API or Vault Loader do not get users populated into their Sharing
  Settings the way UI-created documents do, so migrated documents arrive with their roles
  unfilled. [`oneshot/veeva-roles.ps1`](oneshot/veeva-roles.ps1) puts them back.

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

One file, nothing to install, no ini, no `refresh.bat`. Fetch it into whatever folder you
want to work in and run it:

```
cd /d %USERPROFILE%
```

```
curl.exe -sfL -H "Accept: application/vnd.github.raw" -o veeva-roles.ps1 "https://api.github.com/repos/kevinnassery/veeva/contents/oneshot/veeva-roles.ps1?ref=oneshot"
```

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File veeva-roles.ps1 -Probe
```

The `-ExecutionPolicy Bypass` is not optional — a downloaded `.ps1` will not run without
it, and double-clicking one opens Notepad.

The first run asks for the vault and your Vault login, and caches both in
`.vault-session.json` beside the script, so probing, planning and assigning do not each
stop to ask. Later runs offer the cached host back as the prompt default, so the vault
you are about to write to is on screen and Enter accepts it. The session is checked
against the vault before being trusted, and a dead one just means logging in again. **That file is a bearer token** — whoever holds it acts as you
until Vault expires it. It is ACL'd to your account, but it is not encrypted. Run
`veeva-roles.ps1 -Logout` when you are done.

Swap `ref=oneshot` for `ref=main` once this is merged.

### Why that URL and not the obvious one

**Do not fetch this from `raw.githubusercontent.com/…/main/…`.** That caches for five
minutes and ignores `no-cache`, so right after a fix is pushed it hands back the
*previous* file — which looks exactly like a fix that did not work, and costs an hour
chasing a bug that was already dead.

The contents API above is a different host with its own cache: 60 seconds, revalidated
against an ETag. One request, no SHA to juggle, and always effectively current. It is
rate-limited to 60 requests an hour from one address, which is not a constraint for a
file you fetch when it changes.

To pin to one exact version — worth doing when two people need to be demonstrably running
the same code rather than merely the latest:

```
curl.exe -sfL -o veeva-roles.ps1 https://raw.githubusercontent.com/kevinnassery/veeva/954bf06b95971570998be3e4436bed432c22106c/oneshot/veeva-roles.ps1
```

A commit URL is immutable, so the CDN can cache it as long as it likes and still only ever
have one answer. Either way, `veeva-roles.ps1 -Version` prints what you actually have,
with no vault and no login.

`-Probe` asks only for the vault and your login — it writes nothing, so it will survey a
sample of the vault on its own if you give it no scope. Give it one and it surveys all of
it, because a survey that looked at 25 of 577 documents can miss a subtype entirely and
then report that everything is consistent.

`-Plan` and the assign run always need a scope; neither will ever default to "the whole
vault".

### The map is optional

This job only ever touches the **target** vault, so the map's source-id column is unused —
only the target ids matter. Anything that names those documents will do, and the vault can
usually name them itself. `-Where` takes a VQL condition, run as
`SELECT id FROM documents WHERE …` and paged through:

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File veeva-roles.ps1 -Probe -Where "created_by__v = 11280389"
```

`created_by__v` set to the account the migration ran as is usually the most exact scope
there is — it is *definitionally* "the documents that were loaded", with no spreadsheet to
keep in step. Narrow it further with a date window or a subtype if the account did more
than one load:

```
-Where "created_by__v = 11280389 AND created_date__v > '2026-08-01T00:00:00.000Z'"
```

`-Map` still works and still takes the same `attachments-map.csv` — two rows pointing at
the same target are one document, not two. Use it when the migration was one batch you
already have a manifest for. Use `-Where` otherwise.

One reason to keep *some* scope rather than sweeping the vault: a document can be missing
a default because someone deliberately removed that group from its sharing settings. This
tool cannot tell that apart from a document the loader never populated, and would put the
group back. Documents the UI created already have their defaults, so they report `IN_STEP`
and nothing happens to them — but a deliberate removal is a real edit, and a scope keeps
you away from it.

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

`-Plan` also reports how many of the direct user assignments it would write are people
*already in a group it is assigning on the same document*. That number matters: a direct
assignment outlives the group, so taking someone out of the group later does not take
away their access. `-Assign Groups` writes only the groups and leaves membership to do
its job.

Assignment is additive and it never removes anyone, so a second run over the same map is
a no-op. Per document and role, `role-results.csv` records what was assigned, what was
already there, and which rule was applied.

| | |
| --- | --- |
| `-Assign Groups` | write only groups, not direct user assignments |
| `-Logout` | delete the cached session |
| `-Where "…"` | enumerate from the vault instead of a map |
| `-Version` | print the version, no vault or login needed |
| `-Limit 5` | cap the documents examined — off by default |
| `-Test 5` | stop once 5 documents have been changed |
| `-Role viewer__v` | only this role |
| `-ExcludeRole owner__v` | leave this role alone |
| `-WhatIf` | rehearse, write nothing |
| `-DesiredFrom Document` | use Vault's own per-document defaults instead of the rules |

## Reference

| | |
| --- | --- |
| Attachment tools | [`legacy/attachments/`](legacy/attachments/) |
| Sharing settings | [`oneshot/veeva-roles.ps1`](oneshot/veeva-roles.ps1) |
| Vault API v26.2, offline | [`docs/api/`](docs/api/INDEX.md) |
| Document transfer, complete | [`legacy/document-transfer/`](legacy/document-transfer/) |
