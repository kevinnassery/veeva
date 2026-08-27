<!-- source: https://general.veevavault.dev/vql/clauses/pagesize/ -->
<!-- title: PAGESIZE -->

# PAGESIZE

By default, the maximum number of results displayed per page is 200 for documents and 1000 for objects. In v20.3+, use the `PAGESIZE` clause to limit the number of results returned per page.

Using `PAGESIZE` does not change the total number of results found, only the number displayed per page.

Learn more about [limiting page results](/vql/references/system-limits-performance/page-size-specifications).

If you’re using VQL version v20.2 or lower, you must use `LIMIT` instead of `PAGESIZE`. If you use both `LIMIT` and `PAGESIZE` in a query, the query ignores `LIMIT`.

Note

Vault may [scale down the page size](/vql/references/system-limits-performance/page-size-specifications) to protect performance.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
PAGESIZE {number}
```

## Query Examples

The following are examples of queries using `PAGESIZE`.

### Query

The following query returns 25 documents per page:

Copy to clipboard

```
SELECT id
FROM documents
PAGESIZE 25
```

## LIMIT

Note

Deprecated as of v20.3. Instead, use [`PAGESIZE`](/vql/clauses/pagesize).

By default, the maximum number of results displayed per page is 200 for documents and 1000 for objects. Use the `LIMIT` clause to limit the number of results returned per page.

Using `LIMIT` does not change the total number of results found, only the number displayed per page.

Learn more about [limiting page results](/vql/references/system-limits-performance/page-size-specifications).

### Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
LIMIT {number}
```

### Query Examples

The following are examples of queries using `LIMIT`.

#### Query

The following query returns 25 documents per page:

Copy to clipboard

```
SELECT id
FROM documents
LIMIT 25
```
