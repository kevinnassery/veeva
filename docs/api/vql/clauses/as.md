<!-- source: https://general.veevavault.dev/vql/clauses/as/ -->
<!-- title: AS -->

# AS

By default, VQL queries return fields in key-value pairs where the key is the field name. You can use the `AS` clause with the `SELECT` clause to define an optional alias:

* In v20.3+ (documents) and v21.1+ (objects), use the `AS` clause to define an alias for a function on a field.
* In v24.2+, use the `AS` clause to define an alias on any document or object field.

The alias name:

* Can be any string as long as it is not identical to a field name in the query target.
* Must not exceed 40 characters.
* Can only contain letters, numbers, and underscores (`_`) and cannot contain more than one consecutive underscore. Whitespaces are not supported.
* Must not be one of the reserved keywords, including VQL grammar constructs such as `SELECT`. Click below for a complete list of reserved keywords.

[Download File](/sample-files/vql-restricted-keywords.csv)

Aliases are scoped to the query target. Therefore, you can use the same alias name in the main query and a subquery. If a query includes the same field both by itself and modified by a function, you must use the `AS` clause to define an alias for the function.

Note

When a query includes the `AS` clause, the `queryDescribe` object includes `“alias”: “true”`.

## Syntax

Copy to clipboard

```
SELECT {field} AS {alias}
FROM {query target}
```

## Query Examples

The following are examples of queries using `AS`.

### Query: Aliasing Object Functions on Fields

The following query retrieves the ID and the default value of the *Packaging Text* field and uses the `LONGTEXT()` function to retrieve the full (long text) value of the *Packaging Text* field. The query uses an alias to distinguish between the default and full field values.

Copy to clipboard

```
SELECT id, packaging_text__c, LONGTEXT(packaging_text__c) AS package_fulltext
FROM product__v
WHERE name__v = 'Cholecap'
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
           "id": "cholecap",
           "packaging_text__c": "Your blood cholesterol level has a lot to do with\nyour chances of getting heart disease. High blood cholesterol is one of the major risk factors for heart disease. A risk factor is a condition that increases your chance of getting a disease. In fact,",
           "package_fulltext": "Your blood cholesterol level has a lot to do with\nyour chances of getting heart disease. High blood cholesterol is one of the major risk factors for heart disease. A risk factor is a condition that increases your chance of getting a disease. In fact, the higher your blood cholesterol level, the greater your risk for developing heart disease or having a heart attack. Heart disease is the number one killer of women and men in the United States. Each year, more than a million Americans have heart attacks, and about a half million people die from heart disease."
       }
   ]
}
```

### Query: Aliasing and Ordering by Object Fields

The following query creates an alias for both the `name__v` field and the `country__cr.name__v` relationship and orders the results using the `name` alias:

Copy to clipboard

```
SELECT name__v as name, country__cr.name__v AS country
FROM product__v
ORDER BY name
```

### Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 4,
       "total": 4
   },
   "data": [
       {
           "name": "Adalarase",
           "country": "USA"
       },
       {
           "name": "Adalarase EX",
           "country": "USA"
       },
       {
           "name": "Amsirox",
           "country": "Canada"
       },
       {
           "name": "Cholecap",
           "country": "Canada"
       }
  ]
}
```

### Query: Using an Alias in a Function

The following query creates an alias for the `lifecycle__v` field and then uses the alias as the argument in the `TONAME()` function:

Copy to clipboard

```
SELECT id, lifecycle__v as lifecycleLabel
FROM documents
WHERE TONAME(lifecycleLabel) = 'general_lifecycle__c'
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
            "id": 303,
            "lifecycleLabel": "General Lifecycle"
        },
        {
            "id": 301,
            "lifecycleLabel": "General Lifecycle"
        },
        {
            "id": 201,
            "lifecycleLabel": "General Lifecycle"
        }
    ]
}
```
