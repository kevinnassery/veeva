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

Each document gets its own folder under `[documents] path`, named for its **source id** —
two documents called `Cover Letter.pdf` are common, and one overwriting the other after a
twelve-hour transfer is not something to discover afterwards.

Results are written after every document, so any run can be stopped and re-run: ids
already recorded `SUCCESS` are skipped.

## Check it landed

A separate command, run whenever you want — including long after the transfer, and by
someone who did not do it.

```
.\vault.ps1 documents verify              downloads both copies and compares the bytes
.\vault.ps1 documents verify -Depth FAST  compares name and size only
```

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

## Going faster

`[limits] workers` starts at 1. Above 1, the command shards what is outstanding, runs
that many copies of itself, and merges their results into the one file you read. Per
document the time is dominated by round trips rather than bytes, so it scales close to
linearly until Vault's burst limit starts throttling. 4 is a safe starting point **once a
sequential run is known good**.

Workers run hidden, so their warnings and errors are forwarded into the main log as they
happen, and progress is reported every 30 seconds with a rate and an ETA.

`-Workers <n>` overrides the config for one run. `-Test` and `-Plan` always run
sequentially — there is nothing to parallelise, and five documents should be easy to
follow.

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
