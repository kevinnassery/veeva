<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/create-users/create-single-user/ -->
<!-- title: Create Single User -->

# Create Single User

Note

Beginning in v18.1, Admins create and manage users with `user__sys` object records. Unless you are adding cross-domain or VeevaID users or adding users to a domain without assigning Vault membership, we strongly recommend using the [Create Object Records](/vault-api/api-reference/26.2/vault-objects/create-upsert-object-records) endpoint to create new users.

Create one user at a time without the need for a CSV input file. After creation, you can assign these users to Vaults with the [Update Vault Membership](/vault-api/api-reference/26.2/users/update-vault-membership) endpoint.

Some Vaults use multiple applications, for example, a RIM Vault with Submissions and Registrations. If your Vault utilizes user-based licensing, you must use the [Create Multiple Users](/vault-api/api-reference/26.2/users/create-users/create-multiple-users) endpoint with the `app_licensing` field. After creation, you can also manually adjust the user’s application licenses through the Vault UI. Learn more about [license types](https://platform.veevavault.help/en/gr/5721#license-types) and [application licenses in Vault Help](https://platform.veevavault.help/en/gr/5721#application-licensing).

POST`/api/{version}/objects/users`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

The following table provides the required and most common optional parameters to create a user. You may add values to any other editable user field, unless you are adding a [cross-domain](/vault-api/api-reference/26.2/users/create-users/create-multiple-users/#Cross_Domain_Users) user or [VeevaID](/vault-api/api-reference/26.2/users/create-users/create-multiple-users/#VeevaID) user. See [Retrieve All Users](/vault-api/api-reference/26.2/users/retrieve-all-users) for all possible values.

| Name | Description |
| --- | --- |
| `user_name__v` required | The user’s Vault username (login credential). For example, `ewoodhouse@veepharm.com` |
| `user_first_name__v` required | The user's first name. |
| `user_last_name__v` required | The user's last name. |
| `user_email__v` required | The user's email address. |
| `user_timezone__v` required | The user's time zone. Retrieve values from [Retrieve All Users](/vault-api/api-reference/26.2/users/retrieve-all-users). |
| `user_locale__v` required | The user's location. Retrieve values from [Retrieve All Users](/vault-api/api-reference/26.2/users/retrieve-all-users). |
| `security_policy_id__v` required | The user's security policy. Retrieve values from [Retrieve All Security Policies](/vault-api/api-reference/26.2/security-policies/retrieve-all-security-policies). |
| `user_language__v` required | The user's preferred language. Retrieve values from [Retrieve All Users](/vault-api/api-reference/26.2/users/retrieve-all-users). |
| `security_profile__v` optional | The user’s security profile. If omitted, the default value is `document_user__v`. |
| `license_type__v` optional | The license type is the first level of access control that Vault applies to a user. If your Vault utilizes user-based licensing, assign application licensing using the [Create Multiple Users](/vault-api/api-reference/26.2/users/create-users/create-multiple-users) endpoint. The `license_type__v` cannot be less permissive than a user's application licensing. If omitted, the default value is `full__v`. |

## Cross-Domain Users

The following are the only fields required to create a cross-domain user. All other fields are ignored.

| Name | Description |
| --- | --- |
| `user_name__v` required | The user’s Vault username (login credential). For example, `ewoodhouse@veepharm.com` |
| `security_profile__v` optional | The user’s security profile. If omitted, the default value is `document_user__v`. |
| `license_type__v` optional | The user’s license type. If omitted, the default value is `full__v`. If your Vault utilizes user-based licensing, assign application licensing using the [Create Multiple Users](/vault-api/api-reference/26.2/users/create-users/create-multiple-users) endpoint. |

## VeevaID Users

The following are the only fields required to add an existing VeevaID user to Vault. All other fields are ignored.

| Name | Description |
| --- | --- |
| `user_name__v` required | The user’s Vault username (login credential). For example, `ewoodhouse@veepharm.com` |
| `security_policy_id__v` required | The `name__v` of your Vault’s VeevaID security policy, for example, `25285`. You can retrieve this ID from the [Retrieve All Security Policies](/vault-api/api-reference/26.2/security-policies/retrieve-all-security-policies) endpoint. |
| `security_profile__v` optional | The user’s security profile. If omitted, the default value is `document_user__v`. |
| `license_type__v` optional | The user’s license type. If omitted, the default value is `full__v`. If your Vault utilizes user-based licensing, assign application licensing using the [Create Multiple Users](/vault-api/api-reference/26.2/users/create-users/create-multiple-users) endpoint. |

### Query Parameters

| Name | Description |
| --- | --- |
| `domain` | When set to `true`, the user will not be assigned to a Vault. |

## Add User to Domain

On `SUCCESS`, the user account is created and set to active. The new user is not assigned a license type or security profile, nor do they have access to any Vaults in your domain. This means they will not receive a welcome email.

### Request: Add User to Domain

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "user_name__v=ewoodhouse@veepharm.com" \
-F "user_email__v=ewoodhouse@veepharm.com" \
-F "user_first_name__v=Elaine" \
-F "user_last_name__v=Woodhouse" \
-F "user_language__v=en" \
-F "user_timezone__v=America/Denver" \
-F "user_locale__v=en_US" \
-F "security_policy_id__v=821" \
-F "domain=true" \
https://myvault.veevavault.com/api/v26.2/objects/users
```

## Add User to Current Vault

This request adds one new user to your domain and assigns them to the Vault where the request was made. They will receive a welcome email with instructions for logging into the Vault, and they will not have access to any other Vaults in your domain. To give them access to other Vaults, see [Update Vault Membership](/vault-api/api-reference/26.2/users/update-vault-membership).

This example request includes all fields required to create a new user, and two optional fields (security profile and license type). If these optional fields were not included in the request, the user would be assigned the `document_user__v` security profile and `full__v` license type by default.

### Request: Add User to Current Vault

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "user_name__v=ewoodhouse@veepharm.com" \
-F "user_email__v=ewoodhouse@veepharm.com" \
-F "user_first_name__v=Elaine" \
-F "user_last_name__v=Woodhouse" \
-F "user_language__v=en" \
-F "user_timezone__v=America/Denver" \
-F "user_locale__v=en_US" \
-F "security_policy_id__v=821" \
-F "security_profile__v=business_admin__v" \
-F "license_type__v=full__v" \
https://myvault.veevavault.com/api/v26.2/objects/users
```

## Add Cross-Domain User

This request adds the user `ewoodhouse.veevavault.com` to your current domain as a cross-domain user.

All other metadata fields are ignored. Learn more about [cross-domain users in Vault Help](https://platform.veevavault.help/en/gr/38996).

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "user_name__v=ewoodhouse@veepharm.com" \
-F "security_profile__v=business_admin__v" \
-F "license_type__v=full__v" \
https://myvault.veevavault.com/api/v26.2/objects/users
```
