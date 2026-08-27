<!-- source: https://general.veevavault.dev/vql/clauses/order-by/ -->
<!-- title: ORDER BY -->

# ORDER BY

You can use the `ORDER BY` and `ORDER BY RANK` clauses to order the results returned from your Vault.

## Ordering by Field

In v8.0+, use `ORDER BY` to control the order of query results. You can specify either ascending (`ASC`) or descending order (`DESC`).

VQL does not support sorting by reference objects such as `product__v.name__v`.

In v24.2+, the `users` query target does not support sorting by the `created_by__v` or `modified_by__v` fields. Previous versions may return invalid results.

### Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
ORDER BY {field} ASC|DESC
```

### Functions & Options

You can use the following functions and query target options in the `ORDER BY` clause. For full technical details, see the [VQL Functions & Options](/vql/functions-options) reference.

#### Refining Sort Order

| Name | Goal | API Version |
| --- | --- | --- |
| [`FILENAME()`](/vql/functions-options/attachment-field-functions) | Sort results by the file name of an Attachment field. | v24.3+ |
| [`TOLABEL()`](/vql/functions-options/tolabel) | Sort results by the localized label of an object field. | v24.1+ |

### Query Examples

The following are examples of queries using `ORDER BY`.

#### Query: Retrieve Documents in Ascending Order

This following query returns document IDs in ascending numerical order:

Copy to clipboard

```
SELECT id, name__v
FROM documents
ORDER BY id ASC
```

#### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 54,
        "total": 54
    },
    "data": [
        {
            "id": 1,
            "name__v": "Binders v10 Video"
        },
        {
            "id": 2,
            "name__v": "PowerPoints 20R3"
        },
        {
            "id": 3,
            "name__v": "Video Script Creating Tabular Reports"
        }
   ]
}
```

#### Query: Retrieve Documents in Descending Order

This query returns document names in descending alphabetical order:

Copy to clipboard

```
SELECT id, name__v
FROM documents
ORDER BY name__v DESC
```

#### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 54,
        "total": 54
    },
    "data": [
        {
            "id": 44,
            "name__v": "WonderDrug Research"
        },
        {
            "id": 26,
            "name__v": "Ways to Get Help"
        },
        {
            "id": 4,
            "name__v": "VeevaProm Information"
        },
        {
            "id": 7,
            "name__v": "Time-Release Medication"
        },
  ]
}
```

#### Query: Enforcing Primary and Secondary Order

You can enforce both the primary and secondary order of results by using a comma-separated string of field names. The field sort priority is left to right.

Copy to clipboard

```
SELECT name__v, type__v
FROM documents
ORDER BY type__v DESC, name__v DESC
```

#### Response

The response includes results sorted first by type and then by name, both in descending order.

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 54,
        "total": 54
    },
    "data": [
        {
            "name__v": "VeevaProm Resource Doc",
            "type__v": "Resource"
        },
        {
            "name__v": "Nyaxa Resource Doc",
            "type__v": "Resource"
        },
        {
            "name__v": "CholeCap Logo",
            "type__v": "Promotional Material"
        }
   ]
}
```

## Ordering by Rank

In v10.0+, use the `ORDER BY RANK` clause with `FIND` to sort documents by relevance to a search phrase. Doing so matches the default result ordering for the same search in the Vault UI.

Note

`ORDER BY RANK` is only supported for `documents` queries. Since the default behavior for Vault object queries is to sort by rank, including `ORDER BY RANK` in Vault object queries results in an error.

### Syntax

Copy to clipboard

```
SELECT {fields}
FROM documents
FIND ('{search phrase}')
ORDER BY RANK
```

### Query Examples

The following are examples of queries using `ORDER BY RANK`.

#### Query

The following query sorts the results in descending order, starting with those most closely matching the search phrase:

Copy to clipboard

```
SELECT id, name__v
FROM documents FIND ('ABC')
ORDER BY RANK
```

#### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 54,
        "total": 54
    },
    "data": [
        {
            "id": 26,
            "name__v": "Document ABC"
        },
        {
            "id": 44,
            "name__v": "Document ABCD"
        },
        {
            "id": 4,
            "name__v": "Document ABCDE"
        }
  ]
}
```
