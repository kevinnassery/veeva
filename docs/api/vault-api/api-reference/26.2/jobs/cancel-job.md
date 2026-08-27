<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/jobs/cancel-job/ -->
<!-- title: Cancel Job -->

# Cancel Job

Request to cancel up to 500 job instances. Once cancelled, the job moves to the `CANCELLED` state.

Job instances must meet certain criteria to be eligible for cancellation. Learn more about [jobs eligible for cancellation in Vault Help](https://platform.veevavault.help/en/gr/24762). For example, jobs in the `SCHEDULED` state can always be cancelled. You can use [Vault API](/vault-api/api-reference/26.2/jobs/retrieve-job-status) or [VQL](/vql/query-targets/jobs#Job_Instances) to retrieve the status of a job instance.

POST`/api/{version}/services/jobs/actions/cancel`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` (default) or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

In the body of the request, include a JSON or CSV with the following information:

| Name | Description |
| --- | --- |
| `{job_id}` | A JSON array or CSV of each `job_id` to cancel. Maximum 500 jobs per request. |

## Request

Copy to clipboard

```
curl --location 'https://myvault.veevavault.com/api/v26.2/services/jobs/actions/cancel' \
--header 'Authorization: {AUTH_VALUE}' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--data '[
   {
       "job_id": 1046892
   },
   {
       "job_id": 1043341
   }
]'
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": [
       {
           "responseStatus": "SUCCESS",
           "data": {
               "id": 1068044
           }
       },
       {
           "responseStatus": "FAILURE",
           "errors": {
               "type": "INVALID_DATA",
               "message": "Job [1068337] is not found in QUEUED or QUEUEING state"
           }
       }
   ]
}
```

## Response Details

On `SUCCESS`, Vault returns an individual `responseStatus` for each of the requested job instances, either `SUCCESS` or `FAILURE`. The status of each job instance is returned in the same order as the request.

For each job instance that successfully begins cancelling, Vault moves the job instance to the `CANCELLING` state and returns the `id` of the job instance. Once a job is in the `CANCELLING` state, the job will not fail to cancel. You can retrieve the job status to check if the job has finished cancelling and moved to the `CANCELLED` state.

For each job instance that could not begin cancelling, Vault returns an individual `errors` array containing the `type` of error (such as `INVALID_DATA`) and the error `message` containing the reason for failure and the job ID.
