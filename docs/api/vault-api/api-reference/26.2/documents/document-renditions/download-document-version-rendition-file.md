<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/download-document-version-rendition-file/ -->
<!-- title: Download Document Version Rendition File -->

# Download Document Version Rendition File

Download a rendition for a specified version of a document.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/renditions/{rendition_type}`

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
| `{rendition_type}` | The document rendition type. |

## Query Parameters

| Name | Description |
| --- | --- |
| `protectedRendition` | If your Vault is configured to use protected renditions, set to `false` to download the non-protected rendition. If omitted, defaults to `true`. You must have the *Download Non-Protected Rendition* permission to download non-protected renditions. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/0/renditions/viewable_rendition__v > file
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```

## Response Details

On `SUCCESS`, Vault retrieves the file associated with the given renditions type for the specified document version. The HTTP Response Header `Content-Type` is set to `application/octet-stream`.
