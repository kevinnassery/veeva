<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/delete-single-document-attachment/ -->
<!-- title: Delete Single Document Attachment -->

# Delete Single Document Attachment

Deletes the specified attachment and all of its versions.

DELETE`/api/{version}/objects/documents/{doc_id}/attachments/{attachment_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{attachment_id}` | The attachment `id` field value. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/567
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```

## Response Details

On `SUCCESS`, Vault deletes the specific attachment and all its versions.
