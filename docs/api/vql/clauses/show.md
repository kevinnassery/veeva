<!-- source: https://general.veevavault.dev/vql/clauses/show/ -->
<!-- title: SHOW -->

# SHOW

In v25.2+, the `SHOW` clause allows you to retrieve the query target schema for a Vault:

* `SHOW TARGETS` retrieves a list of query targets.
* `SHOW FIELDS FROM {query target}` retrieves the queryable fields for a query target.
* `SHOW RELATIONSHIPS FROM {query target}` retrieves the queryable relationships for a query target.

## SHOW TARGETS

Use `SHOW TARGETS` to retrieve a list of all query targets the currently authenticated user has permission to query. The response includes the name, label, and plural label for each query target.

### Syntax

Copy to clipboard

```
SHOW TARGETS
```

### Operators

You can use the following [operators](/vql/operators) with `SHOW TARGETS`:

| Name | Syntax | Description |
| --- | --- | --- |
| [LIKE](/vql/operators/comparison-operators#LIKE) | `SHOW TARGETS LIKE '{value%}'` | Find query targets by matching the query target name using a wildcard string. |

### Query Examples

The following are examples of queries using `SHOW TARGETS`.

#### Query: Show Workflow-Related Query Targets

The following query retrieves all query targets with a name containing the word "workflow":

Copy to clipboard

```
SHOW TARGETS
LIKE '%workflow%'
```

#### Response: Show Workflow-Related Query Targets

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 10,
        "total": 10
    },
    "data": [
        {
            "name": "active_workflow__sys",
            "label": "active_workflow__sys",
            "label_plural": "active_workflow__sys"
        },
        {
            "name": "active_workflow_item__sys",
            "label": "active_workflow_item__sys",
            "label_plural": "active_workflow_item__sys"
        },
        {
            "name": "active_workflow_task__sys",
            "label": "active_workflow_task__sys",
            "label_plural": "active_workflow_task__sys"
        },
        {
            "name": "active_workflow_task_item__sys",
            "label": "active_workflow_task_item__sys",
            "label_plural": "active_workflow_task_item__sys"
        },
        {
            "name": "inactive_workflow__sys",
            "label": "inactive_workflow__sys",
            "label_plural": "inactive_workflow__sys"
        },
        {
            "name": "inactive_workflow_item__sys",
            "label": "inactive_workflow_item__sys",
            "label_plural": "inactive_workflow_item__sys"
        },
        {
            "name": "inactive_workflow_task__sys",
            "label": "inactive_workflow_task__sys",
            "label_plural": "inactive_workflow_task__sys"
        },
        {
            "name": "inactive_workflow_task_item__sys",
            "label": "inactive_workflow_task_item__sys",
            "label_plural": "inactive_workflow_task_item__sys"
        },
        {
            "name": "workflow_variable__sys",
            "label": "Workflow Variable",
            "label_plural": "Workflow Variables"
        },
        {
            "name": "workflows",
            "label": "workflows",
            "label_plural": "workflows"
        }
    ]
}
```

## SHOW FIELDS

In 25.2+, use `SHOW FIELDS` to retrieve the queryable fields on the specified query target. The response includes the name, label, field type, and optional relationship name for each field.

You must use the `FROM` clause to specify the query target. Other clauses are not supported with `SHOW FIELDS`.

### Syntax

Copy to clipboard

```
SHOW FIELDS
FROM {query target}
```

### Operators

You can use the following [operators](/vql/operators) with `SHOW FIELDS`:

| Name | Syntax | Description |
| --- | --- | --- |
| [LIKE](/vql/operators/comparison-operators#LIKE) | `SHOW FIELDS FROM {query target} LIKE '{value%}'` | Find fields by matching the field name using a wildcard string. |

### Query Examples

The following are examples of queries using `SHOW FIELDS`.

#### Query: Show Document Fields Starting with "a"

The following query returns a list of document fields with a field name starting with "a":

Copy to clipboard

```
SHOW FIELDS
FROM documents
LIKE 'a%'
```

#### Response: Show Document Fields Starting with "a"

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
            "name": "approved_country__c",
            "label": "Approved Country",
            "type": "ObjectReference",
            "relationship_name": "document_approved_country__cr"
        },
        {
            "name": "approver__v",
            "label": "Approver",
            "type": "ObjectReference"
        },
        {
            "name": "archived_date__sys",
            "label": "Archived Date",
            "type": "DateTime"
        }
    ]
}
```

## SHOW RELATIONSHIPS

In 25.2+, use `SHOW RELATIONSHIPS` to retrieve the queryable relationships on the specified query target. The response includes the name, target, and type (`inbound` or `outbound`) for each relationship.

You must use the `FROM` clause to specify the query target. Other clauses are not supported with `SHOW RELATIONSHIPS`.

### Syntax

Copy to clipboard

```
SHOW RELATIONSHIPS
FROM {query target}
```

### Operators

You can use the following [operators](/vql/operators) with `SHOW RELATIONSHIPS`:

| Name | Syntax | Description |
| --- | --- | --- |
| [LIKE](/vql/operators/comparison-operators#LIKE) | `SHOW RELATIONSHIPS FROM {query target} LIKE '{value%}'` | Find relationships by matching the relationship name using a wildcard string. |

### Query Examples

The following are examples of queries using `SHOW RELATIONSHIPS`.

#### Query: Show Relationships to Custom Fields on an Object

The following query returns a list of relationships on the *Product* object with a name ending in `__cr`. The `LIKE` operator filters on relationships with a name containing `__cr`.

Copy to clipboard

```
SHOW RELATIONSHIPS 
FROM product__v
LIKE '%__cr'
```

#### Response: Show Relationships to Custom Fields on an Object

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 8,
        "total": 8
    },
    "data": [
        {
            "name": "activities__cr",
            "target": "activity__c",
            "type": "inbound"
        },
        {
            "name": "approved_countries__cr",
            "target": "approved_country__c",
            "type": "inbound"
        },
        {
            "name": "manufacturer__cr",
            "target": "manufacturer__c",
            "type": "outbound"
        },
        {
            "name": "marketing_campaigns__cr",
            "target": "marketing_campaign__c",
            "type": "inbound"
        },
        {
            "name": "product_labels__cr",
            "target": "product_label__c",
            "type": "inbound"
        },
        {
            "name": "region__cr",
            "target": "region__c",
            "type": "outbound"
        },
        {
            "name": "reviewer__cr",
            "target": "user__sys",
            "type": "outbound"
        },
        {
            "name": "tests__cr",
            "target": "test__c",
            "type": "inbound"
        }
    ]
}
```
