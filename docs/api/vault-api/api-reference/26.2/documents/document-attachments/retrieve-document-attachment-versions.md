<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-attachment-versions/ -->
<!-- title: Retrieve Document Attachment Versions -->

# Retrieve Document Attachment Versions

GET`/api/{version}/objects/documents/{doc_id}/attachments/{attachment_id}/versions`

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
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/566/versions
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "version__v": 1,
            "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/566/versions/1"
        },
        {
            "version__v": 2,
            "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/566/versions/2"
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response lists the following metadata for each version of the requested attachment:

| Metadata Field | Description |
| --- | --- |
| `version__v` | Version of the attachment. Attachment versioning uses integer numbers beginning with 1 and incrementing sequentially (1, 2, 3,...). There is no concept of major or minor version numbers with attachments. |
| `url` | Link to the [Retrieve Document Attachment Version Metadata](/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-attachment-version-metadata) endpoint to retrieve this attachment version. |
