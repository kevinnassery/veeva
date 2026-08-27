<!-- source: https://general.veevavault.dev/vql/query-targets/attachments/ -->
<!-- title: Attachments -->

# Attachments

You can use the `attachments__sysr` subquery relationship to query Vault object and document attachments when used as a subquery in the `SELECT` or `WHERE` clause of a query.

The `attachments__sysr` relationship is only supported on objects and documents with attachments enabled.

## Document Attachments

Document and archived document attachments are available for query in v24.1+. You can only query the `attachments__sysr` relationship as a subquery in the `SELECT` or `WHERE` clause.

### Document Attachment Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The `attachments__sysr` relationship allows queries on the following fields:

| Name | Description |
| --- | --- |
| `document_id__sys` | The ID of the document with the attachment. |
| `document_version_id__sys` | The IDs of the document versions with the attachment. For example, `["123_0_1", "123_0_2", "123_1_0"]` for a document with ID 123. This field has a value only when version-specific attachments are enabled in your Vault. Learn more in [Vault Help](https://platform.veevavault.help/en/lr/24287/#version-specific). |
| `attachment_id__sys` | The unique attachment ID. |
| `attachment_name__sys` | The name of the attachment. |
| `attachment_external_id__sys` | The external ID (`external_id__v`) value of the attachment, if provided when creating the attachment. |
| `attachment_version__sys` | The attachment version. |
| `file_name__sys` | The filename of the attachment. |
| `description__sys` | The description of the attachment. |
| `md5checksum__sys` | The MD5 checksum for the attachment. |
| `latest_version__sys` | Boolean indicating whether this is the latest version of the attachment. |
| `created_date__sys` | The date the attachment was created. |
| `created_by__sys` | The ID of the user who created the attachment. |
| `modified_date__sys` | The date the attachment was last modified. |
| `modified_by__sys` | The ID of the user who last modified the attachment. |
| `format__sys` | The file format of the attachment. |
| `size__sys` | The size of the attachment in bytes. |
| `unclassified__sys` | Boolean indicating whether the attachment is unclassified. |

### Document Attachment Query Examples

The following are examples of standard `attachments__sysr` queries on documents.

#### Query: Retrieve All Attachments for a Specific Document Version

The following query retrieves attachment metadata for version 0.2 of document 101:

Copy to clipboard

```
SELECT id,
  (SELECT file_name__sys, attachment_id__sys, attachment_version__sys
   FROM attachments__sysr
   WHERE document_version_id__sys = '101_0_2')
FROM documents
WHERE id = 101
```

#### Query: Retrieve All Document Attachment Versions

Use the `ALLVERSIONS` query target option with `attachments__sysr` to retrieve all attachment versions:

Copy to clipboard

```
SELECT id, name__v, (SELECT document_id__sys, document_version_id__sys, attachment_id__sys FROM ALLVERSIONS attachments__sysr)
FROM documents
```

## Object Attachments

Vault object attachments are available for query in v13.0+. You can only query the `attachments__sysr` relationship as a subquery in the `SELECT` or `WHERE` clause.

### Object Attachment Queryable Fields

The `attachments__sysr` relationship allows queries on the following fields:

| Name | Description |
| --- | --- |
| `object_name__sys` | The name of the object record with the attachment. |
| `object_record_id__sys` | The ID of the object record with the attachment. |
| `attachment_id__sys` | The unique attachment ID. |
| `attachment_name__sys` | The name of the attachment. |
| `attachment_external_id__sys` | The external ID (`external_id__v`) value of the attachment, if provided when creating the attachment. |
| `attachment_version__sys` | The attachment version. |
| `file_name__sys` | The filename of the attachment. |
| `description__sys` | The description of the attachment. |
| `md5checksum__sys` | The MD5 checksum for the attachment. |
| `latest_version__sys` | Boolean indicating whether this is the latest version of the attachment. |
| `created_date__sys` | The date the attachment was created. |
| `created_by__sys` | The ID of the user who created the attachment. |
| `modified_date__sys` | The date the attachment was last modified. |
| `modified_by__sys` | The ID of the user who last modified the attachment. |
| `format__sys` | The file format of the attachment. |
| `size__sys` | The size of the attachment in bytes. |

### Object Attachment Query Examples

The following are examples of standard `attachments__sysr` queries on Vault objects.

#### Query: Retrieve Object Attachment Metadata (Subquery)

Get metadata for Vault object attachments using a subquery:

Copy to clipboard

```
SELECT id, name__v, (SELECT file_name__sys FROM attachments__sysr)
FROM product__v
```

#### Query: Retrieve Object Attachment Metadata (Filter)

Get metadata for Vault object attachments using a `WHERE` clause:

Copy to clipboard

```
SELECT id, name__v
FROM product__v
WHERE id IN (SELECT object_record_id__sys FROM attachments__sysr)
```

#### Query: Retrieve All Object Attachment Versions

Use the `ALLVERSIONS` query target option with `attachments__sysr` to retrieve all attachment versions:

Copy to clipboard

```
SELECT id, name__v, (SELECT file_name__sys, latest_version__sys FROM ALLVERSIONS attachments__sysr)
FROM product__v
```
