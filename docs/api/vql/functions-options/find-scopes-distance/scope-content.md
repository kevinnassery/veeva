<!-- source: https://general.veevavault.dev/vql/functions-options/find-scopes-distance/scope-content/ -->
<!-- title: SCOPE CONTENT -->

# SCOPE CONTENT

In v8.0+, use `SCOPE CONTENT` with `FIND` to search within document content.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM documents
FIND ('{search phrase}' SCOPE CONTENT)
```

## Query Examples

The following are examples of queries using `SCOPE CONTENT`.

### Query: Search Document Content

The following query retrieves documents with the search term *insulin* within the content:

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('insulin' SCOPE CONTENT)
```

### Query: Search Related Document Content

The following query retrieves *Product* records where the term *cholecap* appears in the content of the *Materials* (`materials__c`) related document:

Copy to clipboard

```
SELECT id, name__v
FROM product__v
WHERE id IN (SELECT id FROM materials__cr FIND ('cholecap' SCOPE CONTENT))
```
