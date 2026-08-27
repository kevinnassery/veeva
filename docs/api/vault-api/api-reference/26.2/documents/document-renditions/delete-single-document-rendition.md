<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/delete-single-document-rendition/ -->
<!-- title: Delete Single Document Rendition -->

# Delete Single Document Rendition

Note

If you need to delete more than one document rendition, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/document-renditions/delete-multiple-document-renditions).

Delete a single document rendition. On `SUCCESS`, Vault deletes the rendition of specified type from the latest document version.

DELETE`/api/{version}/objects/documents/{document_id}/renditions/{rendition_type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{document_id}` - The document `id` field value. |  |
| `{rendition_type}` - The document rendition type. |  |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/imported_rendition__vs
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```
