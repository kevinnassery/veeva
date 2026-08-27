<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/delete-single-document-attachment-version/ -->
<!-- title: Delete Single Document Attachment Version -->

# Delete Single Document Attachment Version

Deletes the specified version of the specified attachment.

DELETE`/api/{version}/objects/documents/{doc_id}/attachments/{attachment_id}/versions/{attachment_version}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{attachment_id}` | The attachment `id` field value. |
| `{attachment_version}` | The attachment `version__v` field value. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/567/versions/3
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```
