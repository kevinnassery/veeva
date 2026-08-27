<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/delete-multiple-document-attachments/ -->
<!-- title: Delete Multiple Document Attachments -->

# Delete Multiple Document Attachments

Delete multiple document attachments in bulk with a JSON or CSV input file. This works for version-specific attachments and attachments at the document level.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

DELETE`/api/{version}/objects/documents/attachments/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` or `application/xml` |

## Body Parameters

Note

Some HTTP clients do not support `DELETE` requests with a
body. As a workaround for these cases, you can simulate this request using the
`POST` method with the `_method=DELETE` query parameter.

Prepare a CSV or JSON input file.

| Name | Description |
| --- | --- |
| `id` conditional | The attachment ID to delete. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `external_id__v` optional | Identify documents by their external ID instead of regular `id`. You must also add the `idParam=external_id__v` query parameter. |
| `document_id__v` optional | The source document `id` value. |

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you’re identifying attachments in your input by external id, add `idParam=external_id__v` to the request endpoint. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id
26
27
28
' \
https://myvault.veevavault.com/api/v26.2/objects/documents/attachments/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 26
        },
        {
            "responseStatus": "SUCCESS",
            "id": 27
        },
        {
            "responseStatus": "SUCCESS",
            "id": 28
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response returns the `id` of all successfully deleted attachments. You can only delete the latest version of an attachment.
