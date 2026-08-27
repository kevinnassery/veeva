<!-- source: https://general.veevavault.dev/vql/functions-options/find-scopes-distance/scope-fields/ -->
<!-- title: SCOPE Fields -->

# SCOPE Fields

In v15.0+, use `SCOPE {field}` to search a specific document field or Vault object field.

In v22.3+, use `SCOPE {fields}` to search multiple fields when querying Vault objects, up to a maximum of 25 fields.

When querying Vault objects, `SCOPE {fields}` supports fields of data type String (*Text*, *LongText*, and *RichText* fields) and object reference fields.

When querying documents, `SCOPE {field}` only supports fields of data type String (*Text*, *LongText*, and *RichText* fields).

In v25.3+, you can use a single `SCOPE {field}` operation with one single-value object or document reference field lookup. For example, `FROM documents FIND ('cholecap' SCOPE obj_ref__cr.name__v)`. On documents, you can use `SCOPE {field}` on a lookup but not on the object reference field directly.

A single-value lookup has `repeating` ("Allow user to select multiple values" in the Vault UI) set to `false`.

`SCOPE` does not support picklist fields. To query picklist fields, use [SCOPE ALL](/vql/functions-options/find-scopes-distance/scope-all) or [SCOPE PROPERTIES](/vql/functions-options/find-scopes-distance/scope-properties).

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
FIND ('{search phrase}' SCOPE {field_1, field_2})
```

## Query Examples

The following are examples of queries using `SCOPE {fields}`.

### Query: Search a Specific Document Field

The following query searches the `name__v` document field for the search term *insulin*. You can only include one document field.

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('insulin' SCOPE name__v)
```

### Query: Search a Specific Object Field

The following query searches the `name__v` and `generic_name__vs` object fields for the search term *phosphate*:

Copy to clipboard

```
SELECT id, name__v
FROM product__v
FIND ('phosphate' SCOPE name__v, generic_name__vs)
```

### Query: Combining SCOPE Fields with SCOPE CONTENT

The following query returns all documents where the name contains the search term *cholecap* and the document content also contains *prescribing* or *information*:

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND ('cholecap' SCOPE name__v AND 'prescribing information' SCOPE CONTENT)
```

### Query: Combining FIND with WHERE

When using `FIND` with or without `SCOPE`, you can use the `WHERE` clause to narrow results. `WHERE` must be placed after `FIND` and `SCOPE`. The following query searches the `generic_name__vs` field for the search term *phosphate* in all *Product* records with a specific therapeutic area:

Copy to clipboard

```
SELECT id, name__v
FROM product__v
FIND ('phosphate' SCOPE generic_name__vs)
WHERE therapeutic_area__vs = 'cardiology__vs'
```

### Query: Search a Related Document Using a Lookup

The following query returns *Product* records where the term *cholecap* appears in the `name__v` field of *Materials* (`materials__c`) related document:

Copy to clipboard

```
SELECT id, name__v, materials__c
FROM product__v
FIND ('cholecap' SCOPE materials__cr.name__v)
```
