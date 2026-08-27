<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/retrieve-user-permissions/ -->
<!-- title: Retrieve User Permissions -->

# Retrieve User Permissions

Retrieve all object and object field permissions (*Read*, *Edit*, *Create*, *Delete*) assigned to a specific user.

GET`/api/{version}/objects/users/{id}/permissions`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{id}` | The ID of the user. Use the value `me` to retrieve information for the currently authenticated user. |

## Query Parameters

| Name | Description |
| --- | --- |
| `filter=name__v::{permission_name}` | Filter the results to show only one `specific name__v`, which is in the format `object.{object name}.{object` or `field}_actions`. Wildcards are not supported. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users/61579/permissions?filter=name__v::object.product__v.object_actions
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "data": [
    {
      "name__v": "object.product__v.object_actions",
      "permissions": {
        "read": true,
        "edit": true,
        "create": false,
        "delete": false
      }
    }
  ]
}
```
