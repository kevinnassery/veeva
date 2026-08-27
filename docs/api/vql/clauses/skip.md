<!-- source: https://general.veevavault.dev/vql/clauses/skip/ -->
<!-- title: SKIP -->

# SKIP

In v20.3+, use the `SKIP` clause to skip first N results. The results start at result N + 1.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
SKIP {number}
```

## Query Examples

The following are examples of queries using `SKIP`.

### Query

The following query skips the first 25 results. The first result returned is result 26.

Copy to clipboard

```
SELECT id
FROM documents
SKIP 25
```
