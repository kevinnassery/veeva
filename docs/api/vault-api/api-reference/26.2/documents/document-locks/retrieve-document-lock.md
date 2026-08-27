<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-locks/retrieve-document-lock/ -->
<!-- title: Retrieve Document Lock -->

# Retrieve Document Lock

GET`/api/{version}/objects/documents/{doc_id}/lock`

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
https://myvault.veevavault.com/api/v26.2/objects/documents/534/lock
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "lock": {
        "locked_by__v": 46916,
        "locked_date__v": "2015-03-20T23:47:11.000Z"
    }
}
```

## Response Details

If the document is locked (checked out), the response includes the user `id` field value of the person who checked it out and the date and time. If the document is not locked, the lock fields shown above will not be returned.
