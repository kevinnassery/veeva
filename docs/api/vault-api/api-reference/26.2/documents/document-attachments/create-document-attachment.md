<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/create-document-attachment/ -->
<!-- title: Create Document Attachment -->

# Create Document Attachment

Create an attachment on the latest version of a document. If the attachment already exists, Vault uploads the attachment as a new version of the existing attachment. Learn more about [attachment versioning in Vault Help](https://platform.veevavault.help/en/gr/24287#version-specific).

To create a version-specific attachment, or to create multiple attachments at once, use the [bulk API](/vault-api/api-reference/26.2/documents/document-attachments/create-multiple-document-attachments).

POST`/api/{version}/objects/documents/{doc_id}/attachments`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

#### File Upload

To upload the file, use the multi-part attachment with the file component `"file={file_name}"`. The maximum allowed file size is 2GB.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "file=my_attachment_file.png" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments
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

On `SUCCESS`, the response will contain the attachment ID and version of the newly added attachment. Document attachments are automatically bound to all versions of a document. The following attribute values are determined based on the file in the request: `filename__v`, `format__v`, `size__v`.
