<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions/ -->
<!-- title: Retrieve Document User Actions -->

# Retrieve Document User Actions

Retrieve all available user actions on a specific version of a document which:

* The authenticated user has permission to view or initiate.
* Can be initiated through the API. See [supported user actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions).
* Is not currently in an active workflow.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/lifecycle_actions`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value from which to retrieve available user actions. |
| `{major_version}` | The major version number of the document. |
| `{minor_version}` | The minor version number of the document. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/lifecycle_actions
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseMessage": "Success",
   "lifecycle_actions__v": [
       {
           "name__v": "start_review__c",
           "label__v": "Start Review",
           "lifecycle_action_type__v": "workflow",
           "lifecycle__v": "general_lifecycle__c",
           "state__v": "draft__c",
           "executable__v": "false"
       },
       {
           "name__v": "start_approval__c",
           "label__v": "Start Approval",
           "lifecycle_action_type__v": "workflow",
           "lifecycle__v": "general_lifecycle__c",
           "state__v": "draft__c",
           "executable__v": "true",
           "entry_requirements__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/lifecycle_actions/start_approval__c/entry_requirements"
       },
       {
           "name__v": "approve__c",
           "label__v": "Approve",
           "lifecycle_action_type__v": "stateChange",
           "lifecycle__v": "general_lifecycle__c",
           "state__v": "draft__c",
           "executable__v": "true",
           "entry_requirements__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/lifecycle_actions/approve__c/entry_requirements"
       }
   ]
}
```

## Response Details

The response lists all available user actions (`lifecycle_actions__v`) that can be initiated on the specified version of the document.

| Name | Description |
| --- | --- |
| `name__v` | The user action name (consumed by the API). These vary from Vault to Vault and may be text, numeric, or alphanumeric values. |
| `label__v` | The user action label displayed to users in the UI. |
| `lifecycle_action_type__v` | The `workflow` (legacy) and `stateChange` types are the most commonly used and are available in all Vaults. Others may exist. |
| `lifecycle__v` | The document lifecycle the action belongs to. For example, `general_lifecycle__c`. |
| `state__v` | The state of the document. |
| `executable__v` | Indicates if the currently authenticated user has *Execute* permission for this action. This is `true` if the user can execute the action, otherwise `false`. |
| `entry_requirements__v` | The endpoint to retrieve the entry requirements for each user action. If no entry criteria exist, this endpoint returns an empty list. If the authenticated user does not have permission to execute this action, `entry_requirements__v` does not appear in the response. |
