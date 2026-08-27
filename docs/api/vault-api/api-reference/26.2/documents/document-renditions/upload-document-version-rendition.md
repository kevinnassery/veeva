<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/upload-document-version-rendition/ -->
<!-- title: Upload Document Version Rendition -->

# Upload Document Version Rendition

POST`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/renditions/{rendition_type}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{major_version}` | The document `major_version_number__v` field value. |
| `{minor_version}` | The document `minor_version_number__v` field value. |
| `{rendition_type}` | The document rendition type. |

#### File Upload

To upload the file, use the multi-part attachment with the file component `"file={file_name}"`. The maximum allowed file size is 4GB.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "file=CholeCap-Document.pdf" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/imported_rendition__c
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```

## Response Details

On `SUCCESS`, Vault associates the uploaded file with the given rendition type for the document with the specified version number.
