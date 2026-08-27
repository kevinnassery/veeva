<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/export-documents/retrieve-document-export-results/ -->
<!-- title: Retrieve Document Export Results -->

# Retrieve Document Export Results

After submitting a request to export documents from your Vault, you can query your Vault to determine the results of the request.

Before submitting this request:

* You must have previously requested a document export job (via the API) which is no longer active.
* You must have a valid `job_id` value (retrieved from the document export binder request).
* You must be a Vault Owner, System Admin or the user who initiated the job.

GET`/api/{version}/objects/documents/batch/actions/fileextract/{jobid}/results`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{job_id}` | The `id` value of the requested export job. This is returned with the export document requests above. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/batch/actions/fileextract/82701/results
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 23,
            "major_version_number__v": 0,
            "minor_version_number__v": 1,
            "file": "/82701/23/0_1/New Document.png",
            "user_id__v": 88973
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

| Field Name | Description |
| --- | --- |
| `job_id` | The Job ID value of the document export request. |
| `id` | The `id` value of the exported document. |
| `major_version_number__v` | The major version number of the exported document. |
| `minor_version_number__v` | The minor version number of the exported document. |
| `file` | The path on the [file staging](/vault-api/guides/file-staging). |
| `user_id__v` | The `id` value of the Vault user who initiated the document export job. |
