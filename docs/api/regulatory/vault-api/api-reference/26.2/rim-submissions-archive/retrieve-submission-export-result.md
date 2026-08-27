<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/retrieve-submission-export-result/ -->
<!-- title: Retrieve Submission Export Results -->

# Retrieve Submission Export Results

After submitting a request to export a submission from your Vault, you can query Vault to determine the results of the request.

Before submitting this request:

* You must have previously requested a submission export job (via the API) which is no longer active.
* You must have a valid `job_id` returned from an [Export Single Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-single-submission) or [Export Multiple Submissions](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-multiple-submissions) request.

GET`/api/{version}/app/regulatory/submissions_archive/export_job/{job_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{job_id}` | The unique ID returned in the response of the initial export request. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/app/regulatory/submissions_archive/export_job/418103
```

## Response

Copy to clipboard

```
{
    "status": "SUCCESS",
    "responseMessage": "Submissions Archive Export Results",
    "data": {
        "job_id": "418103",
        "job_status": "SUCCEEDED",
        "user_id": "4644280",
        "file_path": "/u4644280/Submissions Archive Export/418103"
    }
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

* `job_id` - The unique ID assigned to the asynchronous export job in Vault.
* `job_status` - The current status of the job. Possible values: `QUEUED`, `RUNNING`, `SUCCESS`, `FAILED`, `EXPIRED`, `NOT FOUND`.
* `user_id` - The ID of the Vault user who initiated the request.
* `file_path` - The path to the exported package in file staging. For bulk exports, this is the standardized path. For single exports, this is only returned if the package exceeds 4 GB; otherwise, the response includes a direct download URL valid for 14 days.
