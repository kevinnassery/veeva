<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-binder-roles/document-roles/retrieve-document-role/ -->
<!-- title: Retrieve Document Role -->

# Retrieve Document Role

Retrieve a specific role on a document and the users and groups assigned to it.

GET`/api/{version}/objects/documents/{doc_id}/roles/{role_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{role_name}` | The name of the role to retrieve. For example, `owner__v`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/245/roles/reviewer__v
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Document role retrieved",
    "errorCodes": null,
    "documentRoles": [
        {
            "name": "reviewer__v",
            "label": "Reviewer",
            "assignedUsers": [
                25496,
                26231
            ],
            "assignedGroups": [
                1,
                2
            ],
            "availableUsers": [
                25496,
                26231,
                28874
            ],
            "availableGroups": [
                1,
                2,
                3
            ],
            "defaultUsers": [
                25496,
                26231
            ],
            "defaultGroups": [
                1,
                2
            ]
        }
    ],
    "errorType": null
}
```

## Response Details

On `SUCCESS`, the response lists the following for the specific role retrieved:

| Name | Description |
| --- | --- |
| `name` | The role name available to developers. For example, `reviewer__v`. |
| `label` | The UI-friendly role label available to Admins in the Vault UI. For example, `Reviewer`. |
| `assignedUsers` | List of the IDs of users assigned to this role |
| `assignedGroups` | List of the IDs of groups assigned to this role |
| `availableUsers` | List of the IDs of users available for this role |
| `availableGroups` | List of the IDs of groups available to this role |
| `defaultUsers` | List of the IDs of default users assigned to this role |
| `defaultGroups` | List of the IDs of default groups assigned to this role |
