<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/restore-document-attachment-version/ -->
<!-- title: Restore Document Attachment Version -->

# Restore Document Attachment Version

POST`/api/{version}/objects/documents/{doc_id}/attachments/{attachment_id}/versions/{attachment_version}?restore=true`

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

## Query Parameters

| Name | Description |
| --- | --- |
| `restore` | The parameter `restore` must be set to `true`. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/567/versions/2?restore=true
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data":
    {
        "id": "567",
        "version__v": 3
    }
}
```

## Response Details

On `SUCCESS`, Vault restores the specific version of an existing attachment to make it the latest version. The response will contain the attachment ID and version of the restored attachment.
