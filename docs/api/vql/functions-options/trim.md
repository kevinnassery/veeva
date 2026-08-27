<!-- source: https://general.veevavault.dev/vql/functions-options/trim/ -->
<!-- title: TRIM() -->

# TRIM()

By default, VQL returns picklist field values with a namespace suffix, such as the `__c` in `hematology__c`. In v25.1+, use the `TRIM()` function in the `SELECT` clause to return picklist field values without the namespace suffix, such as `hematology`.

## Syntax

Copy to clipboard

```
SELECT TRIM({field})
FROM {query target}
```

The `{field}` parameter must be the name of a field of type *Picklist*.

## Query Examples

The following are examples of queries using `TRIM()`.

### Query

The following example returns both the full and trimmed *Therapeutic Area* field from *Product* records:

Copy to clipboard

```
SELECT id, therapeutic_area__c, TRIM(therapeutic_area__c) AS therapeutic_area_trimmed
FROM product__v
```

### Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 2,
       "total": 2
   },
   "data": [
       {
            "id": "00P000000007001",
            "therapeutic_area__c": [
                "endocrinology__c"
            ],
            "therapeutic_area_trimmed": [
                "endocrinology"
            ]
        },
        {
            "id": "00P000000008001",
            "therapeutic_area__c": [
                "hematology__c"
            ],
            "therapeutic_area_trimmed": [
                "hematology"
            ]
        },

   ]
}
```
