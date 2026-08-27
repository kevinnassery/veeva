<!-- source: https://general.veevavault.dev/vql/functions-options/caseinsensitive/ -->
<!-- title: CASEINSENSITIVE() -->

# CASEINSENSITIVE()

By default, field values in the `WHERE` clause are [case sensitive](/vql/references/language-specifications/syntax-basics#Case_Sensitivity). In v14.0+, use the `CASEINSENSITIVE()` function in the `WHERE` clause to bypass field case sensitivity.

## Syntax

Copy to clipboard

```
SELECT {field}
FROM {query target}
WHERE CASEINSENSITIVE({field}) {operator} {value}
```

The `{field}` parameter must be the name of an object field of type String.

## Query Examples

The following are examples of queries using `CASEINSENSITIVE()`.

### Query

The following example returns *Product* records where the *Name* field value is ‘cholecap’ in any letter case:

Copy to clipboard

```
SELECT name__v
FROM product__v
WHERE CASEINSENSITIVE(name__v) = 'cholecap'
```

### Response

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
           "name__v": "CholeCap"
       }
   ]
}
```
