<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-binder-roles/document-roles/remove-users-groups-from-roles-on-a-single-document/ -->
<!-- title: Remove Users & Groups from Roles on a Single Document -->

# Remove Users & Groups from Roles on a Single Document

Note

If you need to remove users and groups from roles on more than one document, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/document-binder-roles/document-roles/remove-users-groups-from-roles-on-multiple-documents-binders).

Remove users and groups from roles on a single document.

DELETE`/api/{version}/objects/documents/{doc_id}/roles/{role_name_and_user_or_group}/{id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The `id` value of the document from which to remove roles. |
| `{role_name_and_user_or_group}` | The name of the role from which to remove the user or group followed by either `user` or `group`. The format is `{role_name}.{user_or_group}`. For example, `consumer__v.user`. |
| `{id}` | The `id` value of the user or group to remove from the role. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/1234/roles/consumer__v.user/1008313
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseMessage": "User/group deleted from document role",
  "updatedRoles": {
    "consumer__v": {
      "users": [
        1008313
      ]
    }
  }
}
```

## Response Details

On `SUCCESS`, the response lists the `id` of the user or group removed from the document role. On `FAILURE`, the response returns an error message describing the reason for the failure. For example, a user or group may not be removed if the role assignment is system-managed.
