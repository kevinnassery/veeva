<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-documents/download-document-version-thumbnail-file/ -->
<!-- title: Download Document Version Thumbnail File -->

# Download Document Version Thumbnail File

Download the thumbnail image file of a specific document version.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/thumbnail`

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
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/3/thumbnail > thumbnail.png
```

## Response Details

On `SUCCESS`, Vault returns the thumbnail image for the specified version of the document. The HTTP Response Header `Content-Type` is set to `image/png`.
