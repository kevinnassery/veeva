<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/binder-user-actions/retrieve-binder-user-actions/ -->
<!-- title: Retrieve Binder User Actions -->

# Retrieve Binder User Actions

Retrieve all available user actions on a specific version of a binder which:

* The authenticated user has permission to view or initiate.
* Can be initiated through the API. See [supported user actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions).
* Is not currently in an active workflow.

GET`/api/{version}/objects/binders/{binder_id}/versions/{major_version}/{minor_version}/lifecycle_actions`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{binder_id}` | The `id` field value of the binder from which to retrieve available user actions. |
| `{major_version}` | The major version number of the binder. |
| `{minor_version}` | The minor version number of the binder. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/binders/17/versions/0/1/lifecycle_actions
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Success",
    "lifecycle_actions__v": [
        {
            "name__v": "request_content__c",
            "label__v": "Send to Content Creator",
            "lifecycle_action_type__v": "workflow",
            "lifecycle__v": "job_processing__c",
            "state__v": "draft__c",
            "executable__v": true,
            "entry_requirements__v": "https://myvault.veevavault.com/api/v26.2/objects/binders/152/versions/0/1/lifecycle_actions/request_content__c/entry_requirements"
        },
        {
            "name__v": "submit_for_review__c",
            "label__v": "Submit for Review",
            "lifecycle_action_type__v": "workflow",
            "lifecycle__v": "job_processing__c",
            "state__v": "draft__c",
            "executable__v": true,
            "entry_requirements__v": "https://myvault.veevavault.com/api/v26.2/objects/binders/152/versions/0/1/lifecycle_actions/submit_for_review__c/entry_requirements"
        },
        {
            "name__v": "review_annotate__c",
            "label__v": "Review & Annotate",
            "lifecycle_action_type__v": "workflow",
            "lifecycle__v": "job_processing__c",
            "state__v": "draft__c",
            "executable__v": true,
            "entry_requirements__v": "https://myvault.veevavault.com/api/v26.2/objects/binders/152/versions/0/1/lifecycle_actions/review_annotate__c/entry_requirements"
        }
    ]
}
```

## Response Details

The response lists all available user actions (`lifecycle_actions__v`) that can be initiated on the specified version of the binder.

| Name | Description |
| --- | --- |
| `name__v` | The user action name (consumed by the API). These vary from Vault to Vault and may be text, numeric, or alphanumeric values. |
| `label__v` | The user action label displayed to users in the UI. |
| `lifecycle_action_type__v` | The `workflow` (legacy) and `stateChange` types are the most commonly used and are available in all Vaults. Others may exist. |
| `lifecycle__v` | The binder lifecycle the action belongs to. For example, `general_lifecycle__c`. |
| `state__v` | The state of the binder. |
| `executable__v` | Indicates if the currently authenticated user has *Execute* permission for this action. This is `true` if the user can execute the action, otherwise `false`. |
| `entry_requirements__v` | The endpoint to retrieve the entry requirements for each user action. If no entry criteria exist, this endpoint returns an empty list. If the authenticated user does not have permission to execute this action, `entry_requirements__v` does not appear in the response. |
