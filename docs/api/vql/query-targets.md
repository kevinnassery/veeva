<!-- source: https://general.veevavault.dev/vql/query-targets/ -->
<!-- title: Query Targets -->

# Query Targets

The target of a query is the object specified in the `FROM` clause. The target object represents a collection of Vault data such as documents and must be queryable.

This section provides a reference on common query targets and their queryable fields and relationships, including those with metadata that is not retrievable via the standard metadata API.

Query targets include documents, Vault objects, users, events, and relationships.

Note

Not all [object fields](/vql/references/system-limits-performance/queryable-field-types) are queryable.

To query one of these objects, use its name attribute. For example, to query the documents object, enter `documents` as the query target. To query the *Product* object, enter `product__v` as the query target.

* [Documents](/vql/query-targets/documents/)
* [Vault Objects](/vql/query-targets/vault-objects/)
* [Attachments](/vql/query-targets/attachments/)
* [API Access Tokens](/vql/query-targets/api-access-tokens/)
* [Binders](/vql/query-targets/binders/)
* [Document Events](/vql/query-targets/document-events/)
* [Document Relationships](/vql/query-targets/document-relationships/)
* [Document Roles](/vql/query-targets/document-roles/)
* [Document Signatures](/vql/query-targets/document-signatures/)
* [Groups](/vql/query-targets/groups/)
* [Hierarchy Relationship](/vql/query-targets/hierarchy-relationship/)
* [Jobs](/vql/query-targets/jobs/)
* [Matched Documents](/vql/query-targets/matched-documents/)
* [Object Record Roles Relationship](/vql/query-targets/object-record-roles-relationship/)
* [Renditions](/vql/query-targets/renditions/)
* [Users](/vql/query-targets/users/)
* [Vault Component Definitions](/vql/query-targets/vault-component-definitions/)
* [Vault Component Objects](/vql/query-targets/vault-component-objects/)
* [Workflows](/vql/query-targets/workflows/)
