<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/delete-documents/delete-multiple-documents/ -->
<!-- title: Delete Multiple Documents -->

# Delete Multiple Documents

Delete all versions of multiple documents, including all source files and viewable renditions.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

DELETE`/api/{version}/objects/documents/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/json` |
| `Accept` | `application/json` (default) or `text/csv` |

## Body Parameters

Note

Some HTTP clients do not support `DELETE` requests with a
body. As a workaround for these cases, you can simulate this request using the
`POST` method with the `_method=DELETE` query parameter.

Create a CSV or JSON input file. Choose one of the following two ways to identify documents for deletion:

| Name | Description |
| --- | --- |
| `id` conditional | The system-assigned document ID of the document to delete. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `external_id__v` conditional | Instead of `id`, you can use this user-defined document external ID. |

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you're identifying documents in your input by a unique field, add `idParam={fieldname}` to the request endpoint. You can use any object field which has `unique` set to `true` in the object metadata, with the exception of picklists. For example, `idParam=external_id__v`. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id
771
772
773
774' \
https://myvault.veevavault.com/api/v26.2/objects/documents/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 771,
            "external_id__v": "ALT-DOC-0771"
        },
        {
            "responseStatus": "SUCCESS",
            "id": 772,
            "external_id__v": "CHO-DOC-0772"
        },
        {
            "responseStatus": "SUCCESS",
            "id": 773,
            "external_id__v": "GLU-DOC-0773"
        },
        {
            "responseStatus": "FAILURE",
            "errors": [
                {
                    "type": "INVALID_DATA",
                    "message": "Error message describing why this document was not deleted."
                }
            ]
        }
    ]
}
```
