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

Results are written as the run goes, so any run can be stopped and re-run: ids already
recorded `SUCCESS` are skipped. They are written every 25 documents rather than every
one — saving rewrites the whole file, so saving per document is quadratic and a
sequential run over 15,775 would spend longer writing the CSV than moving files. A hard
kill therefore loses at most 25 rows, and those are simply done again on the next run. That file keeps a fixed name because resume
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

## Is it migrated?

The per-workflow checks each answer their own question. This one answers the question
someone actually asks at the end, which is about a **document** rather than a step —
source document to destination document, and everything that hangs off it.

```
.\vault.ps1 verify trial     a fixed handful at random - proves the check runs
.\vault.ps1 verify sample    sized for a confidence level - evidence about the population
.\vault.ps1 verify census    every mapped document
```

Read-only on both vaults. One row per source/target pair in
`migration-validate-results.csv`, across four dimensions:

| dimension | what it compares |
| --- | --- |
| both documents exist | the pair resolves on both sides at all |
| the file | source document's file against the target document's, by MD5 (`-Depth FAST` compares size only) |
| attachments | by name and MD5, from the listings — nothing is downloaded |
| Sharing Settings | roles present and populated; `-WithRoleRules` also checks them against the lifecycle rules |

`VERIFIED` means every dimension that could be checked passed. A dimension that could not
be checked never counts as a pass — a document whose file has been staged but not yet
loaded reports `PARTIAL` with `NO_FILE_ON_TARGET`, not a clean bill.

**Sizing.** `sample` uses Cochran's formula with the finite population correction, at
p=0.5 — the conservative assumption, and the one that does not require guessing the
failure rate you are trying to measure. For 15,775 documents at 95% confidence and a ±5%
margin that is 376. `-Confidence 90|95|99` and `-Margin <pct>` move it; a tighter margin
costs more documents than a higher confidence does.

**Reproducibility.** Pass `-Seed <n>` and the same seed over the same population selects
the same documents. A sample nobody can reproduce is an anecdote, and "which documents
did you check" is the first question anyone will ask. Every run states its mode, size,
seed and what fraction of the population it covered, and a sample run says out loud that
it does not certify the documents it did not check.

**The map.** The pairs come from `[verify] map` — canonical form is
`source_id,target_id`, and anything Excel produced is read too. `.\vault.ps1 map check`
reports what a map holds and **needs no vault**, so it answers the question before a run
rather than during one. Full specification: [`docs/map-format.md`](docs/map-format.md).

**The anchor.** The pairs come from `[verify] map`. A static map says what somebody
*intended*, goes stale when anyone loads a document outside it, and cannot tell you about
a document it does not mention. If the load wrote the source id onto a field of the target
document, there is a better anchor in the vault itself:

```
.\vault.ps1 verify anchors            which field, if any, relates the two vaults
.\vault.ps1 verify map -Anchor <field>  build the pairs from the vault
```

`anchors` reads the target's document field definitions, queries every candidate, and
reports which are populated and how many of their values are source ids the map knows —
a field that is populated but matches nothing is worse than no field, because it looks
like an anchor.

## Repair the Sharing Settings

A document created through the API or Vault Loader does **not** get the lifecycle's role
assignment rules or the document type's default security applied — Veeva confirms this is
by design — so a migrated document arrives with its Sharing Settings empty. Filling them
in is a separate job from moving the files, and it touches only the **target** vault.

```
.\vault.ps1 roles survey     what is in scope: subtypes, roles, defaults
.\vault.ps1 roles probe      whether a defaults table is needed, and what it should say
.\vault.ps1 roles scope  -WithinHours <n>   which documents the filter selects
.\vault.ps1 roles plan   -WithinHours <n>   who would be added to which role
.\vault.ps1 roles assign -WithinHours <n>   add them
.\vault.ps1 roles verify     prove what the run recorded is on the documents
```

**`-WithinHours` is required** on `scope`, `plan` and `assign`. This command grants people
access to documents, and there is no safe default for how much of the past that should
cover — every answer is a different blast radius and none is the obvious one.

