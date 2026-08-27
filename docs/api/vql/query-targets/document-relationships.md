<!-- source: https://general.veevavault.dev/vql/query-targets/document-relationships/ -->
<!-- title: Document Relationships -->

# Document Relationships

You can use the `relationships` query target to query links in annotations and other document relationships.

Use the [Retrieve Document Type Relationships API](/vault-api/api-reference/26.2/documents/document-relationships/retrieve-document-type-relationships) to get the relationships queryable fields and object relationships. This includes the `source__vr` and `target__vr` relationships, which you can use to filter the returned document relationships.

## Relationship Query Examples

The following are examples of relationship queries.

### Annotation Link Query

The following query retrieves relationship properties for link annotations:

Copy to clipboard

```
SELECT source_doc_id__v, source_major_version__v, source_minor_version__v, relationship_type__v, target_doc_id__v, target_major_version__v, target_minor_version__v
FROM relationships
WHERE relationship_type__v = 'references__v'
```

### Related Document Metadata Query

The following query retrieves document metadata where the source document has a document type of Promotional Material:

Copy to clipboard

```
SELECT source__vr.name__v, source__vr.document_number__v, relationship_type__v, target__vr.name__v, target__vr.document_number__v
FROM relationships
WHERE TONAME(source__vr.type__v) = 'promotional_material__c'
```
