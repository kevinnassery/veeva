<!-- source: https://general.veevavault.dev/vql/clauses/find/ -->
<!-- title: FIND -->

# FIND

Use `FIND` to search documents and Vault objects.

When using `FIND` on documents, Vault searches all queryable document fields. You can configure object references to search additional object fields by configuring Searchable Object Fields. Learn more in [Vault Help](https://platform.veevavault.help/en/lr/29926).

* `FIND` for documents is available in Vault API v8.0+
* `FIND` for standard volume Vault objects is available in Vault API v14.0+
* `FIND` is not supported on raw Vault objects or in attachment subqueries
* `FIND` is supported in `SELECT` statements. In 25.3+, you can also use `FIND` in all subqueries except attachment subequeries.

You can [scope](/vql/functions-options/find-scopes-distance) your search to specific fields, document content, or both. When using `FIND` without `SCOPE`, VQL uses [SCOPE PROPERTIES](/vql/functions-options/find-scopes-distance/scope-properties) by default.

VQL automatically adds wildcards to most search terms. Learn more about wildcarding, search tokenization, stemming, order of evaluation, and other topics in [Searching & Filtering](/vql/references/search-specifications).

Note

When precise matching is absolutely critical, we recommend using the `WHERE` clause instead of `FIND`. `FIND` is more appropriate for interactive applications.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
FIND ('{search phrase}')
```

The `FIND` search phrase must be enclosed in single quotation marks. The entire `FIND` statement (search phrase and scopes) must be enclosed in parentheses.

The maximum search term length is 250 characters. The minimum search term length is 1 character.

The search phrase is not case sensitive.

## Functions & Options

You can use the following functions and query target options in the `FIND` clause. For full technical details, see the [VQL Functions & Options](/vql/functions-options) reference.

### Refining Search Scope

These options control which fields or content are searched.

| Name | Goal | API Version |
| --- | --- | --- |
| [`SCOPE ALL`](/vql/functions-options/find-scopes-distance/scope-all) | Search all fields and document content. | v8.0+ |
| [`SCOPE CONTENT`](/vql/functions-options/find-scopes-distance/scope-content) | Search document content only. | v8.0+ |
| [`SCOPE {fields}`](/vql/functions-options/find-scopes-distance/scope-fields) | Search one specific document field or up to 25 object fields. | v15.0+ |
| [`SCOPE PROPERTIES`](/vql/functions-options/find-scopes-distance/scope-properties) | Search all picklists and text-based fields (default scope). | v8.0+ |

### Advanced Matching

These functions and options provide more granular control over search results.

| Name | Goal | API Version |
| --- | --- | --- |
| [`DISTANCE`](/vql/functions-options/find-scopes-distance/distance) | Enable fuzzy search with an edit distance of up to 2. | v26.1+ |
| [`FILENAME()`](/vql/functions-options/attachment-field-functions) | Search by Attachment file name instead of file handle. | v24.3+ |

## Operators

You can use the following [logical operators](/vql/operators/logical-operators) in the `FIND` clause:

| Name | Syntax | Description |
| --- | --- | --- |
| [`AND`](/vql/operators/logical-operators#AND) | `FIND ('{v1} AND {v2}')` | All terms in the search string must match. |
| [`NOT`](/vql/operators/logical-operators#NOT) | `FIND (NOT '{phrase}')` | Results must not match the specified search string. |
| [`OR`](/vql/operators/logical-operators#OR) | `FIND ('{v1} OR {v2}')` | At least one term in the search string must match. |

## Query Examples

The following are examples of queries using `FIND`.

### Query: Find Documents with a Search Term Match

The following query returns the latest version of all documents that contain the search term *insulin* (case insensitive):

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('insulin')
```

### Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "find": "('insulin')",
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 3,
       "total": 3
   },
   "data": [
       {
           "id": 200,
           "name__v": "Test Doc Nyaxa Insulin"
       },
       {
           "id": 198,
           "name__v": "Test Doc Diabetes Insulin"
       },
       {
           "id": 197,
           "name__v": "Test Doc Nyaxa Diabetes Insulin"
       }
   ]
}
```

### Query: Find Objects with a Search Term Match

The following query returns the ID, compound ID, and abbreviation of all *Product* records that contain the search term *cc* in one or more fields (case insensitive):

Copy to clipboard

```
SELECT id, compound_id__c, abbreviation__c
FROM product__v
FIND ('cc')
```

### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
       "find": "('cc')",
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 2,
       "total": 2
    },
    "data": [
       {
           "id": "00P000000000302",
           "compound_id__c": "CC-123",
           "abbreviation__c": "CC"
       },
       {
           "id": "00P000000000301",
           "compound_id__c": "CC-127",
           "abbreviation__c": null
       }
    ]
}
```

### Query: Find Documents with Any Search Term

To search document fields containing any of the provided search terms, use the `OR` operator between them.

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('insulin OR diabetes')
```

### Query: Find Documents with All Search Terms

To search document fields containing all search terms, use the `AND` operator between each search term.

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('insulin AND diabetes AND Nyaxa')
```

### Query: Find Documents with an Exact Search Term Match

To search for an exact match, enclose the string in double quotes within the single quotes.

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('"blood sugar"')
```

### Query: Find Documents Using Strict Matching

A `FIND` search phrase without operators uses [strict matching](/vql/references/search-specifications/search-operators-evaluation#Strict_Matching_Using_Operators_with_FIND).

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('insulin diabetes gludacta')
```

### Query: Find Documents with a Partial Search Term Match

The following query uses the wildcard character (`*`) to retrieve partial matches.

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('ins* dia* glu*')
```

### Query: Find Documents Without a Search Term Match

Use `NOT` with `FIND` to exclude results from a query.

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND (NOT 'insulin')
```

### Query: Search Only Document Content

The following example uses the [`SCOPE CONTENT`](/vql/functions-options/find-scopes-distance/scope-content) option.

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('insulin' SCOPE CONTENT)
```

### Query: Filter Search Results with WHERE

`WHERE` must be placed after the `FIND` clause.

Copy to clipboard

```
SELECT id, name__v
FROM product__v
FIND ('phosphate' SCOPE generic_name__vs)
WHERE therapeutic_area__vs = 'cardiology__vs'
```

### Query: FIND with Inner Join Subqueries

Copy to clipboard

```
SELECT id, name__v
FROM product__v
WHERE id IN (SELECT id FROM dosages__vr FIND ('standard' SCOPE name__v))
```

### Query: FIND with Outer Join Subquery

Copy to clipboard

```
SELECT id,
(SELECT id, name__v FROM dosages__vr FIND ('standard' SCOPE name__v))
FROM product__v
```
