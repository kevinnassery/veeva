<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/roll-up-fields/recalculate-roll-up-fields/ -->
<!-- title: Recalculate Roll-up Fields -->

# Recalculate Roll-up Fields

Recalculate all Roll-up fields for the specified object. [Learn more about Roll-up fields in Vault Help](https://platform.veevavault.help/en/gr/15057/#roll-up-fields).

When performing a full recalculation, Vault evaluates all Roll-up fields on an object asynchronously.

This endpoint is equivalent to the *Recalculate Roll-up Fields* action in the Vault UI. While a recalculation is running, Admins cannot start another recalculation using either Vault API or Vault UI.

POST`/api/{version}/vobjects/{object_name}/actions/recalculaterollups`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object on which to start the Roll-up field recalculation. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/actions/recalculaterollups
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "SUCCESS"
}
```

## Response Details

Returns `SUCCESS` if the recalculation starts successfully, or `FAILURE` if a recalculation is already running for the specified object.
