<!-- source: https://general.veevavault.dev/vql/functions-options/state-functions/ -->
<!-- title: State Functions -->

# State Functions

By default, document queries retrieve documents in any lifecycle state. In v8.0+, use the special document functions with `WHERE` to retrieve documents in a lifecycle state (`status__v`) associated with a specific state type:

* `STEADYSTATE()`: Retrieve all documents in a steady state.
* `OBSOLETESTATE()`: Retrieve documents in an obsolete state.
* `SUPERSEDEDSTATE()`: Retrieve all documents in a superseded state.

In v19.2+:

* `DELETEDSTATE()`: Retrieve all documents in a deleted state.

Learn more about [document state types in Vault Help](https://platform.veevavault.help/en/lr/14560).

## Syntax

In v9.0+, the syntax is as follows:

Copy to clipboard

```
SELECT {fields}
FROM documents
WHERE status__v = STEADYSTATE()|OBSOLETESTATE()|SUPERSEDEDSTATE()|DELETEDSTATE()
```

You can only use these document functions with the `status__v` field.

In API v8.0 and earlier, the syntax is as follows:

Copy to clipboard

```
SELECT {fields}
FROM documents
WHERE STEADYSTATE()|OBSOLETESTATE()|SUPERSEDEDSTATE() = true
```

## Query Examples

The following are examples of queries using the document state functions.

### Query: Retrieve Documents in a Steady State

The following query returns the ID and lifecycle state of all documents in a steady state:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE status__v = STEADYSTATE()
```

### Response: Retrieve Documents in a Steady State

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
           "id": 9,
           "status__v": "Approved"
       }
   ]
}
```

### Query: Retrieve Documents in an Obsolete State

The following query returns the ID and lifecycle state of all documents in an obsolete state:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE status__v = OBSOLETESTATE()
```

### Query: Retrieve Documents in a Superseded State

The following query returns the ID and lifecycle state of all documents in a superseded state:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE status__v = SUPERSEDEDSTATE()
```

### Query: Retrieve Documents in a Deleted State

The following query returns the ID and lifecycle state of all documents in a deleted state:

Copy to clipboard

```
SELECT id, status__v
FROM documents
WHERE status__v = DELETEDSTATE()
```
