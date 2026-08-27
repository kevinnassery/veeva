<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/merge-object-records/retrieve-record-merge-status/ -->
<!-- title: Retrieve Record Merge Status -->

# Retrieve Record Merge Status

Given a `job_id` for a merge records job, retrieve the job status.

Before submitting this request:

* You must have previously requested a record merge job.
* You must have a valid `job_id` field value returned from the record merge operation.

GET`/api/{version}/vobjects/merges/{job_id}/status`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{job_id}` | The `job_id` field value returned from the merge operation. You can start merge operations with the [Initiate Record Merge](/vault-api/api-reference/26.2/vault-objects/merge-object-records/initiate-record-merge) API request or with the [Vault Java SDK](/vault-sdk/entry-points/record-merge/). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/merges/863301/status
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "status": "IN_PROGRESS"
    }
}
```

## Response Details

On `SUCCESS`, the merge job may have one of the following statuses:

* `IN_PROGRESS`: The job is currently running
* `SUCCESS`: The job completed with no errors; all records were merged
* `FAILURE`: The job completed with errors; one or more records were not merged
