<!-- source: https://general.veevavault.dev/vql/functions-options/find-scopes-distance/scope-all/ -->
<!-- title: SCOPE ALL -->

# SCOPE ALL

In v8.0+, use `SCOPE ALL` with `FIND` to search document fields and within document content.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM documents
FIND ('{search phrase}' SCOPE ALL)
```

## Query Examples

The following are examples of queries using `SCOPE ALL`.

### Query

The example query below searches document content and all queryable fields.

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('insulin' SCOPE ALL)
```
