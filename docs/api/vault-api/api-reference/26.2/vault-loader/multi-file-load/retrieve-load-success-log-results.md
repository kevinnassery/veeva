<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-loader/multi-file-load/retrieve-load-success-log-results/ -->
<!-- title: Retrieve Load Success Log Results -->

# Retrieve Load Success Log Results

Retrieve success logs of loader results.

GET`/api/{version}/services/loader/{job_id}/tasks/{task_id}/successlog`

## Headers

The `Accept` header only changes the format of the response in the case of an error. This does not change the file format of the download.

| Name | Description |
| --- | --- |
| `Accept` | `application/json` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `job_id` | The `id` value of the requested load job. |
| `task_id` | The `id` value of the requested load task. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
- H "Content-Type: application/json" \
https://myveevavault.com/api/v26.2/services/loader/61907/tasks/1/successlog
```

## Response

Copy to clipboard

```
responseStatus,id,name__v,external_id__v,errors,rowId,event,id_param__value
SUCCESS,00P000000000807,,,,1,created__sys,
SUCCESS,00P000000000808,,,,2,created__sys,
SUCCESS,00P000000000809,,,,3,updated__sys,00P000000000809
```

## Response Details

On `SUCCESS`, the response includes a CSV file with the success log of loader results.

The response may include the following additional information:

| Metadata Field | Description |
| --- | --- |
| `event` | Whether the record was created (`created__sys`) or updated (`updated__sys`). Only included for upsert actions. |
| `id_param_value` | The value of the field specified by the `idparam` body parameter if provided when loading data objects. For example, if `idparam=external_id__v`, the `id_param_value` returned is the same as the record's external ID. |
