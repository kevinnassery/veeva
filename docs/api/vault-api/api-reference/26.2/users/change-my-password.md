<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/change-my-password/ -->
<!-- title: Change My Password -->

# Change My Password

Change the password for the currently authenticated user.

POST`/api/{version}/objects/users/me/password`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

| Name | Description |
| --- | --- |
| `password__v` required | Enter your current password. |
| `new_password__v` required | Enter your desired new password. Must be a different value than `password__v`. |

Passwords must meet minimum requirements, which are configured by your Vault Admin. Learn about [Configuring Password Requirements](https://platform.veevavault.help/en/gr/1985) in Vault Help.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "password__v=CurrentPassword" \
-d "new_password__v=NewPassword" \
https://myvault.veevavault.com/api/v26.2/objects/users/me/password
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```

## Response Details

On `SUCCESS`, your password is changed.
