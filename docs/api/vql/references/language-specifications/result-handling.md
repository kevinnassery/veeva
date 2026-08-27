<!-- source: https://general.veevavault.dev/vql/references/language-specifications/result-handling/ -->
<!-- title: Result Handling -->

# Result Handling

VQL follows specific logic for how results are ordered and how empty or missing data is evaluated.

## Sorting & Ordering Results

Query results are returned in a default order. To enforce a specific order, use the `ORDER BY` clause.

* The API supports primary and secondary sorting of fields in ascending/descending order. Learn more about [Order By](/vql/clauses/order-by).
* The API also supports sorting results by relevance to a `FIND` operator search phrase using the `ORDER BY RANK` operator. Learn more about [Order By rank](/vql/clauses/order-by#Ordering_by_Rank).

VQL does not support sorting multi-value picklist fields on raw objects.

VQL uses the following strategy when sorting `null` values:

* When ordering `documents` and standard volume Vault objects, `null` values are last in the set of results in both ascending (`ASC`) and descending order (`DESC`).
* When ordering raw objects and other query targets such as `groups`, `null` values are first in the set of results in ascending order (`ASC`) and last in descending order (`DESC`).

## Null Field Values

Use `null` to find `documents` and objects with or without a value set on a particular field. For example, the following query returns all `documents` where the *External ID* field has no value but the *Country* field does have a value:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE external_id__v = null AND country__v != null
```

Vault considers fields with null values in inequalities. For example, the following query returns all documents where the `country__v` field is either null or a value not equal to 'Canada’:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE country__v != 'Canada'
```
