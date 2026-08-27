<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/download-document-version-attachment-version/ -->
<!-- title: Download Document Version Attachment Version -->

# Download Document Version Attachment Version

Downloads the specified attachment version from the specified document version.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/attachments/{attachment_id}/versions/{attachment_version}/file`

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
| `{attachment_id}` | The `id` field value of the attachment. |
| `{attachment_version}` | The version of the attachment. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/56/versions/0/1/attachments/14/versions/3/file
```

## Response

Copy to clipboard

```
Content-Type: application/octet-stream;charset=UTF-8
Content-Disposition: attachment;filename="file.pdf"
```

## Response Details

On `SUCCESS`, Vault retrieves the specified attachment version from the specified document version. The file name is the same as the attachment file name.

The HTTP Response Header `Content-Type` is set to the MIME type of the file. For example, if the attachment is a PNG image, the `Content-Type`is image/png. If we cannot detect the MIME file type, Content-Type is set to application/octet-stream. The HTTP Response Header `Content-Disposition` contains a filename attribute which can be used when naming the local file. When retrieving attachments with very small file size, the HTTP Response Header `Content-Length` is set to the size of the attachment. Note that for most attachment downloads (larger file sizes), the `Transfer-Encoding` method is set to `chunked` and the `Content-Length` is not displayed.
