<!-- source: https://general.veevavault.dev/vql/functions-options/statetype/ -->
<!-- title: STATETYPE() -->

# STATETYPE()

By default, object queries retrieve fields from all object records in any state. In v19.3+, use the `STATETYPE()` function with the `WHERE` clause to filter object records by lifecycle state (`state__v`) associated with an object state type. Learn more about object record state types in [Vault Help](https://platform.veevavault.help/en/lr/56431).

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
WHERE state__v = STATETYPE('{state_type}')
```

You can only use the `STATETYPE()` function with the `state__v` field. The `{state_type}` parameter must be the name of a state type and must be enclosed in single quotes.

## Query Examples

The following are examples of queries using `STATETYPE()`.

### Query

The following query returns the ID and lifecycle state of all *Product* records in a lifecycle state associated with the *Initial* state type:

Copy to clipboard

```
SELECT id, state__v
FROM product__v
WHERE state__v = STATETYPE('initial_state__sys')
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
           "id": "00P000000000508",
           "state__v": "draft_state__c"
       },
       {
           "id": "00P000000000509",
           "state__v": "draft_state__c"
       }
   ]
}
```
