<!-- source: https://general.veevavault.dev/vql/functions-options/ -->
<!-- title: Functions & Options -->

# Functions & Options

Use query functions and query target options to modify returned values or refine your search by bypassing default query behavior.

If a document field is included twice, both by itself and modified by a function, you must [define an alias](/vql/clauses/as) for the function. When querying objects, you can only create an alias with the [LONGTEXT()](/vql/functions-options/longtext) and [RICHTEXT()](/vql/functions-options/richtext) functions.

Note

Unless otherwise stated, if a function is available in the `WHERE` clause, it is also available in the `WHERE clause of a subquery.

When a query includes a function, the [queryDescribe](/vql/references/vql-api-headers#Query_Describe) object includes the `function` field indicating the name of the function.

### Document Versioning & State Options

These options are specifically for querying the `documents` target and managing version or lifecycle state visibility.

| Name | Syntax | Description | API Version |
| --- | --- | --- | --- |
| [`ALLVERSIONS`](/vql/functions-options/allversions-latestversion) | `SELECT {field} FROM ALLVERSIONS documents` | Retrieve fields from all document versions. Can only be used when querying documents. | v8.0+ |
| [`DELETEDSTATE()`](/vql/functions-options/state-functions) | `WHERE status__v = DELETEDSTATE()` | Retrieve fields from all documents in a steady, obsolete, superseded, or deleted state. Can only be used when querying `documents`. | v19.2+ |
| [`OBSOLETESTATE()`](/vql/functions-options/state-functions) | `WHERE status__v = OBSOLETESTATE()` | Retrieve fields from all documents in a steady, obsolete, superseded, or deleted state. Can only be used when querying `documents`. | v8.0+ |
| [`STEADYSTATE()`](/vql/functions-options/state-functions) | `WHERE status__v = STEADYSTATE()` | Retrieve fields from all documents in a steady, obsolete, superseded, or deleted state. Can only be used when querying `documents`. | v8.0+ |
| [`SUPERSEDEDSTATE()`](/vql/functions-options/state-functions) | `WHERE status__v = SUPERSEDEDSTATE()` | Retrieve fields from all documents in a steady, obsolete, superseded, or deleted state. Can only be used when querying `documents`. | v8.0+ |
| [`LATESTVERSION`](/vql/functions-options/allversions-latestversion) | `SELECT LATESTVERSION {field} FROM ALLVERSIONS documents` | Retrieve fields from the latest matching version. Can only be used when querying `documents`. | v8.0+ |

### Search Scopes (`FIND` Clause)

These options are used exclusively within the `FIND` clause to narrow the search area across documents or objects.

| Name | Syntax | Description | API Version |
| --- | --- | --- | --- |
| [`SCOPE ALL`](/vql/functions-options/find-scopes-distance/scope-all) | `FIND ('{search phrase}' SCOPE ALL)` | Search all fields and document content. | v8.0+ |
| [`SCOPE CONTENT`](/vql/functions-options/find-scopes-distance/scope-content) | `FIND ('{search phrase}' SCOPE CONTENT)` | Search document content only. | v8.0+ |
| [`SCOPE {fields}`](/vql/functions-options/find-scopes-distance/scope-fields) | `FIND ('{search phrase}' SCOPE {fields})` | Search one specific document field or up to 25 object fields. | v15.0+ |
| [`SCOPE PROPERTIES`](/vql/functions-options/find-scopes-distance/scope-properties) | `FIND ('{search phrase}' SCOPE PROPERTIES)` | Search all picklists and document or object fields with data type String. This is the default scope. | v8.0+ |

### User-Personalized Filters

These options filter results based on the currently authenticated user's interactions in Vault.

| Name | Syntax | Description | API Version |
| --- | --- | --- | --- |
| [`FAVORITES`](/vql/functions-options/favorites-recent) | `SELECT {fields} FROM FAVORITES {query target}` | Filter results to those the currently authenticated user has marked as a favorite. | [Documents](/vql/functions-options/favorites-recent): v22.2+  [Vault objects](/vql/functions-options/favorites-recent): v23.2+ |
| [`RECENT`](/vql/functions-options/favorites-recent) | `SELECT {fields} FROM RECENT {query target}` | Filter results to the 20 documents or object records the currently authenticated user has viewed most recently (in descending order by date). | [Documents](/vql/functions-options/favorites-recent): v22.2+  [Vault objects](/vql/functions-options/favorites-recent): v23.2+ |

### Attachment Field Functions

These functions allow for the retrieval of metadata from files stored in *Attachment* type fields (available in v24.3+).

| Name | Syntax | Description | API Version |
| --- | --- | --- | --- |
| [`FILENAME()`](/vql/functions-options/attachment-field-functions) | `SELECT FILENAME({field}) FROM {query target}`  `WHERE FILENAME({field}) {operator} {value}`   `FIND ('{search phrase}' SCOPE FILENAME({field}))`   `ORDER BY FILENAME({field})` | Use the file name of an *Attachment* field file instead of the file handle. | v24.3+ |
| [`FILESIZE()`](/vql/functions-options/attachment-field-functions) | `SELECT FILESIZE({field})` | Retrieve the file size, MIME type, or MD5 checksum of an *Attachment* field file. | v24.3+ |
| [`MIMETYPE()`](/vql/functions-options/attachment-field-functions) | `SELECT MIMETYPE({field})` | Retrieve the file size, MIME type, or MD5 checksum of an *Attachment* field file. | v24.3+ |
| [`MD5CHECKSUM()`](/vql/functions-options/attachment-field-functions) | `SELECT MD5CHECKSUM({field})` | Retrieve the file size, MIME type, or MD5 checksum of an *Attachment* field file. | v24.3+ |

### Field Formatting & Transformation

These functions modify how field values are compared or returned in the result set.

| Name | Syntax | Description | API Version |
| --- | --- | --- | --- |
| [`CASEINSENSITIVE()`](/vql/functions-options/caseinsensitive) | `WHERE CASEINSENSITIVE({field}) {operator} {value}` | Bypass case sensitivity of fields in the `WHERE` clause. | v14.0+ |
| [`LONGTEXT()`](/vql/functions-options/longtext) | `SELECT LONGTEXT({field}) FROM {query target}` | Retrieve the full value of a Long Text field | v17.1+ |
| [`RICHTEXT()`](/vql/functions-options/richtext) | `SELECT RICHTEXT({field}) FROM {query target}` | Retrieve the full Rich Text field value with HTML markup. | v21.1+ |
| [`STATETYPE()`](/vql/functions-options/statetype) | `WHERE state__v = STATETYPE('{state_type}')` | Retrieve object records in a specific object state type. | v19.3+ |
| [`TODISPLAYFORMAT()`](/vql/functions-options/todisplayformat) | `SELECT TODISPLAYFORMAT({field}) FROM {query target}` | With `SELECT`, retrieve a field’s formatted value instead of the raw value. | v23.2+ |
| [`TOLABEL()`](/vql/functions-options/tolabel) | `SELECT TOLABEL({field}) FROM {query target}`  `WHERE TOLABEL({field}) {operator} {value}` | With `SELECT`, retrieve the object field label instead of the name.  With `WHERE`, filter by the object field label instead of the name. | v24.1+ |
| [`TONAME()`](/vql/functions-options/toname) | `SELECT TONAME({field}) FROM documents`  `WHERE TONAME({field}) {operator} {value}` | With `SELECT`, retrieve the document field name instead of the label.  With `WHERE`, filter by the document field name instead of the label. | v20.3+ |
