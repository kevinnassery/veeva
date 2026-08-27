<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-version-attachment-versions/ -->
<!-- title: Retrieve Document Version Attachment Versions -->

# Retrieve Document Version Attachment Versions

Retrieve all versions of an attachment on a specific document version.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/attachments/{attachment_id}/versions`

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
| `{attachment_id}` | The `id` of the document attachment to retrieve. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/attachments/39/versions
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "version__v": 1,
            "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/attachments/2901/versions/1"
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response lists the following metadata for each version of the requested attachment:

| Metadata Field | Description |
| --- | --- |
| `version__v` | Version of the attachment. Attachment versioning uses integer numbers beginning with 1 and incrementing sequentially (1, 2, 3,...). There is no concept of major or minor version numbers with attachments. |
| `url` | Link to the [Retrieve Document Version Attachment Version Metadata](/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-version-attachment-version-metadata) endpoint to retrieve this attachment version. |
