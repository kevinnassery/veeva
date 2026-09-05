<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/groups/create-group/ -->
<!-- title: Create Group -->

# Create Group

POST`/api/{version}/objects/groups`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

| Name | Description |
| --- | --- |
| `label__v` required | Enter a group label. Vault uses this to create the group `name__v` value. |
| `members__v` optional | Add a comma-separated list of user IDs. This manually assigns individual users to the group. |
| `security_profiles__v` optional | Add a comma-separated list of security profiles. This automatically adds all users with the security profile to the group. These are `implied_members__v`. |
| `active__v` optional | By default, the new group will be created as active. To set the group to inactive, set this value to `false` |
| `group_description__v` optional | Add a description of the group. |
| `allow_delegation_among_members__v` optional | When set to `true`, members of this group will only be allowed to delegate access to other members of the same group. You can set this field for user and system managed groups. If omitted, defaults to `false`. Learn more about [Delegate Access](https://platform.veevavault.help/en/gr/15015). |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "label__v=Cholecap Team US Compliance" \
-d "members__v=45501,45002" \
-d "security_profiles__v=document_user__v"
https://myvault.veevavault.com/api/v26.2/objects/groups
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseMessage": "Group successfully created.",
  "id": 1358979070034
}
```
