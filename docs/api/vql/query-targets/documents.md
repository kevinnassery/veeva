<!-- source: https://general.veevavault.dev/vql/query-targets/documents/ -->
<!-- title: Documents -->

# Documents

Use the `documents` object to query Vault documents.

To retrieve document fields and field properties, use the [Retrieve All Document Fields API](/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-all-document-fields). To retrieve document and binder relationships, use the [Retrieve Document Type Relationships API](/vault-api/api-reference/26.2/documents/document-relationships/retrieve-document-type-relationships).

Query results do not include archived documents by default. In v15.0+, you can use the `archived_documents` object to query archived documents.

Document archive is not available in all Vaults. Learn more in [Vault Help](https://platform.veevavault.help/en/lr/34126).

By default, `documents` and `archived_documents` queries return the latest document version. To retrieve all versions or retrieve the latest version that meets a condition, use the [`ALLVERSIONS`](/vql/functions-options/allversions-latestversion) and [`LATESTVERSION`](/vql/functions-options/allversions-latestversion) query target options.

## Document Query Examples

The following are examples of common document queries.

### Query: Retrieve the Latest Version of a Document

The following query retrieves the ID and latest version number of all documents called “WonderDrug Information”:

Copy to clipboard

```
SELECT id, minor_version_number__v, major_version_number__v
FROM documents
WHERE name__v = 'WonderDrug Information'
```

#### Response: Retrieve the Latest Version of a Document

This response returns the latest version of the document, version 2.2.

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 1,
        "total": 1
    },
    "data": [
        {
            "id": 534,
            "minor_version_number__v": 2,
            "major_version_number__v": 2
        }
    ]
}
```
