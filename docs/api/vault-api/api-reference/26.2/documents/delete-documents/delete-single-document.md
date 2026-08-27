<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/delete-documents/delete-single-document/ -->
<!-- title: Delete Single Document -->

# Delete Single Document

Note

If you need to delete more than one document, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/delete-documents/delete-multiple-documents).

Delete all versions of a document, including all source files and viewable renditions.

DELETE`/api/{version}/objects/documents/{document_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `document_id` | The system-assigned document ID of the document to delete. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "id": 534
}
```
