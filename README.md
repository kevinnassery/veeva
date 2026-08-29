# Veeva Vault — migration kit

*Updated 2026-08-29 10:45 EDT*

Moves documents and their attachments from one Vault to another. Every command compares
both sides first and delivers only what the target is missing, so a run is safe to repeat.

## Setup

Everything lives in one folder — the scripts, the config, and whatever the runs write.
Make one and work from it.

```
mkdir C:\vault-work
cd /d C:\vault-work
curl.exe -sfLO https://raw.githubusercontent.com/kevinnassery/veeva/main/vault.ps1
powershell -ExecutionPolicy Bypass -File .\vault.ps1 update
```

`update` fetches the rest — the `VaultKit\` module, this README, and a starter
`vault.ini`. It never overwrites a `vault.ini` you have already filled in, and it
downloads everything to one side before replacing anything, so a failed update leaves the
folder exactly as it was.

Then open `vault.ini` and set `[vault] source`, `[vault] target`, and `[documents] path`.

Logs, results and the scratch space all go to `[paths] output`, which defaults to the
folder you are in. `-Out <dir>` moves them for a single run — useful for keeping one
wave's artifacts apart from another's, or for putting the scratch space on a volume with
room on it.

From here on the commands are shorter if you allow scripts once per window:

```
powershell
Set-ExecutionPolicy -Scope Process Bypass
.\vault.ps1 login
```

## Log in

```
.\vault.ps1 login
```

Each vault is asked for separately — a production vault and the vault being migrated
into are two organisations and two accounts. Pass `-Shared` when one account really does
exist on both sides.

Sessions are cached in `.vault-session.json` and reused. Every command re-checks both
sides and shows you who it is before it does anything:

```
  source  your-source-vault.veevavault.com
          someone@example.com  userId 11280389  vaultId 9
  target  your-target-vault.veevavault.com
          someone.else@example.net  userId 40993211  vaultId 8
Are these the right two vaults? [y/N]
```

`-Yes` skips that question. `.vault-session.json` holds live tokens: treat it like a
password, and run `.\vault.ps1 logout` when you are done.

## Move documents

Put one document id per line in `documents-ids.txt`. Then:

```
.\vault.ps1 documents stage -Plan     what would move, changes nothing
.\vault.ps1 documents stage -Test 5   move 5, then stop
.\vault.ps1 documents stage           move the rest
```

Each document goes source vault → workstation → the target's File Staging, and the local
copy is deleted the moment it lands. One file is on disk at a time, so the disk needed is
the size of the largest single document, not the size of the set. Free space is checked
before every download and the run stops rather than filling the volume.

A filename that is not a legal path segment is written under a changed one — a Vault
document really can be called `INO/Ikaria Response ... .pdf`, and File Staging treats the
slash as a folder separator. Only separators, control characters, trailing dots and
spaces, over-long names and Windows device names are touched; colons, parentheses and
apostrophes are left as Vault has them.

Every such change is reported: a warning per document as it happens, a count at the end
of the run, and three columns in the results — `Name` is what Vault calls it,
`StagedName` is what was written, and `Renamed` says whether they differ. To list them:

```
Import-Csv document-results.csv | Where-Object { $_.Renamed -eq 'True' } |
    Select-Object Id, Name, StagedName, TargetPath
