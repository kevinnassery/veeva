<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-relationships/delete-multiple-document-relationships/ -->
<!-- title: Delete Multiple Document Relationships -->

# Delete Multiple Document Relationships

Delete relationships from multiple documents.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 1000.

You cannot create or delete standard relationship types. Examples of standard relationship types include *Based On* and *Original Source*. Learn about [document relationships in Vault Help](https://platform.veevavault.help/en/gr/21330).

DELETE`/api/{version}/objects/documents/relationships/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` (default) or `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |

## Body Parameters

Note

Some HTTP clients do not support `DELETE` requests with a
body. As a workaround for these cases, you can simulate this request using the
`POST` method with the `_method=DELETE` query parameter.

Create a CSV or JSON input file.

| Name | Description |
| --- | --- |
| `id` required | The ID of the relationship to delete. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id
10
11
12' \
https://myvault.veevavault.com/api/v26.2/objects/documents/relationships/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 10
        },
        {
            "responseStatus": "SUCCESS",
            "id": 11
        },
        {
            "responseStatus": "FAILURE",
            "errors": [
                {
                    "type": "INVALID_DATA",
                    "message": "Error message describing why this relationship was not deleted."
                }
            ]
        }
    ]
}
```

## Response Details

On `SUCCESS`, Vault returns the relationship IDs of the deleted relationships.
