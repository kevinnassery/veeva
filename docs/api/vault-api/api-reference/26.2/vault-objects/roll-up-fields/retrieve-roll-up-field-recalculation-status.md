<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/roll-up-fields/retrieve-roll-up-field-recalculation-status/ -->
<!-- title: Retrieve Roll-up Field Recalculation Status -->

# Retrieve Roll-up Field Recalculation Status

Determine whether a Roll-up field recalculation is currently running. [Learn more about Roll-up fields in Vault Help](https://platform.veevavault.help/en/gr/15057/#roll-up-fields).

GET`/api/{version}/vobjects/{object_name}/actions/recalculaterollups`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object for which to check the status of a Roll-up field recalculation. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/actions/recalculaterollups
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS", 
    "data": { 
        "status": "RUNNING" 
    }
}
```

## Response Details

On `SUCCESS`, the response specifies the status of the Roll-up field recalculation as either `RUNNING` or `NOT_RUNNING`.
