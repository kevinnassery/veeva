<!-- source: https://general.veevavault.dev/vql/joins/querying-related-objects/ -->
<!-- title: Querying Across Related Objects -->

# Querying Across Related Objects

In VQL, retrieving data across multiple objects requires an understanding of how Vault traverses relationships. Traversing relationships in VQL involves querying across related objects. This tutorial shows how to use subqueries and lookups to combine result data from three related objects. Each step builds on the previous query to either expand or filter data in a new way.

You can follow along directly if you have tutorial objects in your Vault, or you can use any three related objects. Extending this tutorial to other objects in your own Vault requires an [understanding of join queries](/vql/joins/about-join-queries).

Caution

Before performing VQL joins on large datasets, review [Performance Best Practices](/vql/references/query-performance-best-practices).

## The Example Structure

The example in this tutorial combines expanding and filtering data from three objects, two parents that are connected through a child join object:

1. The primary query target (Parent 1): `product__v`
2. The join object (Child): `approved_country__c`
3. The lookup target (Parent 2): `country__v`

By the end of this tutorial, you’ll be able to build complex join queries like this example query. It expands the *Product* result set to include data from the *Approved Country* and *Country* objects. It also filters the dataset to retrieve only products whose related *Approved Country* records have a parent country of ‘United States’.

Copy to clipboard

```
SELECT id, name__v, 
  (SELECT name__v, country__cr.name__v
   FROM approved_countries__cr)
FROM product__v 
WHERE id IN (
  SELECT id 
  FROM approved_countries__cr 
  WHERE country__cr.name__v = 'United States'
)
```

## Step 1: Defining the Primary Target

The primary query looks like a standard VQL query. In this case, we want to query the *Product* object to retrieve a primary result set of *Product* records. This base query returns the ID and name of all *Product* records:

Copy to clipboard

```
SELECT id, name__v
FROM product__v
```

These records are returned in a `data` object, and each record returned has this shape:

Copy to clipboard

```
"data": [
  {
    "id": "00P000000000201",
    "name__v": "VeevaProm"
  },
  {
    "id": "00P00000000H002",
    "name__v": "CholeCap"
  }
]
```

## Step 2: Expanding Data via Subquery

The goal of this step is to add the child object `approved_country__c` to the results. You must navigate the relationship from parent to child:

* Direction (inbound): From the parent (primary target), the query reaches down to the child records.
* Cardinality (1:M): Because one product can have multiple approved countries, the nested results contain multiple records.
* Syntax (subquery): You must use a subquery to create a nested JSON object that holds the collection of related child records.
* Location (`SELECT`): Since this query adds data, place the subquery in the `SELECT` statement.

To add *Approved Country* data to the retrieved *Product* records, add a `SELECT` subquery:

Copy to clipboard

```
SELECT id, name__v,
  (SELECT id, name__v FROM approved_countries__cr)
FROM product__v
```

This query adds the ID and name of every *Approved Country* record that is related to a *Product* record. Each individual *Product* record result contains a subset of data. Note that this creates an outer join, so if a *Product* record does not have related data, the primary record is still included and the subquery result set is empty.

Copy to clipboard

```
"data": [
  {
    "id": "00P000000000201",
    "name__v": "VeevaProm",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 0,
        "total": 0
      },
      "data": []
    }
  },
  {
    "id": "00P00000000H002",
    "name__v": "CholeCap",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 2,
        "total": 2
      },
      "data": [
        {
          "id": "V08000000002001",
          "name__v": "CholeCap Canada"
        },
        {
          "id": "V08000000002002",
          "name__v": "CholeCap USA"
        }
      ]
    }
  },
  {
    "id": "00P00000000W003",
    "name__v": "WonderDrug",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 1,
        "total": 1
      },
      "data": [
        {
          "id": "V08000000003001",
          "name__v": "WonderDrug France"
        }
      ]
    }
  }
]
```

## Step 3: Expanding Data via Lookup

The goal of this step is to reach the object `country__v` by traversing through the join object. There is no direct relationship between `product__v` and `country__v`. Within the subquery, your perspective shifts to the join object:

