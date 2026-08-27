<!-- source: https://general.veevavault.dev/vql/query-targets/hierarchy-relationship/ -->
<!-- title: Hierarchy Relationship -->

# Hierarchy Relationship

Use the `hierarchy_node_sysr` relationship to see the ordering of hierarchical objects. This relationship is available on hierarchy-enabled Vault objects, such as `edl_template__v`, `edl__v`, `submission_metadata__v`, and `visual_hierarchy__v`.

The `hierarchy_node_sysr` relationship cannot be queried directly and is only available as a
subquery. It is a one-to-one inbound relationship.

Access to hierarchy node data depends on the user’s permissions on the parent hierarchical record.

## Queryable Fields

| Field Name | Description |
| --- | --- |
| `node_id_sys` | The ID of the hierarchy node (distinct from the record ID). |
| `order_sys` | The numerical position of the node among its siblings. |
| `parent_node_id_sys` | The ID of the parent hierarchy node (`null` for root nodes). |
| `last_modified_date_sys` | The date the hierarchy node was last modified. |

## Query Example

Copy to clipboard

```
SELECT uuid__v,
  (SELECT order__sys from hierarchy_node__sysr) 
FROM edl_template__v
WHERE root_content_plan_template__v.uuid__v = '47c296ch'
```
