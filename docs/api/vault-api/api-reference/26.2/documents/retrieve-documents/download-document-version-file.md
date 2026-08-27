<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-documents/download-document-version-file/ -->
<!-- title: Download Document Version File -->

# Download Document Version File

Download the file of a specific document version.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/file`

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

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/3/file > file
```

## Response

Copy to clipboard

```
Content-Type: application/octet-stream;charset=UTF-8
Content-Disposition: attachment;filename="CholeCap-Presentation.pptx"
```

## Response Details

On `SUCCESS`, Vault retrieves the specified version of the source file from the document. The HTTP Response Header `Content-Type` is set to `application/octet-stream`. The HTTP Response Header `Content-Disposition` contains a filename component which can be used when naming the local file.
