<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/update-document-attachment-description/ -->
<!-- title: Update Document Attachment Description -->

# Update Document Attachment Description

Update an attachment on the latest version of a document. To update a version-specific attachment, or to update multiple attachments at once, use the [bulk API](/vault-api/api-reference/26.2/documents/document-attachments/update-multiple-document-attachment-descriptions).

PUT`/api/{version}/objects/documents/{doc_id}/attachments/{attachment_id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{attachment_id}` | The attachment `id` field value. |

## Body Parameters

| Name | Description |
| --- | --- |
| `description__v` required | This is the only editable field. The maximum character length is 1000. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "description__v=This is my description for this attachment." \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```
