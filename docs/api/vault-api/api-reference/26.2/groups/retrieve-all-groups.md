<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/groups/retrieve-all-groups/ -->
<!-- title: Retrieve All Groups -->

# Retrieve All Groups

Retrieve all groups except Auto Managed groups. You can retrieve Auto Managed groups using the [Retrieve Auto Managed Groups](/vault-api/api-reference/26.2/groups/retrieve-auto-managed-groups) endpoint.

GET`/api/{version}/objects/groups`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `includeImplied` | Optional: When `true`, the response includes the `implied_members__v` field. These users are automatically added to the group when their `security_profiles__v` are added to the group. If omitted, the response includes only the `members__v` field. These users are individually added to a group by an Admin. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/groups
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "groups": [
    {
      "group": {
        "members__v": [
          25496,
          25513,
          25514,
          25515,
          25519,
          25524,
          25525,
          25526,
          25527,
          25528,
          25532
        ],
        "active__v": true,
        "security_profiles__v": [
          "document_user__v",
          "business_admin__v",
          "system_admin__v",
          "vault_owner__v"
        ],
        "name__v": "all_internal_users__v",
        "modified_by__v": 25524,
        "editable__v": true,
        "allow_delegation_among_members__v": true,
        "modified_date__v": "2016-03-08T21:13:49.000Z",
        "group_description__v": "All Internal Vault Users (System Provided Group)",
        "system_group__v": true,
        "label__v": "All Internal Users",
        "created_date__v": "2014-02-17T10:09:03.000Z",
        "type__v": "System Provided Group",
        "id": 1,
        "created_by__v": 1
      }
    }
  ]
}
```
