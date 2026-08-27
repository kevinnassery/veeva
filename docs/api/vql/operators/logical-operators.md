<!-- source: https://general.veevavault.dev/vql/operators/logical-operators/ -->
<!-- title: Logical Operators -->

# Logical Operators

When querying documents or Vault objects, you can use certain logical operators in the [`WHERE` clause](/vql/clauses/where) and [`FIND` search string](/vql/clauses/find).

## AND

Use the `AND` operator to retrieve results that meet two or more conditions. The following query returns *Approved* documents of the *Reference Document* type:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE TONAME(type__v) = 'reference_document__c' AND TONAME(status__v) = 'approved__v'
```

## & (Bitwise AND)

Use the `&` operator to perform a bitwise `AND` operation between a Bitmask field and a literal bitmask value. This allows you to filter records based on the result of the bitwise operation.

The `&` operator is only supported on raw object query targets.

The bitmask value must be an integer between `0` and `65535`. The bitwise result must be compared to a number value.

The following query evaluates the bitmask field `access_group__v` against the literal value `40049` and returns only the records where the bitwise intersection is greater than zero:

Copy to clipboard

```
SELECT id, name__v, status__v 
FROM master_data__v 
WHERE access_group__v & 40049 > 0
```

## NOT

Use the `NOT` operator to negate an entire search string in the `FIND` clause. This operator is not supported on other clauses.

The following query returns documents that do not contain the word *cholecap* (case insensitive):

Copy to clipboard

```
SELECT id, name__v
FROM documents
FIND (NOT 'cholecap' )
```

## OR

Use the `OR` operator to retrieve results that meet any of two or more conditions. Note that VQL does not support the `OR` operator between different query objects in a `WHERE` clause.

The following query includes documents with a version creation date or modified date after midnight on April 23, 2018:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE version_creation_date__v > '2018-04-23' OR version_modified_date__v > '2018-04-23'
```
