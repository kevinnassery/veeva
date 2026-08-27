<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/lifecycle-role-assignment-rules/delete-lifecycle-role-assignment-override-rules/ -->
<!-- title: Delete Lifecycle Role Assignment Override Rules -->

# Delete Lifecycle Role Assignment Override Rules

Delete override rules configured on a specific lifecycle role.

DELETE`/api/{version}/configuration/role_assignment_rule`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` or `text/csv` |

## Query Parameters

| Name | Description |
| --- | --- |
| `lifecycle__v` | Include the name of the lifecycle from which to delete override rules. For example, `lifecycle__v=general_lifecycle__c`. |
| `role__v` | Include the name of the role from which to delete override rules. For example, `role__v=editor__c`. |
| `{object_name}` | Optional: To delete overrides on a specific object by ID, include the object ID. For example, `product__v=0PR0011001`. |
| `{object_name}.name__v` | Optional: To delete overrides on a specific object by name, include the object name. For example, `product__v.name__v=CholeCap`. |

## Request: Delete All Overrides

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/configuration/role_assignment_rule?lifecycle__v=general_lifecycle__c&role__v=editor__c
```

## Response: Delete All Overrides

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "data": {
    "rules_deleted": 2
  }
}
```

## Request: Delete Object-Specific Override

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/configuration/role_assignment_rule?lifecycle__v=general_lifecycle__c&role__v=editor__c&product__v.name__v=CholeCap
```

## Response: Delete Object-Specific Override

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "data": {
    "rules_deleted": 1
  }
}
```

## Response Details

On `SUCCESS`, the example response displays the number of override rules that were deleted from the lifecycle role.