```

The validator carries the same column, but reads it against `filename__v`, which Vault
leaves empty for some documents. `Renamed` is **blank** there rather than `False` when
there is no filename to compare — with nothing to compare, "no" is a claim it cannot
make. The transfer's own results are the authoritative list.

Each document gets its own folder under `[documents] path`, named for its **source id** —
two documents called `Cover Letter.pdf` are common, and one overwriting the other after a
twelve-hour transfer is not something to discover afterwards.

Results are written after every document, so any run can be stopped and re-run: ids
already recorded `SUCCESS` are skipped. That file keeps a fixed name because resume
depends on finding it — so each run also drops a stamped copy of its own results,
`document-results-<when>.csv`, sharing a timestamp with its log. The working file gets
merged into and overwritten; the stamped one is the record of what a given run did.

## Check it landed

A separate command, run whenever you want — including long after the transfer, and by
someone who did not do it.

First, what is actually there:

```
.\vault.ps1 documents list
```

Read-only. Counts the document folders and files under `[documents] path`, their total
size, and flags folders holding **no** file (a transfer that made the folder and then
failed) or **more than one** (an earlier run landed a different filename).

Then check them:

```
.\vault.ps1 documents verify -Staged      only what is on the target
.\vault.ps1 documents verify              every id in the list
.\vault.ps1 documents verify -Depth FAST  compares name and size only
```

`-Staged` takes its list from the target vault rather than `documents-ids.txt`. Use it
part way through a wave: verifying the whole input list when only some of it has been
sent reports every document not yet moved as `MISSING_ON_TARGET`, and thousands of rows
saying "not done yet" bury the handful that mean something.

Per document in `document-validate-results.csv`: `MATCH`, `MISMATCH`,
`MISSING_ON_TARGET`, `MISSING_ON_SOURCE`. File Staging's listing reports no checksum of
any kind, so `FAST` can only compare sizes — it catches a truncated or absent file and
nothing subtler. `DEEP` is the one that proves the bytes.

## Move attachments

```
.\vault.ps1 attachments sync -Plan    how many exist, how many are already there
.\vault.ps1 attachments sync -Test 5  deliver 5, then stop
.\vault.ps1 attachments sync          deliver the rest
.\vault.ps1 attachments verify        prove both vaults hold the same bytes
```

Needs `attachments-map.csv` — a header row plus the old and new document id columns,
exported from Excel. It defines which documents are in scope.

Attachments match by **filename**, because that is Vault's own rule: a name that already
exists becomes a new *version*. Same name with a different MD5 is reported and left alone
unless `-ReplaceDiffering` is set. Attachments are attached directly to the target
document in one upload — no File Staging is involved, because an attachment has somewhere
to land the moment it arrives.

## Repair the Sharing Settings

A document created through the API or Vault Loader does **not** get the lifecycle's role
assignment rules or the document type's default security applied — Veeva confirms this is
by design — so a migrated document arrives with its Sharing Settings empty. Filling them
in is a separate job from moving the files, and it touches only the **target** vault.

```
.\vault.ps1 roles survey     what is in scope: subtypes, roles, defaults
.\vault.ps1 roles probe      whether a defaults table is needed, and what it should say
.\vault.ps1 roles plan       exactly who would be added to which role
.\vault.ps1 roles assign     add them
.\vault.ps1 roles verify     prove what the run recorded is on the documents
```

The first three change nothing. `assign` never removes anyone and never invents an
assignment: everything it writes is something the configuration already names as a
default.

Which documents get repaired comes from `[roles] map` — the target id column — or from
`-Where "<VQL condition>"`. `survey` and `probe` will sample the vault if given neither,
and say so; `plan` and `assign` refuse, because guessing the scope of a run that grants
people access is not the same as guessing the scope of one that reads.

`verify` is its own command and is never chained onto `assign`. Vault ignores group ids
it cannot grant **and still answers SUCCESS**, so a run can report an assignment it did
not make — and re-running the assign will not fix it. The run that made the claim is the
last thing that should be trusted to check it.

## Going faster

`[limits] workers` starts at 1. Above 1, the command shards what is outstanding, runs
that many copies of itself, and merges their results into the one file you read. Per
document the time is dominated by round trips rather than bytes, so it scales close to
linearly until Vault's burst limit starts throttling. 4 is a safe starting point **once a
sequential run is known good**.

Workers run hidden, so their warnings and errors are forwarded into the main log as they
happen, and progress is reported every 30 seconds with a rate and an ETA. That rate is
the total across all workers over wall clock, not one worker's — it is what to divide the
remaining count by.

`-Workers <n>` overrides the config for one run. `-Test` and `-Plan` always run
sequentially — there is nothing to parallelise, and five documents should be easy to
follow.

`documents verify` shards the same way, and wants it more: `DEEP` downloads **both**
copies of every document, so a full pass moves twice what the migration did and run
sequentially takes longer than the transfer it is checking. Every call it makes is a
read, on both vaults. Note that each worker holds two files at once, so eight workers is
up to sixteen files on disk rather than two.

## Cheat sheet

| | |
| --- | --- |
| `.\vault.ps1 update` | fetch the latest scripts into this folder |
| `.\vault.ps1 login` | log in to both vaults, cache the sessions |
| `.\vault.ps1 whoami` | who is cached, and how old |
| `.\vault.ps1 probe` | read-only survey of each vault, including staging paths |
| `-Plan` | report what would happen, change nothing |
| `-Test 5` | stop once 5 are genuinely done |
| `-Limit 50` | cap the input examined |
| `-Workers 4` | move the work with 4 processes |
| `-Out <dir>` | put logs, results and scratch somewhere else |
| `-Yes` | skip the vault confirmation |
| `-WhatIf` | rehearse, write nothing to Vault |

## Worth knowing

`[documents] path` has no default. Uploading to the staging **root** is almost never
intended, and uploading into **Inbox** is not neutral — it creates Staged documents. Run
`.\vault.ps1 probe` to get the target user id and whether the account is an Admin there:
Admins give an absolute path like `/u11280389/wave1`, everyone else gives one relative to
their own user folder.

Uploads always go through a resumable session, whatever the file size, so one code path
handles a 2KB email and a 2GB video. Parts stream from disk rather than being held in
memory. A failed upload aborts its session rather than leaving it holding quota.

Downloads are pinned to a commit SHA. `raw.githubusercontent.com` caches the branch URL
for five minutes and ignores no-cache, so pulling from `/main` can hand back the previous
version of a file — which looks exactly like a fix that did not work. `update` resolves
the head commit itself and fetches from that; it prints the SHA, and

```
.ault.ps1 update -Commit <sha>
```

fetches that exact commit instead — to pin a known good set, to roll one back, or to get
a specific version when the branch is being cached. The first `curl` can be pinned the
same way, by putting the SHA where `main` is in the URL.

## Reference

| | |
| --- | --- |
| Vault API v26.2, offline | [`docs/api/`](docs/api/INDEX.md) |
| Library bulk action → API | [`docs/library-bulk-action-api-map.md`](docs/library-bulk-action-api-map.md) |
| The standalone tools this replaces | [`legacy/`](legacy/) |