* Direction (outbound): From the subquery, the join object record looks up to its parent.
* Cardinality (M:1): Each join object record links to one country.
* Syntax (lookup): Because there is only one related record, use dot-notation (a lookup) to append it to the result.
* Location (`SELECT`): Place the lookup inside the subquery's `SELECT` statement to expand the nested data.

To add *Country* data to your subquery results, use a lookup on the outbound relationship (`country__cr`):

Copy to clipboard

```
SELECT id, name__v,
  (SELECT id, name__v,
  country__cr.id, country__cr.name__v
  FROM approved_countries__cr)
FROM product__v
```

This query adds *Country* data to the subquery result set:

Copy to clipboard

```
"data": [
  {
    "id": "00P000000000201",
    "name__v": "VeevaProm",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 0,
        "total": 0
      },
      "data": []
    }
  },
  {
    "id": "00P00000000H002",
    "name__v": "CholeCap",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 2,
        "total": 2
      },
      "data": [
        {
          "id": "V08000000002001",
          "name__v": "CholeCap Canada",
          "country__cr.id": "00C000000000105",
          "country__cr.name__v": "Canada"
        },
        {
          "id": "V08000000002002",
          "name__v": "CholeCap USA",
          "country__cr.id": "00C000000000101",
          "country__cr.name__v": "United States"
        }
      ]
    }
  },
  {
    "id": "00P00000000W003",
    "name__v": "WonderDrug",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 1,
        "total": 1
      },
      "data": [
        {
          "id": "V08000000003001",
          "name__v": "WonderDrug France",
          "country__cr.id": "00C000000000108",
          "country__cr.name__v": "France"
        }
      ]
    }
  }
]
```

## Step 4: Filtering via Subquery

The goal of this step is to filter the *Product* results based on the existence of related child records. This creates an inner join:

* Direction (inbound): From the primary target, the query reaches down to match child records.
* Cardinality (1:M): The query checks if each *Product* record's collection of children is not empty.
* Syntax (subquery): You must use a subquery to filter by related child records.
* Location (`WHERE`): Since this query narrows the result set, place the subquery in the `WHERE` clause.

To filter out products that have no approved countries, add a `WHERE IN` subquery:

Copy to clipboard

```
SELECT id, name__v,
  (SELECT id, name__v,
  country__cr.id, country__cr.name__v
  FROM approved_countries__cr)
FROM product__v 
WHERE id IN
  (SELECT id
   FROM approved_countries__cr)
```

The results only include *Product* records with a populated subset of *Approved Country* data. In the response, records like `VeevaProm` (which had an empty array in previous steps) are now removed from the result set.

Copy to clipboard

```
"data": [
  {
    "id": "00P00000000H002",
    "name__v": "CholeCap",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 2,
        "total": 2
      },
      "data": [
        {
          "id": "V08000000002001",
          "name__v": "CholeCap Canada",
          "country__cr.id": "00C000000000105",
          "country__cr.name__v": "Canada"
        },
        {
          "id": "V08000000002002",
          "name__v": "CholeCap USA",
          "country__cr.id": "00C000000000101",
          "country__cr.name__v": "United States"
        }
      ]
    }
  },
  {
    "id": "00P00000000W003",
    "name__v": "WonderDrug",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 1,
        "total": 1
      },
      "data": [
        {
          "id": "V08000000003001",
          "name__v": "WonderDrug France",
          "country__cr.id": "00C000000000108",
          "country__cr.name__v": "France"
        }
      ]
    }
  }
]
```

## Step 5: Filtering Joined Data

The goal of this step is to narrow primary records based on specific field values on the child object:

