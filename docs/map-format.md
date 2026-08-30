# The id map

*Updated 2026-08-30 07:20 EDT*

What relates a document in the source vault to the document it became in the target. It
is the spine of the attachment sync, the roles repair and the migration validation — so
every one of those is only as good as this file.

## Canonical form

```csv
source_id,target_id
55056,207311
55057,207312
```

- **UTF-8**, with or without a byte order mark.
- **Comma** separated.
- A **header row**, naming the two columns `source_id` and `target_id`.
- **One pair per row.** Ids are digits only.
- Extra columns are allowed and ignored.

A file in this shape needs no detection: the kit reads the two named columns and moves
on. `map write` produces it, and `verify map` writes it when the pairs are derived from
the vault.

## What else is accepted

A real map arrives as whatever produced it, and refusing it would only move the work to a
person. So anything below is read, and what was decided is said out loud:

| arrives as | handled |
| --- | --- |
| tab, semicolon or pipe separated | delimiter detected from the header |
| Excel's "CSV UTF-8" byte order mark | stripped — otherwise `source_id` arrives as a name nothing matches |
| headers written for people — `Source (old) Document ID` | matched on meaning: a column naming an **id** and one of source/old/from/legacy, against destination/target/new/to |
| a repeated column name — two `Created By` | suffixed, so `Import-Csv` does not refuse the sheet |
| a row per file, so one document appears eight times | repeats collapsed and counted |
| `#N/A` where a lookup found nothing | skipped, counted, and named in the log |

If the header wording defeats detection, name the columns:

```
.\vault.ps1 map check -SourceColumn "Old Doc" -TargetColumn "New Doc"
```

## What is refused

Two things are errors rather than warnings, because both silently drop documents while
the run still reports success:

**Scientific notation.** Excel turns a long number into `5.5283E+04` on export and the
digits are gone — they cannot be recovered from the file. Re-export with both id columns
formatted as Text.

**One source pointing at two targets.** Choosing between them is not something a tool can
do. Fix the map.

## Checking it

```
.\vault.ps1 map check
```

**Needs no vault.** This is a question about a file, and it is the question you have
*before* a run rather than during one — so it is answerable with no credentials and no
network. It reports the encoding, the delimiter, which columns it used and how it chose
them, how many rows and pairs, how many repeats, and how many rows were skipped. It exits
non-zero if anything was skipped, because a skipped row is a document nobody migrates.

```
.\vault.ps1 map write -OutFile map.csv
```

Rewrites whatever arrived into the canonical form. Point `[verify] map` at the result and
nothing downstream has to guess again — which also means the next person to read the file
does not have to work out which column was which.

## Deriving it instead

A map is a record of what somebody *intended*. It goes stale the moment anyone loads a
document outside it, and it is silent about exactly the documents you would most want to
hear about. If the load wrote the source id onto a field of the target document, the vault
holds a better answer:

```
.\vault.ps1 verify anchors             which field, if any, relates the two vaults
.\vault.ps1 verify map -Anchor <field>   build the pairs from the vault itself
```

`anchors` reports each candidate field, how many documents carry a value, and how many of
those values are source ids the current map knows — a field that is populated but matches
nothing is worse than no field, because it looks like an anchor. `verify map` then writes
the canonical form, and flags any source id claimed by two target documents, which means
a load ran twice.
