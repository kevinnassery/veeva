<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/jobs/retrieve-job-monitors/ -->
<!-- title: Retrieve Job Monitors -->

# Retrieve Job Monitors

Retrieve monitors for jobs which have not yet completed in the authenticated Vault. An uncompleted job is any job which has not finished running, such as scheduled, queued, or actively running jobs. Completed jobs do not appear here.

GET`/api/{version}/services/jobs/monitors`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `start_date` | Sets the date to start retrieving uncompleted jobs, based on the date and time the job instance was created. Value must be in the format `YYYY-MM-DDTHH:MM:SSZ`. For example, for 7AM on January 15, 2016, use `2016-01-15T07:00:00Z`. If omitted, defaults to the first completed job. |
| `end_date` | Sets the date to end retrieving uncompleted jobs, based on the date and time the job instance was created. Value must be in the format `YYYY-MM-DDTHH:MM:SSZ`. For example, for 7AM on January 15, 2016, use `2016-01-15T07:00:00Z`. If omitted, defaults to the current date and time. |
| `status` | Filter to only retrieve jobs in a certain status. Allowed values are `scheduled`, `queued`, `running`. If omitted, retrieves all statuses. |
| `limit` | Paginate the results by specifying the maximum number of jobs per page in the response. This can be any value between `1` and `200`. If omitted, defaults to `50`. |
| `offset` | Paginate the results displayed per page by specifying the amount of offset from the first job instance returned. If omitted, defaults to `0`. If you are viewing the first 50 results (page 1) and want to see the next page, set this to `offset=50`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/services/jobs/monitors
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseMessage": "OK",
   "url": "/api/v26.2/services/jobs/monitors?limit=50&offset=0",
   "responseDetails": {
       "total": 3,
       "limit": 50,
       "offset": 0
   },
   "jobs": [
       {
           "job_id": 72505,
           "title": "User Account Activation",
           "status": "SCHEDULED",
           "created_by": 1,
           "created_date": "2021-02-03T04:01:29.000Z",
           "modified_by": 1,
           "modified_date": "2021-02-03T04:01:29.000Z",
           "run_start_date": "2021-02-04T04:00:00.000Z"
       },
       {
           "job_id": 72518,
           "title": "Task Reminder Notification",
           "status": "SCHEDULED",
           "created_by": 1,
           "created_date": "2021-02-03T09:01:53.000Z",
           "modified_by": 1,
           "modified_date": "2021-02-03T09:01:53.000Z",
           "run_start_date": "2021-02-04T09:00:00.000Z"
       }
   ]
}
```
