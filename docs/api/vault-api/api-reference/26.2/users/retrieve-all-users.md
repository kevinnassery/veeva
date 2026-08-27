<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/retrieve-all-users/ -->
<!-- title: Retrieve All Users -->

# Retrieve All Users

Note

This endpoint retrieves user records at the domain level. Beginning in v18.1, Admins create and manage users with `user__sys` object records. We strongly recommend using [VQL or Direct Data API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) to retrieve `user__sys` records.

GET`/api/{version}/objects/users`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

Using the endpoint alone with no optional parameters will retrieve users assigned only to the Vault in which the request is made. For customers with multiple Vaults in their domain, users with Domain Admin, System Admin, and Vault Owner privileges can access user information across different Vaults in the domain by including the optional parameter `vaults` set to one of the following values:

| Name | Description |
| --- | --- |
| `vaults=all` | Retrieve all users assigned to all Vaults in your domain. |
| `vaults=-1` | Retrieve all users assigned to all Vaults in your domain except for the Vault in which the request is made. |
| `vaults={Vault IDs}` | To retrieve users assigned only to specific Vaults, enter a comma-separated list of Vault IDs. For example, `3003,4004,5005`. |
| `exclude_vault_membership` | Optional: Set to `false` to include `vault_membership` fields. If `true` or omitted, `vault_membership` fields are not included in the response. |
| `exclude_app_licensing` | Optional: Set to `false` to include `app_licensing` fields. If `true` or omitted, `app_licensing` fields are not included in the response. |

System Admins and Vault Owners must have administrative access to Vault applications referenced in the `vaults` parameter to be able to access users from those Vault.

The response also supports pagination. By default the page limit is set to 200 records. The pagination parameters are:

| Name | Description |
| --- | --- |
| `limit` | [optional, default is 200] the size of the result set in the page |
| `start` | [optional, default is 0] the starting record number |
| `sort` | [optional, default is "id asc"] the sort order for the result set (`asc` - ascending, `desc` - descending) (e.g. `user_name__v asc`) |

#### Vault-Owned Users

When you retrieve legacy users, the response includes multiple system-owned user records that appear in all Vaults. These accounts are used to capture actions that are performed by Vault instead of by a user. These records are not included in license counts, are read-only, and cannot be referenced by another user or document. Learn more in [Vault Help](https://platform.veevavault.help/en/gr/953#System_Owned_Users).

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users
```

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users?vaults=all
```

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users?vaults=-1
```

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users?vaults=3003,4004,5005
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "size": 200,
    "start": 0,
    "limit": 200,
    "sort": "id asc",
    "users": [
        {
            "user": {
                "id": 25501,
                "user_name__v": "ewoodhouse@veepharm.com",
                "user_first_name__v": "Elaine",
                "user_last_name__v": "Woodhouse"
              }
        },
        {
            "user": {
                "id": 25502,
                "user_name__v": "bashton@veepharm.com",
                "user_first_name__v": "Bruce",
                "user_last_name__v": "Ashton"
              }
        },
        {
            "user": {
                "id": 25503,
                "user_name__v": "tchung@veepharm.com",
                "user_first_name__v": "Thomas",
                "user_last_name__v": "Chung"
              }
        }
      ]
    }
```
