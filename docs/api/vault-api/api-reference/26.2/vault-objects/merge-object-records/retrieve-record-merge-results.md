<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/merge-object-records/retrieve-record-merge-results/ -->
<!-- title: Retrieve Record Merge Results -->

# Retrieve Record Merge Results

Given a `job_id` for a merge records job, retrieve the job results.

Before submitting this request:

* You must have previously requested a record merge job which is no longer `IN_PROGRESS`.
* You must have a valid `job_id` field value returned from the record merge operation.

GET`/api/{version}/vobjects/merges/{job_id}/results`

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
https://myvault.veevavault.com/api/v26.2/vobjects/merges/863301/results
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "merge_sets": [
           {
               "duplicate_record_id": "0V0000000000003",
               "main_record_id": "0V0000000000013",
               "status": "FAILURE",
               "error": {
                   "type": "INVALID_DATA",
                   "message": "Failed validation. Merge was not attempted."
               }
           }
]
```

## Response Details

On `SUCCESS`, Vault returns the results of the record `merge_sets` that attempted to merge.

For each of the `merge_sets` that return a `status` of `FAILURE`, Vault may return one of the following error `type`s:

* `INVALID_DATA`: The merge was not attempted
* `PROCESSING_ERROR`: The merge was attempted, but failed during processing
