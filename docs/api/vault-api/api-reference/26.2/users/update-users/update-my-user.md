<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/update-users/update-my-user/ -->
<!-- title: Update My User -->

# Update My User

Update information for the currently authenticated user.

PUT`/api/{version}/objects/users/me`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

In the body of the request, add any editable fields you wish to update. To remove existing field values, include the field name and set its value to null.

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "user_title__v=Technical Writer" \
-d "site__v": "San Francisco",
https://myvault.veevavault.com/api/v26.2/objects/users/me
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "id": 61579
}
```

## Response Details

On `SUCCESS`, the specified values are updated and the request returns the `id` of the currently authenticated user.
