<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-locks/delete-document-lock/ -->
<!-- title: Delete Document Lock -->

# Delete Document Lock

Deleting a document lock is analogous to undoing check out of a document. The authenticated user must have *Edit Document* permission in the document lifecycle state security settings as well as one of the following:

* *Document Owner* role on the document
* *All Documents: All Document Actions* permission
* *Document: Cancel Checkout* permission

DELETE`/api/{version}/objects/documents/{doc_id}/lock`

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/lock
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Undo check out successful."
}
```

## Response Details

On `SUCCESS`, Vault unlocks the document, allowing other users to lock/check out the document.
