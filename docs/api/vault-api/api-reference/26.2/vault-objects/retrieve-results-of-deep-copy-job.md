<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/retrieve-results-of-deep-copy-job/ -->
<!-- title: Retrieve Results of Deep Copy Job -->

# Retrieve Results of Deep Copy Job

After submitting a request to deep copy an object record, you can query Vault to determine the results of the request.
Before submitting this request:

* You must have previously requested a deep copy job (via the API) which is no longer active.
* You must have a valid `job_id` value, retrieved from the response of the deep copy request.

GET`/api/{version}/vobjects/deepcopy/results/{object_name}/{job_status}/{job_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `text/csv` (default) |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `object_name` | The name of the deep copied object. |
| `job_id` | The ID of the job, retrieved from the response of the job request. |
| `job_status` | Possible values are `success` or `failure`. Find if your job succeeded or failed by retrieving the job status. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Accept: text/csv" \
https://myvault.veevavault.com/api/v26.2/vobjects/deepcopy/results/product__v/failure/26901
```

## Response

Copy to clipboard

```
line number,vobject,sourceRecordId,errors
1,product__v,00P000000000301,"""PARAMETER_REQUIRED|Missing required parameter [internal_name__c]"",""OPERATION_NOT_ALLOWED|Another resource already exists with [name__v=WonderDrug]"""
```
