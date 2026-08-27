<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-locks/undo-collaborative-authoring-checkout/ -->
<!-- title: Undo Collaborative Authoring Checkout -->

# Undo Collaborative Authoring Checkout

Undo Collaborative Authoring checkout on up to 500 documents at once. Learn more about [Collaborative Authoring in Vault Help](https://platform.veevavault.help/en/gr/56842).

To undo basic checkout, see [Delete Document Lock](/vault-api/api-reference/26.2/documents/document-locks/delete-document-lock).

DELETE`/api/{version}/objects/documents/batch/lock`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` or `text/csv` |
| `Content-Type` | `text/csv` |

## Body Parameters

Note

Some HTTP clients do not support `DELETE` requests with a
body. As a workaround for these cases, you can simulate this request using the
`POST` method with the `_method=DELETE` query parameter.

Upload parameters as a CSV file.

| Name | Description |
| --- | --- |
| `id` required | The `id` of the document to undo checkout. Maximum 500 documents per request. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: application/json" \
--data "id
7652
3
8" \
https://myvault.veevavault.com/api/v26.2/objects/documents/batch/lock
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": [
       {
           "responseStatus": "EXCEPTION",
           "responseMessage": "Document not found 19523/7652",
           "id": 7652
       },
       {
           "responseStatus": "FAILURE",
           "responseMessage": "Cannot use office365__sys undo check out for a document checked out to basic__sys",
           "id": 3
       },
       {
           "responseStatus": "SUCCESS",
           "responseMessage": "Undo check out successful",
           "id": 8
       }
   ]
}
```

## Response Details

On `SUCCESS`, Vault returns a `responseStatus` and `responseMessage` for each `id` in the request body. Partial success is allowed, meaning some documents in the batch may succeed while others fail. For any failed documents, the response includes a reason for the failure.
