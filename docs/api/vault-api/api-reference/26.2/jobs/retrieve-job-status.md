<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/jobs/retrieve-job-status/ -->
<!-- title: Retrieve Job Status -->

# Retrieve Job Status

After submitting a request, you can query your Vault to determine the status of the request. To do this, you must have a valid `job_id` for a job previously requested through the API.

Example Jobs:

* Binder Export
* Import Submission
* Export Submission
* Create EDL
* Deploy Package
* Deep Copy Object Record
* Cascade Delete Object Record
* Export Documents

Note

The [Job Status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) endpoint can only be requested
once every 10 seconds for each `job_id`. When this limit is reached, Vault returns
`API_LIMIT_EXCEEDED`.

GET`/api/{version}/services/jobs/{job_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{job_id}` | The ID of the job, returned from the original job request. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/services/jobs/1201
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseMessage": "OK",
  "data": {
    "id": 1201,
    "status": "SUCCESS",
    "method": "POST",
    "links": [
      {
        "rel": "self",
        "href": "/api/v26.2/services/jobs/1601",
        "method": "GET",
        "accept": "application/json"
      }
    ],
    "created_by": 44533,
    "created_date": "2016-04-20T18:14:42.000Z",
    "run_start_date": "2016-04-20T18:14:43.000Z",
    "run_end_date": "2016-04-20T18:14:44.000Z"
  }
}
```

## Response Details

On `SUCCESS`, the response includes the following information. All DateTime values for scheduled jobs are in the Vault time zone for the currently authenticated user. Learn more about the [Vault time zone in Vault Help](https://platform.veevavault.help/en/gr/13309#vault_time_zone).

| Metadata Field | Description |
| --- | --- |
| `id` | The `job_id` field value for the job. |
| `status` | The status of the job. Possible statuses include `SCHEDULED`, `QUEUED`, `RUNNING`, `SUCCESS`, `ERRORS_ENCOUNTERED`, `QUEUEING`, `CANCELLED`, `TIMEOUT`, `COMPLETED_DUE_TO_INACTIVITY`, and `MISSED_SCHEDULE`. Learn more about [job statuses in Vault Help](https://platform.veevavault.help/en/gr/24762/#about-job-completion-statuses). |
| `method` | The HTTP method used in the request. |
| `links` | Once the job is finished, use these endpoints and methods to retrieve other job details. Note that for Controlled Copy jobs, the `artifacts` link will only work with API v18.3+. |
| `progress` | If the retrieved job is a custom job created with the Vault Java SDK, this array contains a summary of the number of job tasks (`size`) and their status. |
| `created_by` | The `id` field value of the user who started the job. |
| `created_date` | The date and time when the job was requested. |
| `run_start_date` | The date and time when the export job started. |
| `run_end_date` | The date and time when the export job finished. |
