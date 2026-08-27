<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/update-users/update-single-user/ -->
<!-- title: Update Single User -->

# Update Single User

Note

Beginning in v18.1, Admins create and manage users with `user__sys` object records. Unless you are updating domain-only users, we strongly recommend using the [Update Object Records](/vault-api/api-reference/26.2/vault-objects/update-object-records) endpoint to update users.

Update information for a single user. To update information for multiple users, see [Retrieve All Users](/vault-api/api-reference/26.2/users/retrieve-all-users).

PUT`/api/{version}/objects/users/{id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{id}` | The user `id` field value. Use the value `me` to update information for the currently authenticated user. |

## Body Parameters

In the body of the request, add any editable fields you wish to update. To remove existing field values, include the field name and set its value to null.

#### Example Request: Disable User at Domain-Level

Only Domain Admins may use this request.

When updating a user, `domain_active__v` can be (optionally) included in the input and set to either true or false to enable or disable the user at the domain-level. Disabling a user at the domain-level will disable the user in every Vault in your domain. Re-enabling a user enables them in the domain but does not re-activate them in their Vaults. After re-enabling a user, you must update their Vault membership to make them active in the individual Vaults.

This request will set the user (ID: 25001) profile to inactive in all Vaults in your domain. The user will still be a member in the Vaults and retain their license types and security profiles, but their user profile will be inactive and they will no longer have access to any Vaults in your domain.

#### Example Request: Re-Enable User at Domain-Level

Only Domain Admins may use this request.

This request will set the (previously inactive) user (ID: 25001) profile to active in your Vault domain. However, they will still be inactive in and unable to access your domain Vaults. Use the Update Vault Membership request to set their status to active in the individual Vaults in your domain.

#### Example Request: Promote a User to Domain Admin

Only Domain Admins may use this request.

This request will promote a user to Domain Admin. To remove a user from the Domain Admin role, set the `is_domain_admin__v` field to false. Each domain must have at least one user in the Domain Admin role.

#### Example Request: Update User Application Licensing

This request updates a user's licensing values for a specific application. As of 24R2, Vault enforces valid license values by application. When updating a user's application licensing values, Vault corrects any invalid application license values based on the user's initial `license_type__v`. For example, if a user's initial license type is `full__v` and their application license value for Veeva QMS is `read_only__v`, Vault updates the QMS application license value to `full__v`. If the user's initial license type is `read_only__v` and their license value for Veeva QMS is `read_only__v`, Vault clears the QMS license value because `read_only__v` is not a valid license value for QMS.

Some license values may be invalid depending on the application. The request fails if you provide an invalid license value for a specific application. Learn more about [valid license values by application in Vault Help](https://platform.veevavault.help/en/gr/5721#application-license).

## Request: Update User Profile Information

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "user_timezone__v=America/Los Angeles" \
-d "company__v=VeevaPharm" \
-d "user_title__v=Product Manager" \
-d "alias__v=Skipper" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001
```

## Request: Disable User at Domain-Level

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "domain_active__v=false" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001
```

## Request: Re-Enable User at Domain-Level

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "domain_active__v=true" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001
```

## Request: Promote a User to Domain Admin

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "is_domain_admin__v=true" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001
```

## Request: Update User Application Licensing

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "app_licensing=25001|qualityQms_v:true:full__v" \
https://myvault.veevavault.com/api/v26.2/objects/users/25001
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "id": 25001
}
```
