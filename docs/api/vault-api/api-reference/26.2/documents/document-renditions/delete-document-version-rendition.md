<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/delete-document-version-rendition/ -->
<!-- title: Delete Document Version Rendition -->

# Delete Document Version Rendition

DELETE`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/renditions/{rendition_type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{major_version}` | The document `major_version_number__v` field value. |
| `{minor_version}` | The document `minor_version_number__v` field value. |
| `{rendition_type}` | The document rendition type. |

On `SUCCESS`, Vault deletes the rendition of the given type from the specified version of the document.

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/0/renditions/imported_rendition__c
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```
