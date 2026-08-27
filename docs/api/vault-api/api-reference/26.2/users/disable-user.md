<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/disable-user/ -->
<!-- title: Disable User -->

# Disable User

Disable a user in a specific Vault or disable a user in all Vaults in the domain.

Note

This endpoint disables users at the domain level. Beginning in v18.1, Admins create and manage users with `user__sys` object records. To disable users in an individual Vault, use the single or bulk [Initiate Object Action](/vault-api/api-reference/26.2/object-lifecycle-workflows/object-record-user-actions/initiate-object-action-on-a-single-record) endpoint to initiate the *Make User Inactive* action on the desired records.

#### Permissions

System Admins and Vault Owners can update users in the Vaults where they have administrative access. System Admins who are also Domain Admins have an unrestricted access to users across all Vaults in the domain.

DELETE`/api/{version}/objects/users/{user_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{user_id}` | The user `id` field value. See [Retrieve All Users](/vault-api/api-reference/26.2/users/retrieve-all-users). |

## Query Parameters

| Name | Description |
| --- | --- |
| `domain` | When `true`, this disables the user account in all Vaults in the domain. |

#### Request: Disable User in a Vault

This request will set the user (ID: 25001) profile to inactive in the Vault in which the request is made. The user will still be a member in the Vault and retain their license type and security profile, but their user profile will be inactive and they will no longer have access to the Vault.

#### Request: Disable User in All Domain Vaults

This request will set the user (ID: 25001) profile to inactive in all Vaults in your domain. The user will still be a member in the Vaults and retain their license types and security profiles, but their user profile will be inactive and they will no longer have access to any Vaults in your domain.

## Request: Disable User in a Vault

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001
```

## Request: Disable User in All Domain Vaults

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001?domain=true
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "id": 25001
}
```
