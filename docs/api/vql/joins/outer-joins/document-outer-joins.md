<!-- source: https://general.veevavault.dev/vql/joins/outer-joins/document-outer-joins/ -->
<!-- title: Document Outer Joins -->

# Document Outer Joins

An outer join uses a relationship to expand the primary query data, returning all results from the primary document query even when there is no matching data from the related object. If no matching related records exist, the primary document record is still included in the results.

## Document to Vault Object (M:M)

When a document field references a Vault object, Vault automatically creates a specialized many-to-many relationship. You can use a subquery in the `SELECT` clause to expand document results to include metadata from the related object records.

1. **Primary query target (`documents`):** The top-level `SELECT` statement retrieves fields from your documents.
2. **Subquery target (the Vault object):** The subquery target uses the `document_{object_name}__vr` relationship. The subquery fields live on the related Vault object, such as `product__v`.

### Query Example

This query retrieves the document ID and the ID and name of all products associated with each document:

Copy to clipboard

```
SELECT id, 
 (SELECT id, name__v 
  FROM document_product__vr) 
FROM documents
```

### Response Structure

The document records are returned at the top level, with the related products nested in `document_product__vr`:

Copy to clipboard

```
"data": [
    {
        "id": 111,
        "name__v": "Cholecap Patient Brochure (UK)",
        "document_product__vr": {
            "responseDetails": {
                "pagesize": 250,
                "pageoffset": 0,
                "size": 1,
                "total": 1
            },
            "data": [
                {
                    "id": "00P000000000202",
                    "name__v": "Cholecap"
                }
            ]
        }
    },
]
```

## Vault Object to Document (M:M)

Because document-to-object relationships are bi-directional, you can also start your query from the Vault object. This allows you to expand object results to include a collection of all related documents.

1. **Primary query target (the Vault object):** The top-level `SELECT` statement retrieves fields from the Vault object.
2. **Subquery target (`documents`):** Use the same `document_{object_name}__vr` relationship as the subquery target.

### Query Example

This query retrieves product IDs and a list of all documents associated with each product:

Copy to clipboard

```
SELECT id, name__v,
 (SELECT id, name__v 
  FROM document_product__vr) 
FROM product__v
```

### Response Structure

The product records appear at the top level. Even if a product has no associated documents, the record is included in the response (outer join).

Copy to clipboard

```
"data": [
    {
        "id": "00P000000000102",
        "name__v": "VeevaProm XR",
        "document_product__vr": {
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
        "id": "00P000000000202",
        "name__v": "Cholecap",
        "document_product__vr": {
            "responseDetails": {
                "pagesize": 250,
                "pageoffset": 0,
                "size": 34,
                "total": 34
            },
            "data": [
                {
                    "id": 1,
                    "name__v": "CholeCap Patient Brochure"
                },
                {
                    "id": 2,
                    "name__v": "CholeCap Logo"
                },
                {
                    "id": 3,
                    "name__v": "CholeCap Dosage Claim"
                }
            ]
        }
    }
]
```

## Vault Object to Document (M:1)

When a custom object reference field on a Vault object points to *Document* (`documents`), it behaves as a standard reference relationship. Because the field links to a single specific document, you can use a lookup in the `SELECT` clause to expand the result data.

1. **Primary query target (the Vault object):** The top-level `SELECT` statement retrieves fields from the Vault object.
2. \*\*Lookup target (`documents`): \*\*The dot-notation lookup in the `SELECT` clause identifies the outbound relationship, such as `doc_ref__cr`.

### Query Example

Copy to clipboard

```
SELECT id, name__v, doc_ref__cr.name__v 
FROM product__v
```

### Response Structure

The primary object records are returned with the referenced document metadata. If the field is empty, the value is returned as null (outer join).

Copy to clipboard

```
"data": [
    {
        "id": "00P00000000H002",
        "name__v": "CholeCap",
        "doc_ref__cr.name__v": "CholeCap Package Insert"
    },
    {
        "id": "00P00000000K005",
        "name__v": "WonderDrug",
        "doc_ref__cr.name__v": null
    }
]
```

## Document-Object Traversal (M:M)

When a document is related to an object through a child join object, you must traverse the relationship in two steps:

1. **Primary query target (`documents`):** The top-level `SELECT` statement retrieves fields from your documents.
2. **Subquery target (child join object):** The subquery target is the document relationship to the join object.
3. **Referenced Object (the parent object):** Use dot-notation lookup to reach a parent object from the join object.

### Query Example

Copy to clipboard

```
SELECT id, name__v, type__v,
    (SELECT name__v, country__cr.name__v
    FROM document_approved_country__cr)
FROM documents
```

### Response Structure

The document records include data from the child join records, which in turn display metadata from the final referenced object:

Copy to clipboard

```
"data": [
    {
        "id": "1",
        "name__v": "CholeCap Package Insert",
        "document_approved_country__cr": {
            "responseDetails": {
                "size": 1,
                "total": 1
            },
            "data": [
                {
                    "id": "00P00000000K005",
                    "country__cr.name__v": "United States"
                }
            ]
        }
    }
]
```
