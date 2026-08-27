<!-- source: https://general.veevavault.dev/vql/getting-started/document-object-queries/ -->
<!-- title: Document & Object Queries -->

# Document & Object Queries

When structuring a query, add the fields to retrieve to the `SELECT` clause in a comma-separated list. The fields must be queryable.

To add fields to a query, enter the field’s name attribute in the `SELECT` clause. For example, to retrieve the *Status* field, enter `status__v`. To retrieve the *Name* document field, enter `name__v`. You can get the `name` attribute of queryable fields using the [Query Target reference](/vql/query-targets) or the metadata API.

## Querying Documents

To retrieve data from documents in your Vault, use the `documents` query target.

### Basic Document Query

The following query retrieves the IDs and names of all documents in your Vault:

Copy to clipboard

```
SELECT id, name__v
FROM documents
```

### Response

The response provides the response status, the number of results, pagination information, and the requested Vault data. You can also include metadata on the query target and any included fields by [requesting the queryDescribe](/vql/references/vql-api-headers#Query_Describe) object.

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 3,
        "total": 3
    },
    "data": [
        {
            "id": 26,
            "name__v": "Verntorvastatin Batch Manufacturing Record"
        },
        {
            "id": 6,
            "name__v": "Cholecap-Logo"
        },
        {
            "id": 5,
            "name__v": "CholeCap Visual Aid"
        }
    ]
}
```

### Filtered Document Query

To filter and refine your search, you can add clauses, functions, and query target options to a `SELECT` statement.

The following query uses the `WHERE` clause to retrieve the IDs and names of all documents named “WonderDrug Information”:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE name__v = 'WonderDrug Information'
```

### Response: Retrieve a Document by Name

The following response shows that there is only one (1) document named “WonderDrug Information”:

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 1,
        "total": 1
    },
    "data": [
        {
            "id": 534,
            "name__v": "WonderDrug Information" 
        }
    ]
}
```

## Querying Objects

To retrieve object record data from your Vault, use the object’s name attribute as the [query target](/vql/query-targets). For example, to query the *Product* object, enter `product__v` as the query target.

### Query

The following query retrieves the IDs and names of all *Product* object records in your Vault:

Copy to clipboard

```
SELECT id, name__v
FROM product__v
```

### Response

This response includes seven (7) *Product* object records:

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 7,
        "total": 7
    },
    "data": [
        {
            "id": "00P000000000301",
            "name__v": "Nyaxa"
        },
        {
            "id": "00P000000000302",
            "name__v": "Focusin"
        },
        {
            "id": "00P000000000303",
            "name__v": "Lexipalene"
        },
        {
            "id": "00P000000000304",
            "name__v": "Pazofinil"
        },
        {
            "id": "00P000000000401",
            "name__v": "Vetreon"
        },
        {
            "id": "00P000000000A01",
            "name__v": "Gludacta"
        },
        {
            "id": "00P000000000E01",
            "name__v": "Wonderdrug"
        }
    ]
}
```

## Next Steps

To learn how to use VQL in specific use cases, see our VQL Guides or use the Library to find all articles tagged *VQL*.

To learn more about query structure and VQL best practices, see:

* [The VQL Query Structure](/vql/getting-started/structuring-sending-queries)
* [Notation Conventions](/vql/references/language-specifications/notation-conventions) and [Terminology](/vql/references/language-specifications/terminology)
* [Pagination Best Practices](/vql/references/pagination-best-practices)
