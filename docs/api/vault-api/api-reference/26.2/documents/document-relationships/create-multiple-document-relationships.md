<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-relationships/create-multiple-document-relationships/ -->
<!-- title: Create Multiple Document Relationships -->

# Create Multiple Document Relationships

Create new relationships on multiple documents.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 1000.

You cannot create or delete standard relationship types. Examples of standard relationship types include *Based On* and *Original Source*. Learn about [document relationships in Vault Help](https://platform.veevavault.help/en/gr/21330).

POST`/api/{version}/objects/documents/relationships/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |
| `X-VaultAPI-MigrationMode` | When set to `true`, creates a document relationship in migration mode. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |

## Body Parameters

Create a JSON or CSV input file. There are multiple ways to create document relationships. The following standard fields are required to create document relationships.

| Name | Description |
| --- | --- |
| `source_doc_id__v` required | Document `id` value of the document on which the relationship is being created. |
| `target_doc_id__v` required | Document `id` value of the document which is being associated with the source document as a related document. |
| `relationship_type__v` required | The type of relationship the target document will have with the source document. |

[Download Input File](/sample-files/vault-create-doc-relationship-sample-csv-input.csv)
[Download Input File](/sample-files/bulk-create-document-relationships.json)

##### Create Source Version-Specific Relationships

The following fields are required when creating a source version-specific relationship.

| Name | Description |
| --- | --- |
| `source_major_version__v` required | The major version number of the source document. |
| `source_minor_version__v` required | The minor version number of the source document. |
| `relationship_type__v` required | The type of relationship the target document will have with the source document. |

[Download Input File](/sample-files/vault-create-source-version-specific-relationship-sample-csv-input.csv)

##### Create Target Version-Specific Relationships

The following fields are required when creating a target version-specific relationship.

| Name | Description |
| --- | --- |
| `target_major_version__v` required | The major version number of the target document to which the source document will be bound. |
| `target_minor_version__v` required | The minor version number of the target document to which the source document will be bound. |
| `relationship_type__v` required | The type of relationship the target document will have with the source document. |

[Download Input File](/sample-files/vault-create-target-version-specific-relationship-sample-csv-input.csv)

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | To create relationships based on an unique field, set idParam to a unique field name. You can use any object field which has `unique` set to `true` in the object metadata, with the exception of picklists. For example, `idParam=external_id__v`. You must then set `Content-Type` to `text/csv` and include your field name as a column. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id,source_doc_id__v,source_major_version__v,source_minor_version__v,target_doc_id__v,relationship_type__v
7,17,1,6,42,supporting_documents__c
8,17,0,1,40,supporting_documents__c' \
https://myvault.veevavault.com/api/v26.2/objects/documents/relationships/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 10
        },
        {
            "responseStatus": "SUCCESS",
            "id": 11
        },
    ]
}
```

## Response Details

On `SUCCESS`, Vault returns the IDs of the newly created document relationships.
