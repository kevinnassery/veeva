<!-- source: https://general.veevavault.dev/vql/functions-options/find-scopes-distance/distance/ -->
<!-- title: DISTANCE -->

# DISTANCE

In v26.1+, you can use the `DISTANCE` option in the parenthetical `FIND` clause to enable fuzzy search.

The `DISTANCE` option applies an edit distance to allow for minor misspellings or variations of search terms. The edit distance refers to the number of characters that can be different. For example, a query with `FIND ('dag' DISTANCE [2] SCOPE {name__v})` returns matches for both *dog* and *cat* in the `name__v` field.

* The `DISTANCE` option must be used with `SCOPE {fields}` and is not supported with other `SCOPE` options.
* The maximum edit distance is 2.
* You can use fuzzy matching on up to five `SCOPE` fields.
* The query can contain up to three fuzzy search terms (terms with non-zero distance).
* Edit distance defaults to 0 if omitted.
* You can use `AND`, `OR`, and `NOT` operators with fuzzy search.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
FIND ('{term1 terms2 term3}' DISTANCE [{dist1, dist2, dist3}] SCOPE {fields})
```

Each distance value in square brackets applies to the respective search term. For example, `dist1` applies to `term1`.

The number of distance values cannot exceed the number of individual search terms in the search phrase.

The default distance is 0 (exact match). If the number of search terms exceeds the number of distance values, terms without a corresponding distance default to distance 0.

Each fuzzy search term with a non-zero distance can contain:

* Up to 25 characters
* Non-wildcard letter characters only
* No case changes

## Query Examples

The following are examples of queries using `DISTANCE` with `SCOPE {fields}`.

### Query: Fuzzy Document Field

The following query searches the `author__v` document field for the fuzzy search term *smeth* with an edit distance of 1. This query will match the name *smith* but not *smitt*. An edit distance `DISTANCE [2]` would also match *smitt*.

Copy to clipboard

```
SELECT id, author__v
FROM documents
FIND ('smeth' DISTANCE [1] SCOPE author__v)
```

### Query: Multiple Fuzzy Terms

The following query searches *Product* descriptions for the fuzzy search terms *hemoglobin* and *diverticuli* with an edit distance of 1 each. This query matches the variation *haemoglobin* and the correct spelling *diverticula*.

Copy to clipboard

```
SELECT id, description__c
FROM product__v
FIND ('hemoglobin diverticuli' DISTANCE [1, 1] SCOPE description__c)
```

### Query: Default Distance

The following query searches *Product* names with an edit distance of 1 on the first term only. The second term’s edit distance is omitted and defaults to 0 (exact match). This is the same as `DISTANCE [1, 0]`.

This query allows misspellings of *insulin* but not *dysphagia*, so results could include *insulen* and *dysphagia* but not *insulen* and *dysphasia*.

Copy to clipboard

```
SELECT id, name__v
FROM product__v
FIND ('insulin AND dysphagia' DISTANCE [1] SCOPE name__v)
```
