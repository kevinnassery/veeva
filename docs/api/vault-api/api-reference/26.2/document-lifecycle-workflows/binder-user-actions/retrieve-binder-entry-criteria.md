<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/binder-user-actions/retrieve-binder-entry-criteria/ -->
<!-- title: Retrieve Binder Entry Criteria -->

# Retrieve Binder Entry Criteria

Retrieve the entry criteria for a user action. Entry criteria are requirements the binder must meet before you can [initiate the action](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-document-user-action). Entry criteria are dynamic and depend on the lifecycle configuration, lifecycle state, or any workflow activation requirements defined in the *Start Step* of the workflow. Learn more about [entry criteria in Vault Help](https://platform.veevavault.help/en/gr/12617#types).

To retrieve entry criteria, the authenticated user must have permission to execute the action. To check permissions, [Retrieve User Actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions) and check for actions where `executable__v` is `true`.

GET`/api/{version}/objects/binders/{binder_id}/versions/{major_version}/{minor_version}/lifecycle_actions/{name__v}/entry_requirements`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{binder_id}` | The binder `id` field value from which to retrieve available user actions. |
| `{major_version}` | The major version number of the binder. |
| `{minor_version}` | The minor version number of the binder. |
| `{name__v}` | The lifecycle `name__v` field value from which to retrieve entry criteria. Retrieve this value from [Retrieve User Actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/binders/152/versions/0/1/lifecycle_actions/read__c/entry_requirements
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Success",
    "properties": [
        {
            "name": "user_control_multiple__c",
            "description": "Read",
            "type": [
                "ObjectReference"
            ],
            "objectTypeReferenced": {
                "name": "User",
                "label": "User"
            },
            "required": true,
            "editable": true,
            "repeating": true,
            "scope": "WorkflowActivation"
        }
    ]
}
```

## Response Details

The response may include the following metadata elements describing the properties for which values need to be specified:

| Name | Description |
| --- | --- |
| `name` | The entry criteria name (used in the API). This value must be specified when starting the user action. |
| `description` | The entry criteria name (used in the UI). |
| `type` | The entry criteria data type. This value can be one of `String`, `Number`, `Date`, `Boolean`, `Picklist`, or `ObjectReference`. |
| `objectTypeReferenced` | When `type` is `ObjectReference`, this is the object being referenced. For example: `User`, `Product`, `Country`, etc. |
| `required` | Boolean value indicating whether or not the entry criteria must be specified when initiating a user action. |
| `editable` | Boolean value indicating whether or not the value can be edited by the user. |
| `repeating` | Boolean value indicating whether or not the entry criteria can have multiple values. |
| `minValue` | Indicates the minimum character length for the value. |
| `maxValue` | Indicates the maximum character length for the value. |
| `values` | When `type` is `Picklist`, this provides a list of possible values that can be used. |
| `currentSetting` | When a value has already been set, this shows the value. |
| `scope` | Indicates where the entry criteria property is defined. This value can be one of:  * `Binder`: This field must be set on the binder before the action can be initiated. * `WorkflowActivation`: This field must be included in the body of the initiate request. * `EmailFragment` or `CreatePresentation` |
