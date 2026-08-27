<!-- source: https://general.veevavault.dev/vql/operators/comparison-operators/ -->
<!-- title: Comparison Operators -->

# Comparison Operators

VQL supports keyword and symbolic operators for comparison between field values and user-provided values in the [`WHERE` clause](/vql/clauses/where). Some operators are also supported in other clauses, such as `LIKE` in the [`SHOW` clause](/vql/clauses/show).

## Keyword Operators

When querying documents or Vault objects, you can use the keyword comparison operators in clauses that support them, such as the [`WHERE` clause](/vql/clauses/where).

### BETWEEN

Use the `BETWEEN` operator with `AND` to compare data between two different values. The following query returns the documents created between the dates of ‘2018-11-01’ and '2018-12-01’.

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE document_creation_date__v BETWEEN '2018-11-01' AND '2018-12-01'
```

### CONTAINS

Use the `CONTAINS` operator to test whether a field matches any of the values provided in parentheses. This uses the `OR` operator logic. The following query returns documents with *English* OR *Spanish* OR *French* set on the language field.

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE TONAME(language__v)
CONTAINS ('english__c', 'spanish__c', 'french__c')
```

Note

[Legacy workflow](/vql/query-targets/workflows#Legacy_Workflow) queries do not support the `CONTAINS` operator.

### IN

Use the `IN` operator to test whether a field value (placed before the `IN` operator) is in the list of values provided after the `IN` operator.

The following query returns the `id` for all products referenced by a document.

Copy to clipboard

```
SELECT id
FROM product__v
WHERE id
IN (SELECT id FROM document_product__vr)
```

The `IN` operator can only be used for inner join relationship queries on documents and objects.

The `WHERE IN` subquery uses the **relationship name** to identify the connection between objects. It then qualifies the primary records based on the existence of related records (and any additional criteria defined within the subquery).

Note

Using the `id` field is a convention to simplify the query syntax. VQL performs the join automatically based on the relationship name, not the specified field.

### LIKE

Use the `LIKE` operator with the wildcard character `%` to search for matching field values when you don't know the entire value.

The following query returns documents where the `name__v` value starts with *N*.

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE name__v LIKE 'N%'
```

`SELECT` statements do not support `LIKE '%string'` (with a leading wildcard). For example, `LIKE '%DOC` will return an error response.

[SHOW statements](/vql/clauses/show) do support the leading wildcard on `LIKE`. For example, `LIKE '%__v'` will find names ending in `__v`.

## Symbolic Operators

You can use symbolic comparison operators in the [`WHERE` clause](/vql/clauses/where).

### Equal to (`=`)

Copy to clipboard

```
SELECT id, user_name__v, security_profile__v
FROM users
WHERE user_locale__v = 'es_US'
```

### Not Equal to (`!=`)

Copy to clipboard

```
SELECT label__sys, due_date__sys
FROM active_workflow_task__sys
WHERE status__sys != 'available__sys'
```

### Less than (`<`)

Copy to clipboard

```
SELECT id, document_number__v
FROM documents
WHERE document_creation_date__v < '2016-04-23'
```

### Greater than (`>`)

Copy to clipboard

```
SELECT id, site_status__v, location__v
FROM site__v
WHERE modified_date__v > '2016-04-23'
```

### Less than or Equal to (`<=`)

Copy to clipboard

```
SELECT id, document_number__v
FROM documents
WHERE version_modified_date__v <= '2016-04-23T07:30:00.000Z'
```

### Greater than or Equal to (`>=`)

Copy to clipboard

```
SELECT id, document_number__v
FROM documents
WHERE version_modified_date__v >= '2016-04-23T07:30:00.000Z'
```
