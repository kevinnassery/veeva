<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/update-corporate-currency-fields/ -->
<!-- title: Update Corporate Currency Fields -->

# Update Corporate Currency Fields

Currency is a field type available on all Vault objects. Whenever a user populates a local currency field value, Vault automatically populates the related corporate currency field value, except in the following scenarios:

* Admins change the Corporate Currency setting for the vault
* Admins update the Rate setting for the local currency used by a record

This endpoint updates the `field_corp__sys` field values of an object record based on the Rate of the currency, denoted by the `local_currency__sys` field of the specified record. Learn more about [Currency Fields](https://platform.veevavault.help/en/gr/50532) in Vault Help.

PUT`/api/{version}/vobjects/{object_name}/actions/updatecorporatecurrency`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value, for example, `product__v`. |

## Body Parameters

| Name | Description |
| --- | --- |
| `id` optional | The object record `id` field value. If you don't provide an `id`, Vault updates corporate fields of all records for the object. |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
-d "id=00P000000000301" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/actions/updatecorporatecurrency
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "job_id": 81603,
    "url": "/api/v26.2/services/jobs/81603"
}
```
