<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-document-user-action/ -->
<!-- title: Initiate Document User Action -->

# Initiate Document User Action

Initiate a user action. Before initiating, you should retrieve any applicable [entry criteria](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-entry-criteria) for the action.

Only some user action types can be initiated through the API. See [supported user actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions).

The authenticated user must have permission to initiate this action. To check permissions, [Retrieve User Actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions) and check for actions where `executable__v` is `true`.

PUT`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/lifecycle_actions/{name__v}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value on which to initiate the user action. |
| `{major_version}` | The major version number of the document. |
| `{minor_version}` | The minor version number of the document. |
| `{name__v}` | The action `name__v` field value to initiate. Retrieve this value from [Retrieve User Action](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions). |

#### Request Details: Start Legacy Workflow

This request is initiating a `start_approval__c` workflow. [Retrieving the entry criteria](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-entry-criteria) told us what fields we need to add to initiate this action, and that the `scope` is `WorkflowActivation`. This scope means we can add the required entry criteria fields as name-value pairs in the body of this request.

* `user_control_multiple__c=user%3A10001400` is an `ObjectReference` to a `User`.
* `date_control__c=2019-10-31` is a `Date`.

#### Request Details: Change State

This request is initiating the `approve__c` user action, which changes the state of the document to *Approved*. [Retrieving the entry criteria](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-entry-criteria) told us what fields we need to add or update to initiate this action, and that the `scope` is `Document`. This scope means the required entry criteria must be set on the document prior to this request, so there are no additional parameters to add to this initiate request.

## Request: Start Legacy Workflow

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d 'user_control_multiple__c=user%3A10001400&date_control__c=2019-10-31'\
https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/lifecycle_actions/start_approval__c
```

## Response: Start Legacy Workflow

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "id": 17,
   "workflow_id__v": "401"
}
```

## Request: Change State

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/lifecycle_actions/approve__vs
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "id": 17
}
```
