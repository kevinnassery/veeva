<!-- source: https://general.veevavault.dev/vql/query-targets/document-roles/ -->
<!-- title: Document Roles -->

# Document Roles

You can use the `documents` and `doc_role__sys` objects to query document roles. This allows you to see which users and groups are assigned to certain roles on a document, as well as filter documents by the users and groups assigned to roles. Document roles are available for query in v21.1+ only.

Note

The *External Viewer* pseudo-role is not available as a query target. Vault only assigns this role to non-Vault users who receive a document through the *Send as Link* action. Learn more about [Send as Link in Vault Help](https://platform.veevavault.help/en/lr/4754).

## Document Roles Relationships

The `documents` object exposes the `doc_roles__sysr` relationship. This is a one-to-many relationship which points to `doc_role__sys` child objects.

The `doc_role__sys` object exposes the following relationships:

| Name | Description |
| --- | --- |
| `user__sysr` | A child relationship allowing a join with the `user__sys` object. |
| `group__sysr` | A child relationship allowing a join with the `group__sys` object. |
| `document__sysr` | A parent relationship allowing a join with `documents`. |

## Document Roles Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The following fields are queryable for the `doc_role__sys` object:

| Name | Description |
| --- | --- |
| `role_name__sys` | The name of the role, for example `reviewer__v`. |
| `document_id` | The document ID. |
| `user__sys` | The ID of the user in the role. |
| `group__sys` | The ID of the group in the role. |

## Document Role Query Examples

The following are examples of standard document roles queries.

### Query Roles by Document

Find all roles and their assigned users and groups on a document with the `document_id` 627:

Copy to clipboard

```
SELECT role_name__sys, user__sys, group__sys
FROM doc_role__sys
WHERE document_id = 627
```

### Query by Users

Find documents where user 123 is in any role:

Copy to clipboard

```
SELECT document_id, user__sys, user__sysr.username__sys, role_name__sys
FROM doc_role__sys
WHERE user__sys = '123'
```

### Query by Groups

Find documents with the legal reviewers group assigned the reviewer role:

Copy to clipboard

```
SELECT document_id, role_name__sys
FROM doc_role__sys
WHERE role_name__sys = 'reviewer__v' AND group__sysr.label__v = 'Legal Reviewers'
```

### Query Documents With Specific Users or Groups in a Specific Role

Find the ID and name for documents where users 123 or 456 and groups 9876 or 5432 are assigned the approver role:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE id IN (SELECT document_id FROM doc_roles__sysr WHERE user__sys CONTAINS (123, 456) OR group__sys CONTAINS (9876, 5432) AND role_name__sys = 'approver__v')
```

### Query Documents With a Specific Role (Subquery)

Find the ID, name, and owner role for documents with id 123 or 456:

Copy to clipboard

```
SELECT id, name__v, (SELECT id, user__sysr.email__sys FROM doc_roles__sysr WHERE role_name__sys = 'owner__c')
FROM documents
WHERE id CONTAINS (123, 456)
```
