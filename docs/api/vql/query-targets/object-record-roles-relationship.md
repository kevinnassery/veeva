<!-- source: https://general.veevavault.dev/vql/query-targets/object-record-roles-relationship/ -->
<!-- title: Object Record Roles Relationship -->

# Object Record Roles Relationship

Use the `roles__sysr` relationship to retrieve role assignments created through manual assignment, Custom Sharing Rules, Matching Sharing Rules, and Child Security. This relationship is available on Vault object targets with roles enabled.

When querying objects configured with dynamic role assignments, such as Tree Security, the relationship returns supported static data like Custom or Matching Sharing Rules. Due to record visibility rules, it does not include information derived from the dynamic role assignments.

The `roles__sysr` inbound relationship cannot be queried directly and is only available as a subquery.

## Relationships

| Name | Description |
| --- | --- |
| `user__sysr` | A child relationship allowing a join with the `user__sys` object. |
| `group__sysr` | A child relationship allowing a join with the `group__sys` object. |

## Queryable Fields

| Field Name | Description |
| --- | --- |
| `role_name__sys` | The name of the role. For example, `reviewer__v`. |
| `user__sys` | The ID of the user in the role. |
| `group__sys` | The ID of the group in the role. |
| `object_record_id__sys` | The object record ID. |
| `object_name__sys` | The Vault object name. For example, `country__v`. |
| `assignment_type__sys` | Indicates how the role was assigned. Valid picklist values include: `manual_assignment__sys`, `custom_sharing_rule__sys`, `matching_sharing_rule__sys`. |

## Query Example

The following query retrieves the ID and name of a specific *Product* record, and uses a subquery to retrieve each role assignment's name, assigned user, and assignment type for that record.

Copy to clipboard

```
SELECT id, name__v,
  (SELECT role_name__sys, user__sys, assignment_type__sys FROM roles__sysr)
FROM product__v
WHERE id = 'V0B000000003009'
```
