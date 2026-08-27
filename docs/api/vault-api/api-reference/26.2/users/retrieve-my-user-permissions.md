<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/retrieve-my-user-permissions/ -->
<!-- title: Retrieve My User Permissions -->

# Retrieve My User Permissions

Retrieve all object and object field permissions (*Read*, *Edit*, *Create*, *Delete*) assigned to the currently authenticated user.

GET`/api/{version}/objects/users/me/permissions`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `filter=name__v::{permission_name}` | Filter the results to show only one `specific name__v`, which is in the format `object.{object name}.{object` or `field}_actions`. Wildcards are not supported. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users/me/permissions?filter=name__v::object.user__sys.object_actions
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "name__v": "object.user__sys.object_actions",
            "permissions": {
                "read": true,
                "edit": true,
                "create": true,
                "delete": false
            }
        }
    ]
}
```
