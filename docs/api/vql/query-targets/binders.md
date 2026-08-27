<!-- source: https://general.veevavault.dev/vql/query-targets/binders/ -->
<!-- title: Binders -->

# Binders

You can use the `binders` and `binder_node__sys` objects to query binders for the following:

* Given a document, or a set of documents, find binders which contain them.
* Given a binder, or a set of binders, find documents contained with them.

The `binders` object is an extension of the `documents` object and supports the same VQL functions. Binders are available for query in v18.2+.

## Binder Relationships

The `binders` object exposes the `binder_nodes__sysr` relationship. This relationship is a "down" relationship and points to `binder_nodes__sys` child objects.

The `binder_node__sys` object exposes the following relationships:

| Name | Description |
| --- | --- |
| `binder__sysr` | A parent lookup relationship that points to the `binders` object. |
| `document__sysr` | A lookup relationship to a document at the node. This is applicable only if the node is a document (or a binder). |
| `child_nodes__sysr` | A self-referencing "down" relationship pointing to `binder_node__sys` child objects. This is applicable only if the node is a section. |
| `parent_node__sysr` | A self-referencing parent lookup relationship pointing to a `binder_node__sys` object at the parent node. |

## Binder Node Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The following fields are queryable for the `binder_node__sys` object:

| Name | Description |
| --- | --- |
| `id` | The node ID. |
| `name__v` | The section name. This field has a value for nodes of type "section" and is `null` for document and binder nodes. |
| `parent_binder_id__sys` | ID of the parent binder where this node lives. |
| `parent_binder_major_version__sys` | The major version of the parent binder. |
| `parent_binder_minor_version__sys` | The minor version of the parent binder. |
| `parent_node_id__sys` | ID of the parent `binder_node__sys` object. |
| `section_id__sys` | Document ID or section ID specific to the binder. |
| `parent_section_id__sys` | Section ID of the parent node, such as "rootNode". |
| `order__sys` | The ordinal position of the node within its parent. |
| `content_id__sys` | Document ID or binder ID. |
| `content_major_version__sys` | The major version of the content. |
| `content_minor_version__sys` | The minor version of the content. |
| `type__sys` | Points to the standard picklist `binder_node_types__sys`. |
| `created_date__v` | Timestamp when the node was created. |
| `created_by__v` | ID of the user who created the node. |
| `modified_date__v` | Timestamp when the node was updated. |
| `modified_by__v` | ID of the user who updated the node. |

## Binder Query Examples

The following are examples of standard binder queries.

### Simple Binder Query

Find latest steady-state versions of binders, the documents they contain, and where within the binder structure the document is contained:

Copy to clipboard

```
SELECT LATESTVERSION id,
    (SELECT parent_node_id__sys, parent_node__sysr.type__sys, parent_node__sysr.name__v, document__sysr.id, document__sysr.name__v
    FROM binder_nodes__sysr)
FROM ALLVERSIONS binders
WHERE status__v = steadystate()
```

### Binder Query for Specific Documents

Find binders containing specific documents:

Copy to clipboard

```
SELECT binder__sysr.id, binder__sysr.name__v
FROM binder_node__sys
WHERE type__sys = 'document' AND document__sysr.name__v = 'Test'
```

### Query Documents Within a Specific Section

Find documents within sections named "Test Section".

Copy to clipboard

```
SELECT binder__sysr.id, document__sysr.id
FROM binder_node__sys
WHERE type__sys = 'document' AND parent_node__sysr.type__sys = 'section' AND parent_node__sysr.name__v = 'Test Section'
```

### Query Binders and Sections Containing Documents

Find binders and section names containing specific documents.

Copy to clipboard

```
SELECT binder__sysr.id, binder__sysr.name__v, parent_node__sysr.name__v, parent_node__sysr.type__sys
FROM binder_node__sys
WHERE type__sys = 'document' AND document__sysr.name__v 'Test'
```
