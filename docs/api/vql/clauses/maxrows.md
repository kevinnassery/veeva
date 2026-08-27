<!-- source: https://general.veevavault.dev/vql/clauses/maxrows/ -->
<!-- title: MAXROWS -->

# MAXROWS

In v20.3+, use the `MAXROWS` clause to retrieve a maximum of N results, applied after any filters.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
MAXROWS {number}
```

## Query Examples

The following are examples of queries using `MAXROWS`.

### Query: Retrieve a Maximum of N Documents

The following query returns a maximum of 500 documents:

Copy to clipboard

```
SELECT id
FROM documents
MAXROWS 500
```

### Query: Use MAXROWS with PAGESIZE

When used with the [`PAGESIZE` clause](/vql/clauses/pagesize), the `MAXROWS` clause must come first. The following query returns a maximum total of three (3) documents with one (1) result per page:

Copy to clipboard

```
SELECT username__sys
FROM user__sys
MAXROWS 3
PAGESIZE 1
```
