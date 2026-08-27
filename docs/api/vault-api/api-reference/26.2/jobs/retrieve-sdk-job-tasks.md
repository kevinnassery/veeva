<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/jobs/retrieve-sdk-job-tasks/ -->
<!-- title: Retrieve SDK Job Tasks -->

# Retrieve SDK Job Tasks

Retrieve the tasks associated with an SDK job.

GET`/api/{version}/services/jobs/{job_id}/tasks`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{job_id}` | The ID of the SDK job, returned from the original job request. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/services/jobs/72408/tasks
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "url": "/api/v26.2/services/jobs/72408/tasks?limit=50&offset=0",
   "responseDetails": {
       "total": 1,
       "limit": 50,
       "offset": 0
   },
   "job_id": 72408,
   "tasks": [
       {
           "id": "Task1",
           "state": "SUCCESS"
       }
   ]
}
```
