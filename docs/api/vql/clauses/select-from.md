<!-- source: https://general.veevavault.dev/vql/clauses/select-from/ -->
<!-- title: SELECT & FROM -->

# SELECT & FROM

The `SELECT` and `FROM` clauses form the basis of most VQL queries and allow you to retrieve field values from Vault. The `SELECT` clause specifies the fields to retrieve. The `FROM` clause indicates the query target from which to retrieve those fields.

You must use the `FROM` clause to specify the query target.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
```

## Functions & Options

You can use the following functions and query target options in the `SELECT` and `FROM` clauses. For a full list of all available functions, see the [VQL Functions & Options](/vql/functions-options) reference.

### Refining Query Scope (`FROM`)

These options are used in the `FROM` clause to modify which records or versions are included in your query results.

| Name | Target | Description | API Version |
| --- | --- | --- | --- |
| [`ALLVERSIONS`](/vql/functions-options/allversions-latestversion) | Documents | Retrieve fields from all document versions. | v8.0+ |
| [`LATESTVERSION`](/vql/functions-options/allversions-latestversion) | Documents | Retrieve fields from the latest version of all documents. | v8.0+ |
| [`FAVORITES`](/vql/functions-options/favorites-recent) | Both | Filter results to records marked as favorites by the currently authenticated user. | v22.2+ |
| [`RECENT`](/vql/functions-options/favorites-recent) | Both | Filter results to the 20 most recently viewed documents or object records. | v22.2+ |

### Formatting Field Outputs (`SELECT`)

These functions are used in the `SELECT` clause to control how field values are returned in the query response.

| Name | Target | Description | API Version |
| --- | --- | --- | --- |
| [`TONAME()`](/vql/functions-options/toname) | Documents | Return the document field name instead of the label. | v20.3+ |
| [`TOLABEL()`](/vql/functions-options/tolabel) | Objects | Return the object field label instead of the name. | v24.1+ |
| [`TODISPLAYFORMAT()`](/vql/functions-options/todisplayformat) | Objects | Return an object field’s formatted value instead of the raw value. | v23.2+ |
| [`LONGTEXT()`](/vql/functions-options/longtext) | Both | Retrieve the full value of Long Text fields. | v17.1+ |
| [`RICHTEXT()`](/vql/functions-options/richtext) | Both | Retrieve the full value (with HTML markup) of Rich Text fields. | v21.1+ |
| [`TRIM()`](/vql/functions-options/trim) | Both | Retrieve a picklist name without the namespace suffix. | v25.1+ |

### Retrieving Attachment Metadata (`SELECT`)

These specialized functions are used to retrieve metadata from Attachment fields.

| Name | Description | API Version |
| --- | --- | --- |
| [`FILENAME()`](/vql/functions-options/attachment-field-functions) | Use the file name of an Attachment field file instead of the file handle. | v24.3+ |
| [`FILESIZE()`](/vql/functions-options/attachment-field-functions) | Retrieve the size of the file in bytes. | v24.3+ |
| [`MIMETYPE()`](/vql/functions-options/attachment-field-functions) | Retrieve the MIME type (e.g., `application/pdf`). | v24.3+ |
| [`MD5CHECKSUM()`](/vql/functions-options/attachment-field-functions) | Retrieve the MD5 hash of the file. | v24.3+ |

## Query Examples

The following are examples of queries using `SELECT` and `FROM`.

### Query: Retrieving All Documents

The following query returns the ID, name, and status of the latest version of all documents in a Vault:

Copy to clipboard

```
SELECT id, name__v, status__v
FROM documents
```

### Response: Retrieving All Documents

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 54,
        "total": 54
    },
    "data": [
        {
            "id": 68,
            "name__v": "Cholecap Akathisia Temporally associated with Adult Major Depressive Disorder",
            "status__v": "Draft"
        },
        {
            "id": 65,
            "name__v": "Gludacta Package Brochure",
            "status__v": "Approved"
        },
        {
            "id": 64,
            "name__v": "Gludacta Logo Light",
            "status__v": "Approved"
        }
  ]
}
```
