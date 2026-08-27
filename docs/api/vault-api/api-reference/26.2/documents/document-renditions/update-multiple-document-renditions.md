<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/update-multiple-document-renditions/ -->
<!-- title: Update Multiple Document Renditions -->

# Update Multiple Document Renditions

Update or re-render document renditions in bulk.

* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

POST`/api/{version}/objects/documents/batch/actions/rerender`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `text/csv` |

## Body Parameters

Upload parameters as a CSV file.

| Name | Description |
| --- | --- |
| `id` required | The system-assigned ID of the document. |
| `major_version_number__v` required | The major version number of the existing document. |
| `minor_version_number__v` required | The minor version number of the existing document. |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
-H "Accept: text/csv" \
--data-raw 'id,major_version_number__v,minor_version_number__v
1,0,1
2,0,1' \
https://myvault.veevavault.com/api/v26.2/objects/documents/batch/actions/rerender
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 1,
            "major_version_number__v": "0",
            "minor_version_number__v": "1"
        },
        {
            "responseStatus": "SUCCESS",
            "id": 2,
            "major_version_number__v": "0",
            "minor_version_number__v": "1"
        }
    ]
}
```

## Response Details

On `SUCCESS`, Vault returns whether each document rendition was successfully re-rendered.
