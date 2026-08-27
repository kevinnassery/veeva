<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/cascade-delete-object-record/ -->
<!-- title: Cascade Delete Object Record -->

# Cascade Delete Object Record

This asynchronous endpoint will delete a single parent object record and all related children and grandchildren.

POST`/api/{version}/vobjects/{object_name}/{object_record_id}/actions/cascadedelete`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `text/csv` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object to delete. |
| `{object_record_id}` | The ID of the specific object record to delete. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/00P000000000302/actions/cascadedelete
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "job_id": 27301,
  "url": "/api/v26.2/services/jobs/27404"
}
```
