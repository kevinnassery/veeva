<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/download-document-attachment-version/ -->
<!-- title: Download Document Attachment Version -->

# Download Document Attachment Version

Downloads the specified version of the attachment from the document.

GET`/api/{version}/objects/documents/{doc_id}/attachments/{attachment_id}/versions/{attachment_version}/file`

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
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/567/versions/1/file
```

## Response

Copy to clipboard

```
Content-Type: application/octet-stream;charset=UTF-8
Content-Disposition: attachment;filename="file.pdf"
```

## Response Details

On `SUCCESS`, Vault retrieves the specified version of the attachment from the document. The file name is the same as the attachment file name.

The HTTP Response Header Content-Type is set to the MIME type of the file. For example, if the attachment is a PNG image, the Content-Type is image/png. If we cannot detect the MIME file type, Content-Type is set to application/octet-stream. The HTTP Response Header `Content-Disposition` contains a filename attribute which can be used when naming the local file. When downloading attachments with very small file size, the HTTP Response Header `Content-Length` is set to the size of the attachment. Note that for most attachment downloads (larger file sizes), the `Transfer-Encoding` method is set to `chunked` and the `Content-Length` is not displayed.
