<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-relationships/create-single-document-relationship/ -->
<!-- title: Create Single Document Relationship -->

# Create Single Document Relationship

Note

If you need to create a relationship on more than one document, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/document-relationships/create-multiple-document-relationships).

Create a new relationship on a document.

You cannot create or delete standard relationship types. Examples of standard relationship types include *Based On* and *Original Source*. Learn about [document relationships in Vault Help](https://platform.veevavault.help/en/gr/21330).

POST`/api/{version}/objects/documents/{document\_id}/versions/{major\_version\_number\_\_v}/{minor\_version\_number\_\_v}/relationships`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |
| `X-VaultAPI-MigrationMode` | When set to `true`, creates a document relationship in migration mode. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{document_id}` | The document `id` field value. |
| `{major_version_number__v}` | The document `major_version_number__v` field value. |
| `{minor_version_number__v}` | The document `minor_version_number__v` field value. |

## Body Parameters

| Field Name | Description |
| --- | --- |
| `target_doc_id__v` required | The document `id` of the target document. |
| `relationship_type__v` required | The relationship type retrieved from the Document Relationships Metadata call above. |
| `target_major_version__v` conditional | The major version number of the target document to which the source document will be bound. Required for target version-specific relationships. |
| `target_minor_version__v` conditional | The minor version number of the target document to which the source document will be bound. Required for target version-specific relationships. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "target_doc_id__v=548" \
-d "relationship_type__v=supporting_documents__vs" \
-d "target_major_version__v=0" \
-d "target_minor_version__v=2" \
https://myvault.veevavault.com/api/v26.2/objects/documents/548/versions/0/1/relationships
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Document relationship successfully created.",
    "id": 200
}
```

## Response Details

On `SUCCESS`, Vault returns the ID of the newly created document relationship.
