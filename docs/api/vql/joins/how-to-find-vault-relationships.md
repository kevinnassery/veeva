<!-- source: https://general.veevavault.dev/vql/joins/how-to-find-vault-relationships/ -->
<!-- title: How to Find Vault Relationships -->

# How to Find Vault Relationships

In order to perform VQL queries on Vault objects or documents, the query must use the exact inbound or outbound relationship name. There are several methods for finding the correct relationship name:

* Find the relationship in the [Vault Admin UI](https://platform.veevavault.help/en/gr/28740/#how-to-view-relationships)
* Use [`SHOW RELATIONSHIPS`](/vql/clauses/show)
* Use the [Vault API metadata endpoints](/vault-api/getting-started/endpoint-structure)

Before looking for the relationship name, you must first know:

* The primary query target.
* Whether you need the inbound or outbound relationship.

Learn more in [About Join Queries](/vql/joins/about-join-queries).

Refer to the [Query Targets documentation](/vql/query-targets) for information on relationships when the query target is not `documents` or a Vault object.

## SHOW RELATIONSHIPS

Use the [`SHOW RELATIONSHIPS`](/vql/clauses/show) clause in a VQL query on the target object to retrieve the queryable relationships on the join target.

For example, the results of a`SHOW` query on `product__v` include `approved_countries__cr`:

Copy to clipboard

```
{
    "name": "approved_countries__cr",
    "target": "approved_country__c",
    "type": "inbound"
}
```

This indicates that an inbound relationship exists on the *Product* object from the *Approved Country* object, and you can create a subquery using the inbound `approved_countries__cr` relationship name.

## The Metadata APIs

The relationship names to use in queries are exposed in the Document and Object Metadata APIs for fields of type `ObjectReference` when the `objectType` is a Vault object.

* [Document Metadata API](/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-all-document-fields): `/api/{version}/metadata/objects/documents/properties`
* [Object Metadata API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata): `/api/{version}/metadata/vobjects/{object name}`

To find relationships on a document or object, search the metadata response for fields with the following attributes:

| Attribute | Value to Look For | Description |
| --- | --- | --- |
| `type` | `ObjectReference` | Confirms the field references an object. |
| `objectType` | `{object_name__v}` | Indicates the target is a Vault object. This includes standard objects (`__v`) and custom objects (`__c`), but does not include users, groups, or workflows. |
| `relationshipType` | `reference`, `parent`, `child`, `reference_inbound`, `reference_outbound` | Defines the nature of the relationship, which dictates whether you can use a subquery or lookup. |
| `relationshipName` | `{relationship_name__vr}` or `{relationship_name__cr}` | **The exact name to use in the VQL query.** Standard object relationships end in `__vr`, and custom relationships end in `__cr`. |
