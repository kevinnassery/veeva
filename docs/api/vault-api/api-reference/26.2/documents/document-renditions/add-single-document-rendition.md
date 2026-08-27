<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/add-single-document-rendition/ -->
<!-- title: Add Single Document Rendition -->

# Add Single Document Rendition

Note

If you need to add more than one document rendition, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/document-renditions/add-multiple-document-renditions).

POST`/api/{version}/objects/documents/{doc_id}/renditions/{rendition_type}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
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

On `SUCCESS`, Vault associates the uploaded file with the given rendition type for the specified document.
