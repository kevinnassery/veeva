<!-- source: https://general.veevavault.dev/vql/query-targets/groups/ -->
<!-- title: Groups -->

# Groups

You can use the `group__sys` and `group_membership__sys` query targets to query Vault group and user membership information. This allows you to retrieve, filter, and paginate over a large number of groups in your Vault. Groups are available for query in v18.3+ only.

## User & Group Relationships

For relationships between users and groups, both `user__sys` and `group__sys` objects have a `group_membership_sysr` "down" relationship that joins the `user__sys` and `group__sys` objects.

The `group_membership_sys` exposes the following parent relationships:

* `user__sysr` relationship to the `user__sys` object.
* `group__sysr` relationship to the `group__sys` object.

## Group Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The following fields are queryable for the `group__sys` object:

| Name | Description |
| --- | --- |
| `id` | The group ID. |
| `name__v` | The group name. This field must be unique. |
| `label__v` | UI label for the group. This field must be unique. |
| `status__v` | The current state of the group (Active or Inactive). |
| `description__sys` | The description of the group. |
| `system_group__sys` | Specifies if the group is editable. User-managed groups will have a value of `false`, while system-managed groups will have a value of `true`. |
| `type__sys` | Points to `group_types__sys` standard picklist. |
| `created_date__v` | Timestamp when the group was created. |
| `created_by__v` | ID of a user who created the group. |
| `modified_date__v` | Timestamp when the group was updated. |
| `modified_by__v` | ID of a user who updated the group. |

## Group Membership Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The following fields are queryable for the `group_membership__sys` object:

| Name | Description |
| --- | --- |
| `id` | The group membership ID. |
| `user_id__sys` | ID of the `user_sys` object. |
| `group_id__sys` | ID of the `group_sys` object. |

## Group Query Examples

The following are examples of standard group queries.

### Simple Group Query

Retrieve all user-managed groups:

Copy to clipboard

```
SELECT id, name__v, label__v, type__sys
FROM group__sys
WHERE type__sys = 'user_managed__sys'
```

### Simple Group Membership Query

Retrieve all group IDs where user with ID 123 is a member:

Copy to clipboard

```
SELECT group_id__sys
FROM group_membership__sys
WHERE user__sysr.id = 123
```

### Users-to-Groups Query

For all active users, retrieve the user-managed groups the user is a member of:

Copy to clipboard

```
SELECT id,
    (SELECT group__sysr.name__v, group__sysr.label__v
     FROM group_membership__sysr
     WHERE group__sysr.type__sys = 'user_managed__sys')
FROM user__sys
WHERE status__v = 'active__v'
```

### Groups-to-Users Query

For each user-managed Approvers group, retrieve the active members:

Copy to clipboard

```
SELECT id,
    (SELECT user_id__sys
     FROM group_membership__sysr
     WHERE user__sysr.status__v = 'active__v')
FROM group__sys
WHERE name__v = 'approvers__c' AND type__sys = 'user_managed__sys'
```

### Group Label Query

Retrieve the members of the group with the label 'All Product Experts':

Copy to clipboard

```
SELECT user_id__sys, user__sysr.name__v, user__sysr.email__sys
FROM group_membership__sys
WHERE group__sysr.label__v = 'All Product Experts'
```

### Group Name Query

Retrieve the members of the group with the name `all_product_experts__c`:

Copy to clipboard

```
SELECT user_id__sys, user__sysr.name__v, user__sysr.email__sys
FROM group_membership__sys
WHERE group__sysr.name__v = 'all_product_experts__c'
```

### Group ID Query

Retrieve the members of the group with the ID '1394917493501':

Copy to clipboard

```
SELECT user_id__sys, user__sysr.name__v, user__sysr.email__sys
FROM group_membership__sys
WHERE group_id__sys = 1394917493501
```
