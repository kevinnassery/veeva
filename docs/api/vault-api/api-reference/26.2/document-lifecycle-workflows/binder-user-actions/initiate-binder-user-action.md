<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/binder-user-actions/initiate-binder-user-action/ -->
<!-- title: Initiate Binder User Action -->

# Initiate Binder User Action

Initiate a user action. Before initiating, you should retrieve any applicable [entry criteria](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-entry-criteria) for the action.

Only some user action types can be initiated through the API. See [supported user actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions).

The authenticated user must have permission to initiate this action. To check permissions, [Retrieve User Actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions) and check for actions where `executable__v` is `true`.

PUT`/api/{version}/objects/binders/{binder_id}/versions/{major_version}/{minor_version}/lifecycle_actions/{name__v}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{binder_id}` | The binder `id` field value on which to initiate the user action. |
| `{major_version}` | The major version number of the binder. |
| `{minor_version}` | The minor version number of the binder. |
| `{name__v}` | The action `name__v` field value to initiate. Retrieve this value from [Retrieve User Action](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions). |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d 'user_control_multiple__c=user%3A10001400&date_control__c=2019-10-31'\
https://myvault.veevavault.com/api/v26.2/objects/binders/17/versions/0/1/lifecycle_actions/start_approval__c
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "id": 17,
   "workflow_id__v": "401"
}
```
