<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-roles/retrieve-object-record-roles/ -->
<!-- title: Retrieve Object Record Roles -->

# Retrieve Object Record Roles

Retrieve manually assigned roles on an object record and the users and groups assigned to them.

GET`/api/{version}/vobjects/{object_name}/{id}/roles{/role_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object name. |
| `{id}` | The `id` of the document, binder, or object record. |
| `{/role_name}` | Optional: Include a role name to filter for a specific role. For example, `owner__v`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/campaign__c/OBE000000000412/roles
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "name": "approver__c",
            "users": [
                61583,
                61584,
                86488
            ],
            "groups": [
                3,
                1392631750101
            ],
            "assignment_type": "manual_assignment"
        }
      ]
    }
```

## Response Details

Even though the `owner__v` role is automatically assigned when you apply Custom Sharing Rules, the `assignment_type` for roles on objects is always `manual_assignment`.
