<!-- source: https://general.veevavault.dev/vql/clauses/where/ -->
<!-- title: WHERE -->

# WHERE

Use the `WHERE` clause in VQL as a search filter to retrieve results that meet a specified condition.

* The `WHERE` clause supports a variety of [operators](/vql/operators), allowing you to further refine query results.
* Fields vary depending on the document or object being queried.
* Unless otherwise noted, the `WHERE` clause supports the same fields as the `SELECT` clause.

Note

When querying documents, it is best practice to use [TONAME()](/vql/functions-options/toname) in the `WHERE` clause to provide the field name as the filter value. This ensures that the filter works for all users, including those with localized labels in their Vault.

## Syntax

Copy to clipboard

```
SELECT {fields}
FROM {query target}
WHERE {field} {operator} {value}
```

## Functions & Options

You can use the following functions and query target options in the `WHERE` clause. For full technical details, see the [VQL Functions & Options](/vql/functions-options) reference.

### Filtering Documents

These functions are used to filter results when querying the `documents` target.

| Name | Description | API Version |
| --- | --- | --- |
| [`TONAME()`](/vql/functions-options/toname) | Filter by the document field name instead of the label. | v20.3+ |
| [`DELETEDSTATE()`](/vql/functions-options/state-functions) | Filter for documents in a deleted state. | v19.2+ |
| [`OBSOLETESTATE()`](/vql/functions-options/state-functions) | Filter for documents in an obsolete state. | v8.0+ |
| [`STEADYSTATE()`](/vql/functions-options/state-functions) | Filter for documents in a steady state. | v8.0+ |
| [`SUPERSEDEDSTATE()`](/vql/functions-options/state-functions) | Filter for documents in a superseded state. | v8.0+ |

### Filtering Object Records

These functions are used to refine filters when querying Vault objects.

| Name | Description | API Version |
| --- | --- | --- |
| [`CASEINSENSITIVE()`](/vql/functions-options/caseinsensitive) | Bypass case sensitivity of field values. | v14.0+ |
| [`STATETYPE()`](/vql/functions-options/statetype) | Filter for object records with a specific state type. | v19.3+ |
| [`TOLABEL()`](/vql/functions-options/tolabel) | Filter by the object field label instead of the name. | v24.1+ |

### Filtering Attachments

These functions are used to filter by file-specific metadata when querying Attachment fields.

| Name | Description | API Version |
| --- | --- | --- |
| [`FILENAME()`](/vql/functions-options/attachment-field-functions) | Filter by the file name instead of the file handle. | v24.3+ |

## Operators

You can use all [symbolic comparison operators](/vql/operators/comparison-operators#Symbolic_Operators) and the following [operators](/vql/operators) in the `WHERE` clause:

| Name | Syntax | Description |
| --- | --- | --- |
| [`AND`](/vql/operators/logical-operators#AND) | `WHERE {field_1} = {value_1} AND {field_2} = {value_2}` | Field values match both specified conditions. |
| [`& (Bitwise AND)`](/vql/operators/logical-operators#Bitwise_AND) | `WHERE {field} & {bitmask} > 0` | Filter a Bitmask field by the result of a bitwise operation. Supported on raw object query targets only. |
| [`BETWEEN`](/vql/operators/comparison-operators#BETWEEN) | `WHERE {field} BETWEEN {value_1} AND {value_2}` | Compare data between two different values. |
| [`CONTAINS`](/vql/operators/comparison-operators#CONTAINS) | `WHERE {field} CONTAINS ({value_1},{value_2},{value_3})` | Field values match any of the specified values. |
| [`IN`](/vql/operators/comparison-operators#IN) | `WHERE {field} IN (SELECT {fields} FROM {query target})` | Used for inner join relationship queries. |
| [`LIKE`](/vql/operators/comparison-operators#LIKE) | `WHERE {field} LIKE '{value%}'` | Use wildcards `%` to match partial values. |
| [`OR`](/vql/operators/logical-operators#OR) | `WHERE {field_1} = {value_1} OR {field_2} = {v2}` | Field values match either specified condition. |

## Query Examples

The following are examples of queries using `WHERE`.

### Query: Filter by Document Type

The following query returns a list of documents of the *Commercial Content* document type.

Copy to clipboard

```
SELECT id, name__v, status__v
FROM documents
WHERE TONAME(type__v) = 'commercial_content__c'
```

### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 6,
        "total": 6
    },
    "data": [
        {
            "id": 68,
            "name__v": "Cholecap Akathisia Temporally associated with Adult Major Depressive Disorder",
            "status__v": "Draft"
        },
        {
            "id": 65,
            "name__v": "Gludacta Package Brochure",
            "status__v": "Approved"
        },
        {
            "id": 64,
            "name__v": "Gludacta Logo Light",
            "status__v": "Approved"
        },
        {
            "id": 63,
            "name__v": "Gludacta Logo Dark",
            "status__v": "Approved"
        }
    ]
}
```

### Query: Retrieve Documents by Date or DateTime Value

The following query returns the ID and name of all documents created after October 31, 2015. The value `'2015-11-01'` corresponds to November 1st, 2015 at midnight (`00:00:00`), so results will include documents created on November 1st at `00:00:01` or later. Learn more about [Date and DateTime field values](/vql/references/language-specifications/data-types-formats#Date_Time_Formats).

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE document_creation_date__v > '2015-11-01'
```

### Query: Retrieve Products by Case-Insensitive Value

The following query returns results even if the field value is “Cholecap”, “choleCap”, or another case variation. Learn more about [case sensitivity in VQL queries](/vql/references/language-specifications/syntax-basics#Case_Sensitivity) and the [`CASEINSENSITIVE()`](/vql/functions-options/caseinsensitive) function.

Copy to clipboard

```
SELECT id
FROM product__v
WHERE CASEINSENSITIVE(name__v) = 'cholecap'
```

### Query: Retrieve Products by State Type

The following query returns all products in the *Complete* state. Learn more about the [`STATETYPE()`](/vql/functions-options/statetype) function.

Copy to clipboard

```
SELECT id
FROM product__v
WHERE state__v = STATETYPE('complete_state__sys')
```

### Query: Retrieve Documents by Boolean Field Value

The following query returns all documents containing a Crosslink field with the value `true`. Learn more about [using boolean values](/vql/references/system-limits-performance/queryable-field-types#YesNo_Fields).

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE crosslink__v = true
```

### Query: Retrieve Documents with Null Field Values

The following query returns all documents with no value in the *External ID* field. Learn more about [using null values](/vql/references/language-specifications/result-handling#Null_Field_Values).

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE external_id__v = null
```