**`-CreatedBy` defaults to `me`**, this session's own user, resolved from the vault in one
call. That is normally the account that created the documents, since the same service user
does the load and the repair — and asking for the id again only creates the chance to type
a different one, which would not fail, it would quietly repair somebody else's documents.
Pass a numeric user id to name a different account. A *name* or email works too, but it
has to be looked up, which means reading every user and group in the vault; an id or `me`
costs nothing.

`-WithinHours` counts back from now, and the cutoff is logged in both local time and the
UTC form the query uses, so there is no ambiguity about which window ran.

Where `[roles] map` is also set, the scope is the **intersection**: only documents the
migration produced *and* this person created in the window. The counts at each stage are
logged, including how many matched the user and window but were not in the map.

The desired state is each document's **lifecycle role assignment rules**, and with
`-WithTypeDefaults` the document type's *Default Settings for New Documents* as well —
which is the combination a migrated document is missing, since neither is applied to
documents created through the API or Vault Loader.

`survey` and `probe` change nothing and take no scope flags, so you can look around
first.

**Resuming.** By default `assign` reads every document in scope, whether or not an
earlier run finished it — reading current state is the honest thing to do, since an
assignment recorded yesterday says nothing about today. Documents already correct come
back `IN_STEP` and are not rewritten, but they are still read, so an interrupted run
costs the whole read again.

`-Resume` skips the ones an earlier run finished:

```
.\vault.ps1 roles assign -WithinHours 12 -DesiredFrom Lifecycle -WithTypeDefaults -Resume
```

A document counts as finished only when **every** row it has says so. `WOULD_ASSIGN` does
not: a plan run writes those to the same file and they mean the opposite — those are
exactly the documents still needing work. `ERROR` and `UNRESOLVED` do not either, since
those are the ones most worth retrying.

What makes skipping safe is `roles verify`, which reads the vault afterwards and says
whether the claims were true. Use `-Resume` to finish a run; use `verify` to believe it.

**Check the filter before spending anything on it.** `roles scope` runs the pre-query and
stops: one VQL call, no document reads, nothing written. It prints the target ids it
selected and records every one of them in `roles-scope-<when>.csv`, because a count is
not a check — *"412 documents matched"* is equally consistent with the right filter and
the wrong one, and only the ids can tell them apart. Every scoped run writes that file,
not just `scope`.

If you already know which documents should come back, hand the list over:

```
.\vault.ps1 roles scope -CreatedBy <user> -WithinHours 24 -ExpectIds expected.txt
```

One id per line. It reports **both** directions, because they mean opposite things: an id
in your list the query did not return means the filter is narrower than you think, and one
the query returned that is not in your list means it is wider. Either way it exits
non-zero and writes `roles-scope-reconcile-<when>.csv` naming every difference. If nothing
matches at all but the ids line up against the *source* column, it says so — a list of
source ids compared against target ids reads as a catastrophically wrong filter when it is
really the wrong column. `assign` never removes anyone and never invents an
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
remaining count by. Each worker also keeps its own log, and they are merged into one
timestamp-ordered file at the end, every line labelled with the worker that wrote it.

**There is a ceiling, and it is not the worker count.** Vault allows 2,000 API calls
every five minutes *per user* — about 6.7 a second. A document costs roughly four calls
on the target, so no number of workers moves more than about 1.7 documents a second.
Eight workers measured 0.93/s, a little over half the allowance. Past the ceiling Vault
delays *every* call by 500ms rather than refusing it, so an over-parallel run does not
fail, it just quietly gets slower.

Every parallel run therefore ends with what Vault actually reported:

```
your-target-vault.veevavault.com  burst remaining 1240, lowest seen 380 of 2000 per 5 min
```

If the lowest stays well clear of zero there is room; if it bottoms out, more workers
will make the run slower rather than faster.

Waits are randomised. Eight workers that all pause for exactly sixty seconds resume in
the same instant and hit the vault together, which is what turns being throttled into
thrashing — so every wait is jittered to between half and one and a half times its base,
and the pause for a low burst allowance is proportional to how little is left rather than
a cliff at one value. When Vault sends `Retry-After` that is honoured as a floor: the
jitter only ever moves it later, never sooner.

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
| The id map, specified | [`docs/map-format.md`](docs/map-format.md) |
| The standalone tools this replaces | [`legacy/`](legacy/) |
