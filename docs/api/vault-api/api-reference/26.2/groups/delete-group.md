<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/groups/delete-group/ -->
<!-- title: Delete Group -->

# Delete Group

Delete a user-defined group. You cannot delete system-managed groups.

DELETE`/api/{version}/objects/groups/{group_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{group_id}` | The group `id` field value. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/groups/1358979070034
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "id": 1358979070034
}
```
