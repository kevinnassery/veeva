<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-types/change-object-type/ -->
<!-- title: Change Object Type -->

# Change Object Type

Change the object types assigned to object records. Any field values that exist on both the original and new object type will carry over to the new type. All other field values will be removed, as only fields on the new type are valid. You can set field values on the new object type in the CSV input.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the [standard format](https://datatracker.ietf.org/doc/html/rfc4180).
* The maximum batch size is 500.

POST`/api/{version}/vobjects/{object_name}/actions/changetype`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object. |

## Body Parameters

Upload parameters as a JSON or CSV file.

| Name | Description |
| --- | --- |
| `id` required | The ID of the object record. |
| `object_type__v` required | The ID of the new object type. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: application/json" \
--data-raw 'id,object_type__v
00P07710,new_product__c' \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/actions/changetype
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "00P07710",
                "url": "api/v24.2/vobjects/product__v/00P07710"
            }
        }
    ]
}
```
