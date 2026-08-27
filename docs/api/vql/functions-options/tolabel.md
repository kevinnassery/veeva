<!-- source: https://general.veevavault.dev/vql/functions-options/tolabel/ -->
<!-- title: TOLABEL() -->

# TOLABEL()

By default, queries on Vault objects use field names instead of the field labels shown in the Vault UI. In v24.1+, the `TOLABEL()` function uses the localized field label when querying object fields:

* Use `TOLABEL()` with `SELECT` to retrieve the field label.
* Use `TOLABEL()` with `WHERE` to provide the field label as the filter value.
* Use `TOLABEL()` with `ORDER BY` to order results by the field label.

You can use `TOLABEL()` on standard Vault object queries on the following fields:

* Object lifecycle (`lifecycle__v`)
* Object lifecycle state (`state__v`)
* All object Picklist type fields
* Object Type (`object_type__v`) to retrieve object type labels, including localized labels

You cannot use `TOLABEL()` on raw object fields.

## Syntax

Copy to clipboard

```
SELECT TOLABEL({field})
FROM {query target}
WHERE TOLABEL({field}) {operator} {value}
ORDER BY TOLABEL({field})
```

The `{field}` parameter must be the name of one of the supported fields.

## Query Examples

The following are examples of queries using `TOLABEL()`.

### Query

The following query filters by the `state__v` field label and returns both the field name and label:

Copy to clipboard

```
SELECT id, TOLABEL(state__v) AS LifecycleStateLabel, state__v
FROM product__v
WHERE TOLABEL(state__v) = 'Closed'
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
           "id": "V4S000000004002",
           "LifecycleStateLabel": "Closed",
           "state__v": "closed_state__c"
       },
        {
           "id": "V4S000000004003",
           "LifecycleStateLabel": "Closed",
           "state__v": "closed_state__c"
       }
   ]
}
```

## Retrieve Object Type Labels

The following query returns localized object type labels in the authenticated user's language, French, from a Vault with English as its base language:

Copy to clipboard

```
SELECT name__v, object_type__v,
TOLABEL(object_type__v) AS object_type_label,
object_type__vr.name__v, object_type__vr.api_name__v
FROM bicycle__c
```

### Response: Retrieve Object Type Labels

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 1,
        "total": 1
    },
    "data": [
        {
            "name__v": "Cannondale",
            "object_type__v": "OOT00000002E002",
            "object_type_label": "Vélo de route",
            "object_type__vr.name__v": "Road Bike",
            "object_type__vr.api_name__v": "road_bike__c"
        }
    ]
}
```
