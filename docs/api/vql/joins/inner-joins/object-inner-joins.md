<!-- source: https://general.veevavault.dev/vql/joins/inner-joins/object-inner-joins/ -->
<!-- title: Vault Object Inner Joins -->

# Vault Object Inner Joins

An inner join uses a relationship to filter the primary query data, only returning Vault object records that have a successful match in the related object. If the criteria on the related data are not met, the primary object record is excluded from the results.

## Parent to Child (1:M)

Use a `WHERE` subquery to filter parent records based on the existence of child records. If no related records exist in the subquery target, the parent record is excluded from the result set.

This is useful when you only want to see records that have reached a specific milestone or have a specific set of related data.

Copy to clipboard

```
SELECT {fields}
FROM parent__v
WHERE id IN (SELECT id FROM inbound_child_relationship__cr)
```

* **Primary query target (Parent)**: The top-level `SELECT` statement retrieves fields from parent records that meet the subquery criteria.
* **Subquery target (Child)**: The inbound relationship name in the subquery identifies the related object to use for filtering.

Note

Using the `id` field for the `WHERE IN` subquery is a convention to simplify the query syntax. VQL performs the join automatically based on the relationship name, not the specified field. Specifying different or additional fields does not affect the result.

### Query Example

The following example retrieves *Product* records with at least one *Approved Country* child record.

Copy to clipboard

```
SELECT id, name__v
FROM product__v
WHERE id IN (SELECT id FROM approved_countries__cr)
```

## Child to Parent (M:1)

To filter a child object based on its parent, use a `WHERE` clause lookup on the outbound relationship. This ensures we only include child records that match the filter criteria on the parent.

Copy to clipboard

```
SELECT {fields}
FROM child__v
WHERE outbound_parent_relationship__cr.field__c = 'value'
```

* **Primary query target (Parent)**: The top-level `SELECT` statement retrieves fields from child records that meet the lookup criteria.
* **Lookup target (Child)**: The outbound relationship name and field identify the parent object field to look up and filter against.

## Traversal (M:M)

When two parent objects are connected through a shared child join object, you can filter one parent using data from the second parent using the join object as the bridge. The second parent can be reached using a lookup on the outbound relationship, such as `country__cr.name__v`.

Copy to clipboard

```
SELECT parent1_field__v
FROM parent__v
WHERE id IN 
  (SELECT id
  FROM inbound_child_relationship__cr
  WHERE country__cr.name__v = 'United States')
```

1. **Primary query target (Parent 1):** The top-level `SELECT` statement retrieves fields from every Parent 1 record.
2. **Subquery target (Child):** The subquery target is the inbound child relationship on Parent 1. The subquery fields are fields on the child join object.
3. **Referenced parent (Parent 2):** Dot-notation lookups, such as `country__cr.name__v`, use the outbound relationship from the join object to reach Parent 2.

### Query Example

Copy to clipboard

```
SELECT id, name__v FROM campaign__c
WHERE id IN (
	SELECT id FROM product__cr
	WHERE product_labeling__cr.name__v = '67546345')
```

The `WHERE` filter inside this subquery provides additional criteria for the inner join and filters the *primary* target records. It does not filter the subquery records.

## Lookup (1:1)

You can filter an object based on a related object by using a `WHERE` clause lookup on the outbound relationship.

Copy to clipboard

```
SELECT {fields}
FROM object_1__v
WHERE outbound_relationship__cr.field__c = 'value'
```

* **Primary query target (Object 1)**: The top-level `SELECT` statement retrieves fields from the primary object records that meet the lookup criteria.
* **Lookup target (Object 2)**: The outbound relationship name and field identify the related object field to look up and filter against.
