<!-- source: https://general.veevavault.dev/vql/functions-options/toname/ -->
<!-- title: TONAME() -->

# TONAME()

By default, queries on documents use field labels instead of field names. In v20.3+, use the `TONAME()` function to use the field name when querying document fields:

* Use `TONAME()` with `SELECT` to retrieve the field name instead of the field label.
* Use `TONAME()` with `WHERE` to provide the field name as the filter value.

When querying documents, it is best practice to use `TONAME()` in the `WHERE` clause to provide the field name as the filter value. This ensures that the filter works for all users, including those with localized labels in their Vault.

You can only use `TONAME()` in `documents` queries on the following document fields:

* Document lifecycle (`lifecycle__v`)
* Document lifecycle state (`status__v`)
* Type (`type__v`)
* Subtype (`subtype__v`)
* Classification (`classification__v`)
* All document `Picklist` type fields

## Syntax

Copy to clipboard

```
SELECT TONAME({field})
FROM {query target}
WHERE TONAME({field}) {operator} {value}
```

The `{field}` parameter must be the name of one of the supported fields.

## Query Examples

The following are examples of queries using `TONAME()`.

### Query

The following query filters by the `status__v` field name and returns both the field name and label:

Copy to clipboard

```
SELECT TONAME(status__v) AS StatusName, status__v
FROM documents
WHERE TONAME(status__v) = 'draft__c'
```

### Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 3,
       "total": 3
   },
   "data": [
       {
           "StatusName": "draft__c",
           "status__v": "Draft"
       },
       {
           "StatusName": "draft__c",
           "status__v": "Draft"
       },
       {
           "StatusName": "draft__c",
           "status__v": "Draft"
       }
   ]
}
```
