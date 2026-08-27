<!-- source: https://general.veevavault.dev/vql/functions-options/allversions-latestversion/ -->
<!-- title: ALLVERSIONS & LATESTVERSION -->

# ALLVERSIONS & LATESTVERSION

By default, a query on the documents object targets the latest version of all documents. In v8.0+, you can query by document version:

* Use `ALLVERSIONS` with `FROM` to query all document versions.
* Use `LATESTVERSION` with `SELECT` and `ALLVERSIONS` to retrieve the latest version that matches the `FIND` or `WHERE` search criteria. `LATESTVERSION` on its own uses the default behavior.

## Syntax

Copy to clipboard

```
SELECT LATESTVERSION {fields}
FROM ALLVERSIONS documents
```

## Query Examples

The following are examples of queries using `ALLVERSIONS` and `LATESTVERSION`.

### Query: ALLVERSIONS

The following query returns the ID and major and minor version numbers of all document versions:

Copy to clipboard

```
SELECT id, major_version_number__v, minor_version_number__v
FROM ALLVERSIONS documents
```

### Response: ALLVERSIONS

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
           "id": 6,
           "major_version_number__v": 1,
           "minor_version_number__v": 1
       },
       {
           "id": 6,
           "major_version_number__v": 1,
           "minor_version_number__v": 0
       },
       {
           "id": 5,
           "major_version_number__v": 0,
           "minor_version_number__v": 1
       }
   ]
}
```

### Query: LATESTVERSION

In this example, a user has assigned a value to the *Country* field in a document with version 1.1. The following query returns the latest version of this document where the *Country* field is empty:

Copy to clipboard

```
SELECT LATESTVERSION id, major_version_number__v, minor_version_number__v
FROM ALLVERSIONS documents
WHERE id = 6 AND country__c = NULL
```

### Response: LATESTVERSION

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
           "id": 6,
           "major_version_number__v": 1,
           "minor_version_number__v": 0
       }
   ]
}
```
