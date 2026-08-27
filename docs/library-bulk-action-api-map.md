# Automating the Library bulk action ("Insert Product for Document Extraction")

Maps the RIM Library UI flow — saved view → bulk action → Refine Selection → Choose Action →
Edit Details → Confirmation — onto Vault API v26.2 endpoints. Every page cited here is mirrored
under [`docs/api/`](api/INDEX.md).

All paths are relative to `https://<VaultDNS>/api/v26.2`.

## 1. Session

| Step | Endpoint |
| --- | --- |
| Log in | `POST /auth` |
| Keep alive / end | `POST /keep-alive`, `DELETE /session` |

The `Authorization` header pattern is already implemented in `Invoke-VaultApi`
(`Import-VaultSubmissions.ps1`), including the `X-VaultAPI-BurstLimitRemaining` backoff.

## 2. Reproduce the saved view

**There is no API for saved views.** Saved views, their filters, and the grid's
*Export → Text/Excel* are UI-only. Re-express the filters as VQL:

`POST /query` (`Content-Type: application/x-www-form-urlencoded`, body `q=...`)

```sql
SELECT id, name__v, type__v, major_version_number__v, minor_version_number__v
FROM documents
WHERE product__v = '00P1110'
  AND type__v != 'Migrated Document'
  AND type__v != 'Audit Trail'
  AND type__v != 'Submissions Archive'
```

VQL gotchas that bite when translating UI filters:

- **`NOT IN` does not exist.** `NOT` is only valid inside a `FIND` clause
  ([logical operators](api/vql/operators/logical-operators.md)). "Document Types not in (…)"
  becomes a chain of `type__v != '…' AND …`.
- **`IN` is not a value list** — it only works as an inner-join subquery. Use `CONTAINS (…)`
  for OR-of-values ([comparison operators](api/vql/operators/comparison-operators.md)).
- **Document queries match on field *labels* by default**, which is why the excluded types
  are spelled the way the UI spells them. `TONAME()` switches to field names, but it only
  works on `lifecycle__v`, `status__v`, `type__v`, `subtype__v`, `classification__v` and
  picklist fields ([TONAME()](api/vql/functions-options/toname.md)) — **not** on object
  references like `product__v`, which you filter by record id.
- **Binder filter** — `binder__v` is a *pseudo-field* documented on
  [Retrieve Documents](api/vault-api/api-reference/26.2/documents/retrieve-documents.md), not a
  VQL-queryable field. Confirm against `GET /metadata/objects/documents/properties` before
  relying on it; otherwise exclude binder document types explicitly.
- Paging: `pagesize` (max 1000) / `pageoffset`, and follow `next_page` in the response.
  The UI showing "1-25 of about 5200 / 100+ pages" is just grid paging.

Field and type discovery:

| Need | Endpoint |
| --- | --- |
| Editable document fields (look for `editable:true`) | `GET /metadata/objects/documents/properties` |
| Document types / subtypes | `GET /metadata/objects/documents/types` |
| `product__v` record ids to write | `POST /query` → `SELECT id, name__v FROM product__v` |

## 3. Bulk edit field values (the "Insert Product" part)

`PUT /objects/documents/batch` — [Update Multiple Documents](api/vault-api/api-reference/26.2/documents/update-documents/update-multiple-documents.md)

```
curl -X PUT -H "Authorization: {AUTH}" -H "Content-Type: text/csv" -H "Accept: text/csv" \
  --data-raw 'id,product__v
771,00P1110
772,00P1110' \
  https://<VaultDNS>/api/v26.2/objects/documents/batch
```

- **Max batch size is 1,000** — which is exactly why the UI offers "First 1000 Documents".
  ~5200 matches means six batches.
- Latest version only. Past versions need `PUT /objects/documents/{doc_id}/versions/{maj}/{min}`.
- To clear a value, send the field with `null`.
- `X-VaultAPI-MigrationMode` / `X-VaultAPI-NoTriggers` exist if you need to bypass doctype
  triggers during a migration-style load.

## 4. Start Workflow (the other bulk action)

| Step | Endpoint |
| --- | --- |
| List available document workflows | `GET /objects/documents/actions` |
| Workflow parameters | `GET /objects/documents/actions/{workflow_name}` |
| Initiate on a set of documents | `POST /objects/documents/actions/{workflow_name}` |
| Single-doc lifecycle user action | `PUT /objects/documents/{doc_id}/versions/{maj}/{min}/lifecycle_actions/{name__v}` |

## 5. Document extraction (files and text)

| Step | Endpoint |
| --- | --- |
| Export documents to file staging | `POST /objects/documents/batch/actions/fileextract` |
| Same, specific versions | `POST /objects/documents/versions/batch/actions/fileextract` |
| Poll the job | `GET /services/jobs/{job_id}` |
| Export results manifest | `GET /objects/documents/batch/actions/fileextract/{jobid}/results` |
| Download the staged files | `GET /services/file_staging/items/content/{path}` |
| Single version's extracted text | `GET /objects/documents/{doc_id}/versions/{maj}/{min}/text` |

Query params on `fileextract`: `source` (default `true`), `renditions`, `allversions`, `text`.
`text=true` is the one to use if "extraction" means pulling document text rather than files.

## 6. Alternative: Vault Loader

The **Loader** tab in the UI nav is the same work, driven from file staging CSVs. Useful above a
few thousand rows because you upload once instead of chunking 1,000-row PUTs.

| Step | Endpoint |
| --- | --- |
| Bulk load/update | `POST /services/loader/load` |
| Bulk extract | `POST /services/loader/extract` |
| Results / logs | `GET /services/loader/{job_id}/tasks/{task_id}/results` (also `/successlog`, `/failurelog`) |

## Suggested automation shape

1. `POST /auth`.
2. `POST /query` with the VQL above, paging at `pagesize=1000`, collecting `id`s.
3. Chunk to 1,000 and `PUT /objects/documents/batch` with `id,product__v` CSV.
4. Parse the per-row response (`responseStatus` per document) into a results CSV — same
   pattern as `import-results.csv` in this repo.
5. Dry-run first: run step 2 and write the CSV without step 3.

## Implemented

`Invoke-VaultDocumentAction.ps1` + `documents.ini` + `Run-Documents.bat` implement this,
following the same conventions as the submissions importer: one ini file, `MODE`
(REPORT / DRYRUN / UPDATE / EXPORT), session id managed in one place with mid-run re-auth,
burst-limit backoff, resumable results CSV.
