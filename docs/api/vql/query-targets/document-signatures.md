<!-- source: https://general.veevavault.dev/vql/query-targets/document-signatures/ -->
<!-- title: Document Signatures -->

# Document Signatures

You can use the `document_signature__sysr` subquery relationship to query signatures on documents and archived documents. You can only query the `document_signature__sysr` relationship as a subquery in the `SELECT` or `WHERE` clause of a query.

Document archive and the `archived_documents` query target are not available in all Vaults. [Learn more in Vault Help](https://platform.veevavault.help/en/lr/34126).

To retrieve document or archived document signature fields and field properties, use the [Document Signatures API](/vault-api/api-reference/26.2/documents/document-signatures).

Note

You must have the *User: View User Information* permission to retrieve signature data records.

If an Admin has configured the start step for a legacy workflow to capture a signature, `document_signature__sysr` queries return two signature records: one is the expected user signature, and the other is system-managed and can be ignored. The system-managed signature always has a `manifest_signature__sys` value of `false` and a `signature_meaning__sys` value of "start workflow".

## Document Signature Query Examples

The following are examples of standard `document_signature__sysr` queries on documents.

### Document Signature Query (Subquery)

Get metadata for document signatures using a subquery:

Copy to clipboard

```
SELECT id, name__v, (SELECT id, signed_document__sys FROM document_signature__sysr)
FROM documents
```

### Document Signature Query (Filter)

Get metadata for document signatures using a `WHERE` clause:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE id IN (SELECT signed_document__sys FROM document_signature__sysr)
```

### Document Signature Version Query

Use the `ALLVERSIONS` query target option with `document_signature__sysr` to retrieve all signature versions:

Copy to clipboard

```
SELECT id, name__v, (SELECT id, signed_document_major_version__sys, signed_document_minor_version__sys FROM ALLVERSIONS document_signature__sysr)
FROM documents
```
