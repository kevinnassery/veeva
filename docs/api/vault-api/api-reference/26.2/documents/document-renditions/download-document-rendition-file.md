<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/download-document-rendition-file/ -->
<!-- title: Download Document Rendition File -->

# Download Document Rendition File

Download a rendition file from the latest version of a document.

GET`/api/{version}/objects/documents/{doc_id}/renditions/{rendition_type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{rendition_type}` | The document rendition type. |

## Query Parameters

| Name | Description |
| --- | --- |
| `steadyState` | Set to `true` to download a rendition (file) from the latest steady state version (1.0, 2.0, etc.) of a document. |
| `protectedRendition` | If your Vault is configured to use protected renditions, set to `false` to download the non-protected rendition. If omitted, defaults to `true`. You must have the *Download Non-Protected Rendition* permission to download non-protected renditions. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/viewable_rendition__v > file
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```

## Response Details

On `SUCCESS`, Vault retrieves the file associated with the given renditions type for the document. The HTTP Response Header `Content-Type` is set to `application/octet-stream`.
