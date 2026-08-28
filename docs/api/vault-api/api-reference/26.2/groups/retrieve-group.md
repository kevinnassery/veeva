<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/groups/retrieve-group/ -->
<!-- title: Retrieve Group -->

# Retrieve Group

GET`/api/{version}/objects/groups/{group_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{group_id}` | The group `id` field value. |

## Query Parameters

| Name | Description |
| --- | --- |
| `includeImplied` | When `true`, the response includes the `implied_members__v` field. These users are automatically added to the group when their `security_profiles__v` are added to the group. When not used, the response includes only the `members__v` field. These users are individually added to a group by Admin. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/groups/1435176677013
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
          25518,
          25519,
          25520
        ],
        "active__v": true,
        "security_profiles__v": [],
        "name__v": "cholecap_editors_group__c",
        "modified_by__v": 46916,
        "editable__v": true,
        "allow_delegation_among_members__v": true,
        "modified_date__v": "2015-06-24T20:11:17.000Z",
        "group_description__v": null,
        "system_group__v": false,
        "label__v": "Cholecap Editors Group",
        "created_date__v": "2015-06-24T20:11:17.000Z",
        "type__v": "User Managed Group",
        "id": 1435176677013,
        "created_by__v": 46916
      }
    }
  ]
}
```
