<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/retrieve-object-records/ -->
<!-- title: Retrieve Object Records -->

# Retrieve Object Records

To retrieve all records for a specific Vault object, use [VQL](/vault-api/api-reference/26.2/vault-query-language-vql) or the [Direct Data API](/vault-api/api-reference/26.2/direct-data/retrieve-available-direct-data-files).

For example, the following VQL query will retrieve all records for a specific object:

POST`/api/{version}/query`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value. For example,`product__v`, `country__v`, `custom_object__c`. |

## Body Parameters

| Name | Description |
| --- | --- |
| `q` | `SELECT id, name__v FROM {object_name}` where `{object_name}` is the `name__v` field value of the object to retrieve records. |

## Request

Copy to clipboard

```
curl -L 'myvault.veevavault.com/api/v26.2/query' \
--header 'Authorization: {AUTH_VALUE}' \
--header 'Accept: application/json' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'q=SELECT id, name__v FROM product__v'
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 26,
        "total": 26
    },
    "data": [
        {
            "id": "00P000000000101",
            "name__v": "WonderDrug"
        },
        {
            "id": "00P000000000102",
            "name__v": "VeevaProm XR"
        },
        {
            "id": "00P000000000201",
            "name__v": "VeevaProm"
        },
        {
            "id": "00P000000000202",
            "name__v": "Cholecap"
        },
        {
            "id": "00P000000000301",
            "name__v": "Restolar"
        },
        {
            "id": "00P000000000303",
            "name__v": "Felinsulin"
        },
        {
            "id": "00P000000000306",
            "name__v": "Labrinone"
        },
        {
            "id": "00P000000000601",
            "name__v": "Nyaxa"
        },
        {
            "id": "00P000000000602",
            "name__v": "Gludacta"
        },
        {
            "id": "00P00000000H002",
            "name__v": "CholeCap"
        }
    ]
}
```
