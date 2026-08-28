<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-binder-roles/document-roles/assign-users-groups-to-roles-on-a-single-document/ -->
<!-- title: Assign Users & Groups to Roles on a Single Document -->

# Assign Users & Groups to Roles on a Single Document

Note

If you need to assign users and groups to roles on more than one document, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/document-binder-roles/document-roles/assign-users-groups-to-roles-on-multiple-documents-binders).

Assign users and groups to roles on a single document.

POST`/api/{version}/objects/documents/{doc_id}/roles`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Body Parameters

| Name | Description |
| --- | --- |
| `{role__v}.users` optional | A string of comma-separated user id values for the new role. For example, `reviewer__v.users = "3003, 4005"`. |
| `{role__v}.groups` optional | A string of comma-separated group id values for the new group. For example, `reviewer__v.groups = "20, 21"`. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "consumer__v.users=35565,35571" \
-d "approver__v.users-45585,45594" \
https://myvault.veevavault.com/api/v26.2/objects/documents/245/roles
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseMessage": "Document roles updated",
  "updatedRoles": {
    "consumer__v": {
      "users": [
        19376,18234,19456
      ]
    },
    "legal__c": {
      "groups": [
        19365,18923
      ]
    }
  }
}
```

## Response Details

The response includes IDs of the users and groups successfully assigned to each role on the document.
