<!-- source: https://general.veevavault.dev/vql/joins/about-join-queries/ -->
<!-- title: About Join Queries -->

# About Join Queries

A VQL join is defined by three core concepts: the result structure, the direction of the relationship, and the intent for the data.

* Understanding the result structure helps you choose the primary query target because that object populates the top level of JSON data in the response.
* The relationship direction determines whether to use the inbound or outbound relationship name, which in turn determines whether to use subquery or lookup syntax.
* The join's purpose (expanding or filtering data) determines how to structure the join query and where to place the subquery or lookup.

## Result Structure

In VQL, a row is a single result of JSON data. For example, if you query `documents`, each row or result represents a single document in your Vault.

In a VQL join, the primary query target determines the top-level results in the VQL response, and every result represents a single record of the primary query target. When joining query targets, Vault returns related data as a nested subset of data within the primary record result.

Comparison to SQL

VQL uses subquery and lookup syntax to return nested JSON data and does not provide clauses such as `JOIN` or `INNER JOIN`.

Joined VQL data is returned as nested JSON, not a flat table.

## Relationship Direction

The [join syntax](/vql/joins/syntax-reference) to use in a query depends on the direction of the relationship in the Vault object's configuration.

The join syntax you use depends on whether the relationship is inbound or outbound from the perspective of the primary query target. This direction is determined by cardinality: whether the relationship points to a single record (one) or a collection of records (many):

* Many (inbound relationship): When moving down or across to multiple records, use a subquery.
* One (outbound relationship): When moving up or across to one specific parent or reference, use a lookup.

### Inbound Relationships (1:M or 1:1)

When the primary query target has an **inbound relationship** from a second object, you can use the relationship name to join data to the primary result set. This means reaching "down" from the parent to a collection of child object records or *across* to the records of a related object.

For example, the *Approved Country* object could have a parent object field pointing to the *Product* object. This creates an inbound relationship on the *Product* object from the child *Approved Country* object.

This relationship name is plural because it represents an inbound relationship from potentially many related records. It has the format `{plural_object_name__cr}`, such as `approved_countries__cr`.

A join on an inbound relationship requires a subquery. For example, `(SELECT id from approved_countries__cr)`

### Outbound Relationships (M:1 or 1:1)

When the primary query target has an **outbound relationship** to a second object, you can use the relationship name in a lookup to add data to the result set. This means reaching "up" from a child object to its single parent record or "across" to the single record of the related object.

This outbound relationship makes a single related object record available for data retrieval.

For example, the *Approved Country* child object has an outbound relationship to its parent *Product* object. This outbound relationship allows access to the single parent record of each *Approved Country* record.

The relationship name is singular because it represents an outbound relationship to a single related record and has the format `{object_name__cr}`, such as `product__cr`.

A join on an outbound relationship requires a lookup. For example, `country__cr.name__v`.

### Traversal (M:M)

For complex data models such as many-to-many (M:M) relationships, you must combine join strategies. To traverse through three related objects, you can use one object as a bridge.

This traversal requires two steps:

1. Object 1 to Object 2: Use an inbound subquery from Object 1 to reach a child join object or a reference object (Object 2).
2. Object 2 to Object 3: Use an outbound lookup from Object 2 to reach Object 3.

Object 2 acts as a bridge, as it has an inbound relationship from Object 1 and an outbound relationship to Object 3. Object 1 and Object 3 are not directly related.

## Join Intent: Expanding vs. Filtering

VQL distinguishes between retrieving and filtering data:

* The `SELECT` clause retrieves data from a query target.
* The `WHERE` clauses filters the retrieved data using specified criteria.

In a join, related data can either expand or filter the retrieved data:

* **Expanding retrieved data (left outer join):** The join query retrieves all records from the primary query target and adds any related data if it exists. If the related data is empty, the primary record is still included.
* **Filtering retrieved data (inner join):** The query uses a relationship to filter the primary query data, only returning records that have a successful match in the related object records. If the related data is empty, the primary record is excluded (inner join).

### Expanding Data

To expand retrieved data using a join, add a subquery or lookup to the `SELECT` clause.

For example, the following query does the following:

1. Reaches across to the related object *Product Label* via lookup (`product_labeling__cr.name__v`) to retrieve the *Product Label* name.
2. Reaches down to a child object via subquery (`(SELECT id, name__v FROM approved_countries__cr)`) to retrieve related *Approved Country* records.

Copy to clipboard

```
SELECT id, name__v, product_labeling__cr.name__v,
    (SELECT id, name__v FROM approved_countries__cr)
FROM product__v
```

The results include all *Product* records plus related *Approved Country* and *Product Label* data, even if the related data is empty or `null`:

Copy to clipboard

```
"data": [
    {
        "id": "00P000000000G04",
        "name__v": "WonderDrug",
        "product_labeling__cr.name__v": "67546345",
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
        "product_labeling__cr.name__v": null,
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
    }
]
```

### Filtering Data

To filter retrieved data using a join, add a subquery or lookup to the `WHERE` clause.

For example, to filter the primary records, the following query:

1. Reaches across to the related object *Product Label* via lookup (`product_labeling__cr.name__v`)
2. Reaches down to a child object via subquery (`(SELECT id FROM approved_countries__cr)`)

Copy to clipboard

```
SELECT id, name__v
FROM product__v
WHERE id IN
    (SELECT id FROM approved_countries__cr)
AND product_labeling__cr.name__v != null
```

The results only include *Product* records with an *Approved Country* value and where the related *Product Label* has a name that is not `null`. It also only returns the data from the primary query target in the `SELECT` clause:

Copy to clipboard

```
"data": [
    {
        "id": "00P00000000H002",
        "name__v": "CholeCap"
    }
]
```

## Document-to-Object Relationships

The `documents` query target represents the documents in your Vault. Two relationships are possible between `documents` and a Vault object:

1. A document field of type `Object` pointing to a Vault object.
2. An object reference field pointing to *Document*.

The join behavior differs depending on where the relationship was originally created:

* If the field is a document field, use a subquery on the relationship name prefixed with `document_`.
* If the field is on the Vault object, use the inbound or outbound relationship name as for a reference relationship.

### Object Reference Field on Document

When a document field references a Vault object, Vault creates a specialized relationship and automatically generates a specific relationship name: `document_{object_name}__vr`.

The relationship is bi-directional, and VQL treats both directions as a collection. You must use subquery syntax whether you are querying from the document to the object or the object to the document. In other words, use the same relationship name whether the primary target is `documents` or the Vault object.

### Document Reference Field on Object

When an object reference field points to *Document*, Vault creates an inbound and outbound relationship as it does for a standard reference relationship.

In join queries, you can treat this like a reference relationship. This follows standard reference rules: use a lookup for outbound results (to the document) and a subquery for inbound results (to the object).

## Next Steps

* [Querying Related Objects](/vql/joins/querying-related-objects): Learn how to apply these core concepts to building complex queries.
* [Joins](/vql/joins): Complete reference documentation on VQL joins.
