<!-- source: https://general.veevavault.dev/vql/query-targets/renditions/ -->
<!-- title: Renditions -->

# Renditions

You can use the `renditions` object to query rendition properties for a document and document versions.

## Renditions Queryable Fields

The following fields are queryable for the `renditions` object:

| Name | Description |
| --- | --- |
| `rendition_type__sys` | Public name of the rendition type, for example, `viewable_rendition__v`. There is no lookup to rendition type metadata. |
| `document_id` | The parent document id. |
| `major_version_number__sys` | The major version of the parent document. |
| `minor_version_number__sys` | The minor version of the parent document. |
| `size__sys` | Size of unencrypted rendition file. |
| `md5checksum__sys` | MD5 checksum of unencrypted file. |
| `filename__sys` | Name of the file. |
| `pending__sys` | Indicates if the rendition file is being processed (`true`) or complete (`false`). |
| `format__sys` | File format of the rendition file. |
| `upload_date__sys` | The upload date for the rendition. |
| `document_version_id` | Compound document version id field. |

## Rendition Query Examples

The following are examples of queries for document and rendition properties.

### Properties from a Collection of Documents

Get document and rendition properties for a collection of document versions. Note that you will need to respect VQL query size limits and break up your queries:

Copy to clipboard

```
SELECT id, name__v,
    (SELECT rendition_type__sys, md5checksum__sys, size__sys, filename__sys
    FROM renditions__sysr)
FROM ALLVERSIONS documents
WHERE version_id CONTAINS ('102_0_3', '106_1_2', '107_1_0')
```

### Properties for Steady State Version Documents

Get document and rendition properties for steady state version of a set of documents.

Copy to clipboard

```
SELECT id, name__v,
    (SELECT rendition_type__sys, md5checksum__sys, size__sys, filename__sys
    FROM renditions__sysr)
FROM documents
WHERE status__v = steadystate() AND id CONTAINS (101,102,103)
```

### Custom Properties for Steady State Version Documents

Get document and custom rendition properties for steady state version of a set of documents.

Copy to clipboard

```
SELECT id, name__v,
    (SELECT md5checksum__sys, size__sys, filename__sys
    FROM renditions__sysr
    WHERE rendition_type__sys = 'my_rendition_type__c' )
FROM documents
WHERE status__v = steadystate() AND id CONTAINS (101,102,103)
```

### Particular Rendition Type

Query for renditions of a particular type.

Copy to clipboard

```
SELECT document_id, size__sys, upload_date__sys
FROM renditions
WHERE rendition_type__sys = 'imported_rendition__c'
```
