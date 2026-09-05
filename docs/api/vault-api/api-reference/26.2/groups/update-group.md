<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/groups/update-group/ -->
<!-- title: Update Group -->

# Update Group

Update editable group field values. Add or remove group members and security profiles.

PUT`/api/{version}/objects/groups/{group_id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{group_id}` | The group `id` field value. |

## Body Parameters

In the body of the request, add any editable fields you wish to update.

| Name | Description |
| --- | --- |
| `label__v` optional | Updates the label of the group. |
| `members__v` optional | Add a comma-separated list of user IDs. This manually assigns individual users to the group. |
| `security_profiles__v` optional | Add a comma-separated list of security profiles. |
| `active__v` optional | To set the group to inactive, set this value to `false`. |
| `group_description__v` optional | Updates the description of the group. |
| `allow_delegation_among_members__v` optional | When set to `true`, members of this group will only be allowed to delegate access to other members of the same group. You can set this field for user and system managed groups. If omitted, defaults to `false`. Learn more about [Delegate Access](https://platform.veevavault.help/en/gr/15015). |

#### Request Details

You may change the values of any editable group field. Changing the `security_profiles__v` will automatically replace all previous implied users assigned via the previous security profile.

#### Add or Remove Users

To add or remove group members, add a comma-separated list of user IDs in `members__v`. This replaces all previous users who were manually assigned. This action is not additive.

Alternatively, you can add or remove group members without replacing previous users in the following ways:

* To add users, set the value of `members__v` to `add` followed by a comma-separated list of user IDs enclosed in parenthesis. For example `add (userID1, userID2)`. This only adds the specified users to the group.
* To delete users, set the value of `members__v` to `delete` followed by a comma-separated list of user IDs enclosed in parenthesis. For example `delete (userID1, userID2)` This only removes the specified users from the group.

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "label__v=Cholecap Team" \
-d "members__v=45501,45502,45503,45004" \
https://myvault.veevavault.com/api/v26.2/objects/groups/1358979070034
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseMessage": "Group successfully updated.",
  "id": 1358979070034
}
```
