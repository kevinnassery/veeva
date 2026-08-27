<!-- source: https://general.veevavault.dev/vql/functions-options/find-scopes-distance/scope-properties/ -->
<!-- title: SCOPE PROPERTIES -->

# SCOPE PROPERTIES

In v8.0+, use `SCOPE PROPERTIES` with `FIND` to search all picklists and document or object fields with data type String (*Text*, *LongText*, and *RichText* fields).

When using `FIND` without `SCOPE`, the query uses `SCOPE PROPERTIES` by default.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
FIND ('{search phrase}' SCOPE PROPERTIES)
```
