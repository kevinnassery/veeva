<!-- source: https://general.veevavault.dev/vql/joins/outer-joins/object-outer-joins/ -->
<!-- title: Vault Object Outer Joins -->

# Vault Object Outer Joins

An outer join uses a relationship to expand the primary query data, returning all results from the primary object query even when there is no matching data from the related object. If no matching related records exist, the primary object record is still included in the results.

## Parent to Child (1:M)

A parent-child relationship is hierarchical. You can use a subquery in the `SELECT` clause on the parent to include child record data in the query results. This is useful when you need to audit data from a parent record, including those that lack related entries, and identify gaps.

1. **Primary query target (Parent):** The top-level `SELECT` statement retrieves fields from every parent record.
2. **Subquery target (Child):** The subquery target is the inbound relationship on the parent. The subquery fields are on the child object.

### Query Example

This query retrieves the `id` and `name__v` fields from two distinct objects in a single request:

Copy to clipboard

```
SELECT id, name__v, 
 (SELECT id, name__v
  FROM approved_countries__cr) 
FROM product__v
```

### Response Structure

Records from the primary target appear at the top level of the response, with related data expanded into a nested `data` array.

Copy to clipboard

```
"data": [
{
            "id": "00P00000000K001",
            "name__v": "WonderDrug",
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
        }
]
```

Compare the nested VQL JSON result to a traditional flat table:

| Product id | Product name\_\_v | Approved Country id | Approved Country name\_\_v |
| --- | --- | --- | --- |
| `00P000000000101` | `WonderDrug` |  |  |
| `00P000000000201` | `VeevaProm` | `V08000000000101` | `VeevaProm USA` |
| `00P000000000201` | `VeevaProm` | `V08000000000101` | `VeevaProm Canada` |

## Child to Parent (M:1)

You can include data from a parent object by using a `SELECT` clause lookup on the outbound relationship. This allows you to append parent metadata to each result.

1. **Primary query target (child):** The top-level `SELECT` statement retrieves fields from the primary query target.
2. **Lookup target (parent):** The lookup in the `SELECT` clause identifies the outbound relationship. The referenced fields live on the parent object. For example, `parent__cr.field__v`.

### Query Example

This query retrieves the `name__v` field from two distinct objects in a single request:

Copy to clipboard

```
SELECT name__v, country__cr.name__v  
FROM approved_country__c
```

### Response Structure

Copy to clipboard

```
"data": [
        {
            "name__v": "WonderDrug USA",
            "country__cr.name__v": "United States"
        },
        {
            "name__v": "CholeCap Canada",
            "country__cr.name__v": "Canada"
        },
        {
            "name__v": "CholeCap USA",
            "country__cr.name__v": "United States"
        }
]
```

## Traversal (M:M)

To add data from two parent objects that are connected through a shared child join object, the join object acts as the bridge between parent objects. The child is reached using a subquery on the inbound relationship. The second parent is reached using lookups on the outbound relationship, such as `country__cr.name__v`.

Copy to clipboard

```
SELECT {parent1_field__v},
(SELECT 
  {child_field__v},
  {outbound_parent2_relationship__cr.field__v}
FROM inbound_child_relationship__cr)
FROM parent__v
```

1. **Primary query target (parent 1):** The top-level `SELECT` statement retrieves fields from every Parent 1 record.
2. **Subquery target (child):** The subquery target is the inbound child relationship on Parent 1. The subquery fields are fields on the child join object.
3. **Referenced parent (parent 2):** Dot-notation lookups, such as `country__cr.name__v`, use the outbound relationship from the join object to reach Parent 2.

### Query Example

This query retrieves the `id` and `name__v` fields from three distinct objects in a single request:

Copy to clipboard

```
SELECT id, name__v,
(SELECT id, name__v,
 country__cr.id, country__cr.name__v
FROM approved_countries__cr) 
FROM product__v
```

### Response Structure

Records from the primary target appear at the top level of the response, with related data expanded into a nested `data` array. If the related data is empty, the primary records are still included.

Copy to clipboard

```
"data": [
        {
            "id": "00P000000000101",
            "name__v": "WonderDrug",
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
            "id": "00P000000000201",
            "name__v": "VeevaProm",
            "approved_countries__cr": {
                "responseDetails": {
                    "pagesize": 250,
                    "pageoffset": 0,
                    "size": 1,
                    "total": 1
                },
                "data": [
                    {
                        "id": "V08000000000101",
                        "name__v": "VeevaProm USA",
                        "country__cr.id": "00C000000000101",
                        "country__cr.name__v": "United States"
                    },
                    {
                        "id": "V08000000000102",
                        "name__v": "VeevaProm Canada",
                        "country__cr.id": "00C000000000105",
                        "country__cr.name__v": "Canada"
                    }
                ]
            }
        }
]
```

Compare the nested VQL JSON result to a traditional flat table:

| Product id | Product name\_\_v | Approved Country id | Approved Country name\_\_v | Country id | Country name\_\_v |
| --- | --- | --- | --- | --- | --- |
| `00P000000000101` | `WonderDrug` |  |  |  |  |
| `00P000000000201` | `VeevaProm` | `V08000000000101` | `VeevaProm USA` | `00C000000000101` | `United States` |
| `00P000000000201` | `VeevaProm` | `V08000000000101` | `VeevaProm Canada` | `00C000000000105` | `Canada` |

## Lookup (1:1)

You can include data from a reference object by using a lookup on the outbound relationship. This is useful when you need to retrieve values from a reference object without filtering out records that lack the reference.

Copy to clipboard

```
SELECT object1_field__c,
outbound_object2_relationship__cr.field__c
FROM object1__v
```

1. **Primary query target (Object 1):** The top-level `SELECT` statement retrieves fields from the primary query target.
2. **Lookup target (Object 2):** The dot-notation in the `SELECT` clause retrieves fields using the outbound relationship. The referenced fields live on the referenced object.

### Query Example

Copy to clipboard

```
SELECT id, product_labeling__cr.id  
FROM product__v
```

### Response Structure

Copy to clipboard

```
"data": [
        {
            "id": "00P000000000202",
            "product_labeling__cr.id": "OP2000000000101"
        },
        {
            "id": "00P000000000301",
            "product_labeling__cr.id": null
        },
        {
            "id": "00P000000000302",
            "product_labeling__cr.id": null
        }
]
```
