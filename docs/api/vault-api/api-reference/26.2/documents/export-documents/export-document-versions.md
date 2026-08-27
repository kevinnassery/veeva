<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/export-documents/export-document-versions/ -->
<!-- title: Export Document Versions -->

# Export Document Versions

Export a specific set of document versions to your Vault's [file staging](/vault-api/guides/file-staging). The files you export go to the `u{userID}` folder, regardless of your security profile. You can export a maximum of 10,000 document versions (source files) per request.

POST`/api/{version}/objects/documents/versions/batch/actions/fileextract`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

Prepare a JSON input file with the following body parameters for each document version you wish to export:

| Name | Description |
| --- | --- |
| `id` required | ID of the document to export. |
| `major_version_number__v` required | The major version number of the document to export. |
| `minor_version_number__v` required | The minor version number of the document to export. |

## Query Parameters

| Name | Description |
| --- | --- |
| `source` | To exclude source files, include a query parameter `source=false`. If omitted, defaults to `true`. |
| `renditions` | To include renditions, include a query parameter `renditions=true`. If omitted, defaults to `false`. |
| `text` | To include source document text, include a query parameter `text=true`. If omitted, defaults to `false`. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
--data-raw '[
    {
        "id": "58",
        "major_version_number__v": "0",
        "minor_version_number__v": "1"
    }, 
    {
        "id":"134",
        "major_version_number__v": "0",
        "minor_version_number__v": "2"
    },
    {
        "id":"122",
        "major_version_number__v": "0",
        "minor_version_number__v": "2"
    }
]' \
https://myvault.veevavault.com/api/v26.2/objects/documents/versions/batch/actions/fileextract
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "url": "/api/v26.2/services/jobs/40604",
    "job_id": "40604"
}
```

## Response Details

On `SUCCESS`, this operation exports the specified set of document versions to your Vault’s file staging. When exporting source document text, the source document text files appear as "text\_file.txt" within their respective document version folders. The response includes the following information:

| Field Name | Description |
| --- | --- |
| `url` | URL to retrieve the current status of the document export job. |
| `job_id` | The Job ID value of the document export request. |
