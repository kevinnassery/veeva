<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/jobs/retrieve-job-histories/ -->
<!-- title: Retrieve Job Histories -->

# Retrieve Job Histories

Retrieve a history of all completed jobs in the authenticated Vault. A completed job is any job which has started and finished running, including jobs which did not complete successfully. In-progress or queued jobs do not appear here.

GET`/api/{version}/services/jobs/histories`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `start_date` | Sets the date to start retrieving completed jobs, in the format `YYYY-MM-DDTHH:MM:SSZ`. For example, for 7AM on January 15, 2016, use `2016-01-15T07:00:00Z`. If omitted, defaults to the first completed job. |
| `end_date` | Sets the date to end retrieving completed jobs, in the format `YYYY-MM-DDTHH:MM:SSZ`. For example, for 7AM on January 15, 2016, use `2016-01-15T07:00:00Z`. If omitted, defaults to the current date and time. |
| `status` | Filter to only retrieve jobs in a certain status. Allowed values are `success`, `errors_encountered`, `failed_to_run`, `missed_schedule`, `timeout`, `completed_due_to_inactivity`, and `cancelled`. If omitted, retrieves all statuses. Learn more about [job statuses in Vault Help](https://platform.veevavault.help/en/gr/24762/#about-job-completion-statuses). |
| `limit` | Paginate the results by specifying the maximum number of histories per page in the response. This can be any value between `1` and `200`. If omitted, defaults to `50`. |
| `offset` | Paginate the results displayed per page by specifying the amount of offset from the first job history returned. If omitted, defaults to `0`. If you are viewing the first 50 results (page 1) and want to see the next page, set this to `offset=50`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/services/jobs/histories
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseMessage": "OK",
   "url": "/api/v26.2/services/jobs/histories?limit=50&offset=0",
   "responseDetails": {
       "total": 2753,
       "limit": 50,
       "offset": 0,
       "next_page": "/api/v26.2/services/jobs/histories?limit=50&offset=50"
   },
   "jobs": [
      {
           "job_id": 361402,
           "title": "User Account Activation",
           "status": "SUCCESS",
           "created_by": 1,
           "created_date": "2020-12-15T07:00:31.000Z",
           "modified_by": 1,
           "modified_date": "2020-12-16T07:05:06.000Z",
           "run_start_date": "2020-12-16T07:00:00.000Z",
           "run_end_date": "2020-12-16T07:06:07.000Z"
       },
       {
           "job_id": 361401,
           "title": "Synchronize Portal Assets",
           "status": "SUCCESS",
           "created_by": 1,
           "created_date": "2020-12-15T05:01:24.000Z",
           "modified_by": 1,
           "modified_date": "2020-12-16T05:00:09.000Z",
           "run_start_date": "2020-12-16T05:00:00.000Z",
           "run_end_date": "2020-12-16T05:01:12.000Z"
       }
   ]
}
```
