<!-- source: https://general.veevavault.dev/vql/joins/inner-joins/document-inner-joins/ -->
<!-- title: Document Inner Joins -->

# Document Inner Joins

An inner join uses a relationship to filter the primary query data, only returning records that have a successful match in the related object. If the criteria on the related data are not met, the primary record is excluded from the results.

## Document to Vault Object (M:M)

You can filter your document library based on metadata stored in related Vault objects. This is useful for finding documents that are specifically associated with a particular product, study, or country.

1. **Primary query target (`documents`):** The query returns only the documents that meet the subquery criteria.
2. **Subquery target (the Vault object):** The subquery uses the `document_{object_name}__vr` relationship. The filter criteria (the `WHERE` clause inside the subquery) are applied to the Vault object fields.

### Query Example

This query retrieves only the documents that are associated with the product "CholeCap":

Copy to clipboard

```
SELECT id, name__v 
FROM documents 
WHERE id IN (
  SELECT id 
  FROM document_product__vr 
  WHERE name__v = 'CholeCap'
)
```

### Response Structure

The related object data is not returned in the response, and the response only includes the documents that passed the filter.

Copy to clipboard

```
"data": [
    {
        "id": "1",
        "name__v": "CholeCap Package Insert"
    },
    {
        "id": "2",
        "name__v": "CholeCap Label"
    }
]
```

## Vault Object to Document (M:M)

You can filter Vault objects based on the status or metadata of their related documents. A common use case is identifying products that have at least one document in a specific lifecycle state, such as "Approved."

1. **Primary query target (the Vault object):** The query returns only the object records that are linked to documents matching the criteria.
2. **Subquery target (`documents`):** The subquery uses the `document_{object_name}__vr` relationship. The filter criteria are applied to document fields, such as `status__v` or `type__v`.

### Query Example

This query retrieves only the products that have at least one associated document in the "Approved" status:

Copy to clipboard

```
SELECT id, name__v 
FROM product__v 
WHERE id IN (
  SELECT id 
  FROM document_product__vr 
  WHERE status__v = 'Approved'
)
```

### Response Structure

The response only includes the product records. If a product is only associated with "Draft" documents, it is excluded from this result set.

Copy to clipboard

```
"data": [
    {
        "id": "00P00000000H002",
        "name__v": "CholeCap"
    }
]
```

## Traversal (M:M)

Use this pattern to filter documents based on criteria on a parent object of the object referenced by the document field. This is useful when documents are linked to a join object and you need to qualify the documents by a field on the join object's parent.

1. **Primary query target (`documents`):** The query returns only those documents that meet the criteria.
2. **Subquery target (child join object):** The subquery target is the document relationship to the join object.
3. **Filter criteria (the parent object):** Use dot-notation lookup to filter by the parent object in the subquery's `WHERE` clause.

### Query Example

This query retrieves only the documents with an "Approved Country" of "United States":

Copy to clipboard

```
SELECT id, name__v 
FROM documents 
WHERE id IN (
  SELECT id 
  FROM document_approved_country__cr 
  WHERE country__cr.name__v = 'United States'
)
```

### Response Structure

The response contains only the document records that successfully matched the traversal criteria.

Copy to clipboard

```
"data": [
    {
        "id": "1",
        "name__v": "CholeCap Package Insert"
    }
]
```

# Vault Object to Document (M:1)

Use this pattern to filter Vault objects based on a single referenced document. This uses a standard lookup in the `WHERE` clause.

1. **Primary query target (the Vault object):** The query returns only the object records linked to the specific document.
2. **Lookup target (`documents`):** The filter uses the outbound relationship to match a field value on the referenced document.

### Query Example

Copy to clipboard

```
SELECT id, name__v 
FROM product__v 
WHERE doc_ref__cr.name__v = 'CholeCap Package Insert'
```
