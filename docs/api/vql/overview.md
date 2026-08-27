<!-- source: https://general.veevavault.dev/vql/overview/ -->
<!-- title: VQL Overview -->

# VQL Overview

Use **Vault Query Language (VQL)** to access, retrieve, and interact with Vault data. Although VQL queries share most of the same syntax as Structured Query Language (SQL), VQL statements allow you to perform queries specifically for Vault data.

When an application invokes a query call, it passes in a VQL statement. The `FROM` clause specifies a query target such as `documents`. The `SELECT` clause specifies the fields to retrieve. Optional filters (the `WHERE` or `FIND` clause) narrow results:

Copy to clipboard

```
SELECT {one field or comma-separated list of field names}  
FROM {query target}  
WHERE {optional search filters to narrow resulting data}
```

The following example query returns the ID and name from the latest version of all documents where the type name is `promotional_piece__c`:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE TONAME(type__v) = 'promotional_piece__c'
```

To learn more about VQL syntax, how to structure queries, and how to retrieve fields from a single query target such as documents or `product__v`, see [Getting Started](/vql/getting-started).

VQL supports relationship queries (joins) where more than one query target is included in a single query. This is covered in [Joins & Relationships](/vql/joins).
