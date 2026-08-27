<!-- source: https://general.veevavault.dev/vql/functions-options/favorites-recent/ -->
<!-- title: FAVORITES & RECENT -->

# FAVORITES & RECENT

Use the `FAVORITES` and `RECENT` options to return documents and object records from the currently authenticated user’s *Favorites* and *Recent* lists in the Vault UI.

* **FAVORITES**: Filter records or documents to those the currently authenticated user has marked as a favorite.
* **RECENT**: Filter records or documents to the 20 the currently authenticated user has viewed most recently (in descending order by date).
* **Documents**: Available in v22.2+.
* **Object Records**: Available in v23.2+.

You cannot use the `FAVORITES` and `RECENT` options in subqueries or with other query target options such as `ALLVERSIONS`.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM FAVORITES|RECENT {query target}
```

## Query Examples

The following are examples of queries using `FAVORITES` and `RECENT`.

### Query: Retrieve Favorite Documents

The following query returns the ID and name of all documents in the currently authenticated user’s *Favorites* list:

Copy to clipboard

```
SELECT id, name__v
FROM FAVORITES documents
```

### Query: Retrieve Recent Documents

The following query returns the ID and name of all documents in the currently authenticated user’s *Recent Documents* list:

Copy to clipboard

```
SELECT id, name__v
FROM RECENT documents
```

### Query: Retrieve Favorite Object Records

The following query returns the ID and name of all *Product* records in the currently authenticated user’s *Favorites* list:

Copy to clipboard

```
SELECT id, name__v
FROM FAVORITES product__v
```

### Query: Retrieve Recent Object Records

The following query returns the ID and name of all *Product* records in the currently authenticated user’s *Recent Products* list:

Copy to clipboard

```
SELECT id, name__v
FROM RECENT product__v
```
