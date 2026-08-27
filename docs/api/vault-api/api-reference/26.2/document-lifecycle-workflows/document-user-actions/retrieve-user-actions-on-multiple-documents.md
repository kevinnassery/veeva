<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-user-actions-on-multiple-documents/ -->
<!-- title: Retrieve User Actions on Multiple Documents -->

# Retrieve User Actions on Multiple Documents

Retrieve all available user actions on specific versions of multiple documents.

POST`/api/{version}/objects/documents/lifecycle_actions`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

| Name | Description |
| --- | --- |
| `docIds` required | The `id` and version numbers for each document for which to retrieve the available user actions. Include a comma-separated list of document IDs and major and minor version numbers in the format `{doc_id:major_version:minor_version}`. For example, `22:0:1`. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "docIds=22:0:1,21:1:0,20:1:0" \
https://myvault.veevavault.com/api/v26.2/objects/documents/lifecycle_actions
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Success",
    "lifecycle_actions__v": [
        {
            "name__v": "make_obsolete__c",
            "label__v": "Make Obsolete",
            "lifecycle_action_type__v": "stateChange",
            "lifecycle__v": "general_lifecycle__c",
            "state__v": "approved__c",
            "entry_requirements__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/lifecycle_actions/make_obsolete__c/entry_requirements?lifecycle=general_lifecycle__c&state=approved__c"
        },
        {
            "name__v": "approve__c",
            "label__v": "Approve",
            "lifecycle_action_type__v": "stateChange",
            "lifecycle__v": "general_lifecycle__c",
            "state__v": "draft__c",
            "entry_requirements__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/lifecycle_actions/approve__c/entry_requirements?lifecycle=general_lifecycle__c&state=draft__c"
        }
    ]
}
```

## Response Details

The response lists all available lifecycle actions (`lifecycle_actions__v`) that can be initiated on the specified versions of multiple documents.

| Name | Description |
| --- | --- |
| `name__v` | The lifecycle action name (consumed by the API). These vary from Vault to Vault and may be text, numeric, or alphanumeric values. |
| `label__v` | The lifecycle action label. This is the "User Action" label seen in the UI. |
| `lifecycle_action_type__v` | The `workflow` (legacy) and `stateChange` types are the most commonly used and are available in all Vaults. Others may exist. |
| `lifecycle__v` | The document lifecycle the action belongs to. For example, `general_lifecycle__c`. |
| `state__v` | The state of the document. |
| `entry_requirements__v` | The endpoint to retrieve the entry requirements for each lifecycle action. If no entry requirements exist, the endpoint returns an empty list. |

Lifecycle actions are not returned for documents which are currently in an active workflow.
