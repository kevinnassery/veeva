<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/retrieve-results-of-cascade-delete-job/ -->
<!-- title: Retrieve Results of Cascade Delete Job -->

# Retrieve Results of Cascade Delete Job

After submitting a request to cascade delete an object record, you can query Vault to determine the results of the request.
Before submitting this request:

* You must have previously requested a cascade delete job (via the API) which is no longer active.
* You must have a valid `job_id value`, retrieved from the response of the cascade delete request.

GET`/api/{version}/vobjects/cascadedelete/results/{object_name}/{job_status}/{job_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `text/csv` (default) |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object which was deleted. |
| `{job_id}` | The ID of the job, retrieved from the response of the job request. |
| `{job_status}` | Possible values are `success` or `failure`. Find if your job succeeded or failed by retrieving the job status. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Accept: text/csv" \
https://myvault.veevavault.com/api/v26.2/vobjects/cascadedelete/results/product__v/success/27404
```

## Response

Copy to clipboard

```
Source Object, Record Id
product__v, OP0000146
edl__v, OE0000147
edl_item__v, EE123456
```
