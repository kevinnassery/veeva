<!-- source: https://general.veevavault.dev/vql/clauses/pageoffset/ -->
<!-- title: PAGEOFFSET -->

# PAGEOFFSET

Note

This clause can result in poor query performance on large datasets. Learn more about [performance issues with pagination](/vql/references/pagination-best-practices).

When the number of results found exceeds the number displayed per page, use the `PAGEOFFSET` clause to display the next and previous pages of results. `PAGEOFFSET` is available in v20.3+.

For example, if a query returns 500 total results and the `PAGESIZE` is set to display 100 results per page:

* The first page displays results 0–99. To see the second page, use `PAGESIZE 100 PAGEOFFSET 100`.
* The second page displays results 100–199. To see the third page, use `PAGESIZE 100 PAGEOFFSET 200`.

The response includes the `next_page` and `previous_page` URL endpoints when pagination is available. Learn more about [paginating results](/vql/references/pagination-best-practices).

In v20.2 or lower, you must use `OFFSET` instead of `PAGEOFFSET`. If you use both `OFFSET` and `PAGEOFFSET` in a query, the query will ignore `OFFSET`.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
PAGEOFFSET {number}
```

## Query Examples

The following are examples of queries using `PAGEOFFSET`.

### Query

The following query returns results 200 to 299:

Copy to clipboard

```
SELECT id
FROM documents
PAGESIZE 100 PAGEOFFSET 200
```

### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 100,
        "pageoffset": 200,
        "size": 100,
        "total": 500,
        "previous_page": "/api/v20.3/query/c2b58293-1606-4c99-925d-b9b89e83670e?pagesize=100&pageoffset=100",
        "next_page": "/api/v20.3/query/c2b58293-1606-4c99-925d-b9b89e83670e?pagesize=100&pageoffset=300"
    }
}
```

## OFFSET

Note

Deprecated as of v20.3: Instead, use [`PAGEOFFSET`](/vql/clauses/pageoffset).

When the number of results found exceeds the number displayed per page, use the `OFFSET` clause to display the next and previous pages of results.

For example, if a query returns 500 total results and the `LIMIT` is set to display 100 results per page:

* The first page displays results 0–99. To see the second page, use `LIMIT 100 OFFSET 100`.
* The second page displays results 100–199. To see the third page, use `LIMIT 100 OFFSET 200`.

The response includes the `next_page` and `previous_page` URL endpoints when pagination is available. Learn more about [paginating results](/vql/references/pagination-best-practices).

### Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
OFFSET {number}
```

### Query Examples

The following are examples of queries using `OFFSET`.

#### Query

The following query returns results 200 to 299:

Copy to clipboard

```
SELECT id
FROM documents
LIMIT 100 OFFSET 200
```

### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "limit": 100,
        "offset": 200,
        "size": 100,
        "total": 500,
        "previous_page": "/api/v11.0/query/c2b58293-1606-4c99-925d-b9b89e83670e?limit=100&offset=100",
        "next_page": "/api/v11.0/query/c2b58293-1606-4c99-925d-b9b89e83670e?limit=100&offset=300"
    }
}
```
