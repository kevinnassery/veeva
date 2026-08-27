<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/download-all-document-attachments/ -->
<!-- title: Download All Document Attachments -->

# Download All Document Attachments

Downloads the latest version of all attachments from the document.

GET`/api/{version}/objects/documents/{doc_id}/attachments/file`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/file
```

## Response

Copy to clipboard

```
Content-Type: application/octet-stream;charset=UTF-8
Content-Disposition: attachment;filename="Document VV-02839 (v0.1) - attachments.zip"
```

## Response Details

On `SUCCESS`, Vault retrieves the latest version of all attachments from the document. The attachments are packaged in a ZIP file with the file name: `Document {document number} (v. {major version}.{minor version}) - attachments.zip`.

The HTTP Response Header Content-Type is set to `application/zip`. The HTTP Response Header `Content-Disposition` contains a filename attribute which can be used when naming the local file.
When downloading attachments with very small file size, the HTTP Response Header `Content-Length` is set to the size of the attachment. Note that for most attachment downloads (larger file sizes), the `Transfer-Encoding` method is set to `chunked` and the `Content-Length` is not displayed.
