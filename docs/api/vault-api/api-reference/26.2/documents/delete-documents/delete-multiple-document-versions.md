<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/delete-documents/delete-multiple-document-versions/ -->
<!-- title: Delete Multiple Document Versions -->

# Delete Multiple Document Versions

Delete a specific version of multiple documents, including the version's source file and viewable rendition.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

DELETE`/api/{version}/objects/documents/versions/batch`

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

Create a CSV or JSON input file.

| Name | Description |
| --- | --- |
| `id` conditional | The system-assigned document ID of the document to delete. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `external_id__v` conditional | Instead of `id`, you can use this user-defined document external ID. |
| `major_version_number__v` required | Major version number of the document version to remove. |
| `minor_version_number__v` required | Minor version number of the document version to remove. |

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you're identifying documents in your input by a unique field, add `idParam={fieldname}` to the request endpoint. You can use any object field which has `unique` set to `true` in the object metadata, with the exception of picklists. For example, `idParam=external_id__v`. |

[Download Input File](/sample-files/vault-delete-document-versions-sample-csv-input.csv)

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id,major_version_number__v,minor_version_number__v
771,0,2
772,0,2
773,1,0
774,1,1' \
https://myvault.veevavault.com/api/v26.2/objects/documents/versions/batch
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
            "external_id__v": "ALT-DOC-0771",
            "major_version_number__v": 0,
            "minor_version_number__v": 2
        },
        {
            "responseStatus": "SUCCESS",
            "id": 772,
            "external_id__v": "CHO-DOC-0772",
            "major_version_number__v": 0,
            "minor_version_number__v": 2
        },
        {
            "responseStatus": "SUCCESS",
            "id": 773,
            "external_id__v": "GLU-DOC-0773",
            "major_version_number__v": 1,
            "minor_version_number__v": 0
        },
        {
            "responseStatus": "FAILURE",
            "errors": [
                {
                    "type": "INVALID_DATA",
                    "message": "Error message describing why this document version was not deleted."
                }
            ]
        }
    ]
}
```
