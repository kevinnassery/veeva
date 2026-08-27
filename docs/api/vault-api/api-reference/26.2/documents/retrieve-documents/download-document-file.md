<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-documents/download-document-file/ -->
<!-- title: Download Document File -->

# Download Document File

GET`/api/{version}/objects/documents/{doc_id}/file`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Query Parameters

| Name | Description |
| --- | --- |
| `lockDocument` | Set to `true` to Check Out this document before retrieval. If omitted, defaults to `false`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/file?lockDocument=false > file
```

## Response

Copy to clipboard

```
Content-Type: application/octet-stream;charset=UTF-8
Content-Disposition: attachment;filename="CholeCap-Presentation.pptx"
```

## Response Details

On `SUCCESS`, Vault retrieves the latest version of the source file from the
document. The HTTP Response Header `Content-Type` is set to
`application/octet-stream`. The HTTP Response Header `Content-Disposition`
contains a filename component which can be used when naming the local file.
Note that for most downloads (larger file sizes), the `Transfer-Encoding`
method is set to `chunked` and the `Content-Length` is not displayed.
