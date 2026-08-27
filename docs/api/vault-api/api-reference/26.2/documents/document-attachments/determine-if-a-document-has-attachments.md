<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/determine-if-a-document-has-attachments/ -->
<!-- title: Determine if a Document has Attachments -->

# Determine if a Document has Attachments

GET`/api/{version}/objects/documents/{doc_id}`

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
https://myvault.veevavault.com/api/v26.2/objects/documents/565
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "document": {
        "id": 128,
        "version_id": "128_5_0",
    },
    "attachments": [
        {
            "id": 1901,
            "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/128/attachments/1901"
        }
    ]
}
```

## Response Details

This endpoint does not retrieve the number of versions of each attachment or the attachment metadata. The `attachments` attribute is displayed in the response for documents where attachments have been enabled on the document type (even if the document has no attachments).
