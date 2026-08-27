<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/export-documents/export-documents/ -->
<!-- title: Export Documents -->

# Export Documents

Use this request to export a set of documents to your Vault's [file staging](/vault-api/guides/file-staging).

POST`/api/{version}/objects/documents/batch/actions/fileextract`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

Prepare a JSON input file with the following body parameters:

| Name | Description |
| --- | --- |
| `id` required | The `id` value of the document(s) to export. |

## Query Parameters

| Name | Description |
| --- | --- |
| `source` | Optional: To exclude source files, include a query parameter `source=false`. If omitted, defaults to `true`. |
| `renditions` | Optional: To include renditions, include a query parameter `renditions=true`. If omitted, defaults to `false`. |
| `allversions` | Optional: To include all versions, include a query parameter `allversions=true`. If omitted, defaults to `false`, which only includes the latest version. |
| `text` | Optional: To include source document text, include a query parameter `text=true`. If omitted, defaults to `false`, which does not include source document text.  Can be used with `allversions` to include document text for all versions or the latest version. For example, `text=true&allversions=true` includes all text files from all versions of the requested document. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
--data-raw '[
    {
        "id": "58"
    }, 
    {
        "id":"134"
    },
    {
        "id":"122"
    }
]' \
https://myvault.veevavault.com/api/v26.2/objects/documents/batch/actions/fileextract?source=true&renditions=false&allversions=true
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "url": "/api/v26.2/services/jobs/36203",
    "job_id": "36203"
}
```

## Response Details

On `SUCCESS`, this operation exports the specified set of documents to your Vault’s file staging. When exporting source document text, the source document text files appear as "text\_file.txt" within their respective document version folders. The response includes the following information:

| Field Name | Description |
| --- | --- |
| `job_id` | The Job ID value to retrieve the [status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) and results of the document export request. |
| `url` | URL to retrieve the current job status of the document export request. |
