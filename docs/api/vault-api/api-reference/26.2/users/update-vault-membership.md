<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/update-vault-membership/ -->
<!-- title: Update Vault Membership -->

# Update Vault Membership

Use this request to:

* Assign an existing user to a Vault in your domain.
* Remove (disable) an existing user from a Vault in your domain.
* Update the security profile and license type of an existing user.

You cannot use this request to:

* Create a new user. See [Create Object Records](/vault-api/api-reference/26.2/vault-objects/create-upsert-object-records).
* Update other user profile information. See [Update Object Records](/vault-api/api-reference/26.2/vault-objects/update-object-records).

Additional information:

* For a list of user fields and properties, see [Retrieve Users](/vault-api/api-reference/26.2/users/retrieve-all-users).
* Learn about [Creating & Managing Users](https://platform.veevavault.help/en/gr/953) and [Managing Users Across Vaults](https://platform.veevavault.help/en/gr/15127) in Vault Help.

#### Permissions

System Admins and Vault Owners can update users in the Vaults where they have administrative access. System Admins who are also Domain Admins have an unrestricted access to users across all Vaults in the domain.

PUT`/api/{version}/objects/users/{user_id}/vault_membership/{vault_id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{user_id}` | The user `id` field value. See [Retrieve All Users](/vault-api/api-reference/26.2/users/retrieve-all-users). |
| `{vault_id}` | The system-managed `id` field value assigned to each Vault in the domain. |

## Body Parameters

| Name | Description |
| --- | --- |
| `active__v` optional | Set the user status to active (`true`) or inactive (`false`). If omitted, this value defaults to `active__v`. |
| `security_profile__v` optional | Assigns the user a specific security profile in the Vault. If omitted, defaults to `document_user__v`. |
| `license_type__v` optional | Assigns the user a specific license type in the Vault. If omitted, defaults to `full__v`. |

See the example requests below for additional information about using these input values.

#### Request Details: Add User to a Vault

This request will assign the user (ID: 25001) to the Vault (ID: 3003). There are a few default settings that will be applied here:

The user's status will be set to active in the Vault. This is the default setting; the `active__v=true` parameter ca be omitted and produce the same results. We've not included the optional `security_profile__v` and `license_type__v` in the input. Therefore, the user will be assigned a `full__v` license type and `document_user__v` security profile by default.

#### Request Details: Disable User in a Vault

This request will set the user (ID: 25001) profile to inactive in the Vault (ID: 3003). They will still be a member in the Vault and retain their license type and security profile, but their user profile will be inactive and they will no longer have access to the Vault.

#### Request Details: Set Security Profile & License Type

This request will set the user (ID: 25001) security profile and license type to specific values in the Vault (ID: 3003). If the user is already a member of the Vault, this will change their security profile and license type. If the user is not a member of the Vault, this will assign them to the Vault, set their status to active, and their security profile and license type to the specified values.

## Request: Add User to a Vault

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "active__v=true" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001/vault_membership/3003
```

## Request: Disable User in a Vault

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "active__v=false" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001/vault_membership/3003
```

## Request: Set Security Profile & License Type

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "security_profile__v=business_admin__v" \
-d "license_type__v=full__v"
https://myvault.veevavault.com/api/v26.2/objects/users/25001/vault_membership/3003
```
