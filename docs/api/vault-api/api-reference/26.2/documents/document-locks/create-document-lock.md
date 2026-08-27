<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-locks/create-document-lock/ -->
<!-- title: Create Document Lock -->

# Create Document Lock

A document lock is analogous to checking out a document but without the file attached in the response for download.

POST`/api/{version}/objects/documents/{doc_id}/lock`

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
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/lock
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Document successfully checked out."
}
```

## Response Details

On `SUCCESS`, Vault locks the document and other users are not allowed to lock (check-out) the document.