* Direction (inbound): The filter reaches from the parent into its children's metadata.
* Cardinality (1:M): The filter checks each record's collection of children for at least one that matches the specific criteria.
* Syntax (subquery): You must add criteria to the `WHERE IN` subquery.
* Location (subquery's `WHERE` clause): Place the criteria inside the `WHERE IN` subquery's `WHERE` clause.

The following query uses a `WHERE` clause in the `WHERE IN` subquery to filter primary records based on field values on a related object. It checks all *Product* records for at least one child *Approved Country* record with the name ‘CholeCap Canada’:

Copy to clipboard

```
SELECT id, name__v,
  (SELECT id, name__v,
  country__cr.id, country__cr.name__v
  FROM approved_countries__cr)
FROM product__v 
WHERE id IN
  (SELECT id
   FROM approved_countries__cr
   WHERE name__v = 'CholeCap Canada')
```

Note

The `WHERE` clause provides the criteria for the inner join and filters the *primary* target records. It does not filter the subquery records. In the response below, notice that the "CholeCap USA" record is still included in the nested data.

Notice that `WonderDrug` has been removed from dataset because it does not have any related records in the `approved_countries__cr` dataset with this criteria.

Copy to clipboard

```
"data": [
  {
    "id": "00P00000000H002",
    "name__v": "CholeCap",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 2,
        "total": 2
      },
      "data": [
        {
          "id": "V08000000002001",
          "name__v": "CholeCap Canada",
          "country__cr.id": "00C000000000105",
          "country__cr.name__v": "Canada"
        },
        {
          "id": "V08000000002002",
          "name__v": "CholeCap USA",
          "country__cr.id": "00C000000000101",
          "country__cr.name__v": "United States"
        }
      ]
    }
  }
]
```

## Step 6: Filtering via Lookup

The goal of this step is to filter the primary records based on data from a distant third object. You must traverse through the child join object:

* Direction (outbound): From the subquery, the join object record looks up to its parent.
* Cardinality (M:1): The filter checks the single country associated with each join object record.
* Syntax (lookup): Because there is only one related record, use dot-notation (a lookup) to add it to the criteria in the subquery's `WHERE` clause.
* Location (subquery's `WHERE` clause): Place the lookup criteria inside the `WHERE IN` subquery's `WHERE` clause.

The following query includes all products with at least one *Approved Country* with a parent *Country* record named ‘France’:

Copy to clipboard

```
SELECT id, name__v,
  (SELECT id, name__v,
  country__cr.id, country__cr.name__v
  FROM approved_countries__cr)
FROM product__v 
WHERE id IN
  (SELECT id
   FROM approved_countries__cr
   WHERE country__cr.name__v = 'France')
```

Note

The `WHERE` clause provides the criteria for the inner join and filters the *primary* target records. It does not filter the subquery records.

The results filter the *Product* records based on the criteria defined in the `WHERE IN` subquery. Notice that `CholeCap` has now been removed from the `data` array entirely because it does not have any related records in the `approved_countries__cr` dataset with this criteria.

Copy to clipboard

```
"data": [
  {
    "id": "00P00000000W003",
    "name__v": "WonderDrug",
    "approved_countries__cr": {
      "responseDetails": {
        "pagesize": 250,
        "pageoffset": 0,
        "size": 1,
        "total": 1
      },
      "data": [
        {
          "id": "V08000000003001",
          "name__v": "WonderDrug France",
          "country__cr.id": "00C000000000108",
          "country__cr.name__v": "France"
        }
      ]
    }
  }
]
```

## Summary: Expanding vs. Filtering

In this tutorial, you have combined two distinct VQL join behaviors to create a complex, multi-object result set using two subquery types and lookups:

* **Expansion (the `SELECT` Subquery)**: Determines the data that is included for the records in a result set. It functions like an outer join, ensuring that even if a child record doesn't match a filter, you still see the full related context for the primary records that do.
* **Filtering (the `WHERE IN` Subquery)**: Determines which primary records appear in the primary dataset. This functions like an inner join, narrowing the dataset based on specific criteria found in related objects.
* **Lookups (the dot-notation join):** Retrieves data from a parent or related object.

By combining these, you can retrieve a precisely filtered list of records and related data.

## Next Steps

While this tutorial uses a specific product and country hierarchy, these VQL patterns apply to any related objects in your Vault. You can navigate many-to-many joins or reference relationships by applying these subquery and lookup techniques to any valid relationship name identified in your metadata.

To learn more about joins and relationships, see:

* [About Join Queries](/vql/joins/about-join-queries)
* [Relationship Limitations](/vql/joins/relationship-constraints)
