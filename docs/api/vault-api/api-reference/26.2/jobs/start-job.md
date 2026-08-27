<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/jobs/start-job/ -->
<!-- title: Start Job -->

# Start Job

Moves up a `scheduled` job instance to start immediately. Each time a user calls this API, Vault cancels the scheduled instance of the specified job for the current interval. For example, if a job is scheduled to run daily at 11PM PST, calling this API against it at 4PM PST will cause the job to not run as scheduled at 11PM PST the same day. Vault will resume running the job at 11PM PST the next day regardless of how many times this API is called before 11PM PST the previous day.

This is analogous to the *Start Now* option in the Vault UI.

POST`/api/{version}/services/jobs/start_now/{job_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{job_id}` | The ID of the scheduled job instance to start. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/start_now/72505
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "url": "/api/v26.2/services/jobs/72505",
   "job_id": 72505
}
```
