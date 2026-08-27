<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-entry-criteria/ -->
<!-- title: Retrieve Document Entry Criteria -->

# Retrieve Document Entry Criteria

Retrieve the entry criteria for a user action. Entry criteria are requirements the document must meet before you can [initiate the action](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-document-user-action). Entry criteria are dynamic and depend on the lifecycle configuration, lifecycle state, or any workflow activation requirements defined in the *Start Step* of the workflow. Learn more about [entry criteria in Vault Help](https://platform.veevavault.help/en/gr/12617#types).

To retrieve entry criteria, the authenticated user must have permission to execute the action. To check permissions, [Retrieve User Actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions) and check for actions where `executable__v` is `true`.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/lifecycle_actions/{name__v}/entry_requirements`

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
| `{name__v}` | The lifecycle `name__v` field value from which to retrieve entry criteria. Retrieve this value from [Retrieve User Actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-document-user-actions). |

## Request: Start Legacy Workflow

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/lifecycle_actions/start_approval__c/entry_requirements
```

## Response: Start Legacy Workflow

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseMessage": "Success",
   "properties": [
       {
           "name": "user_control_multiple__c",
           "description": "Approver",
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
       },
       {
           "name": "date_control__c",
           "description": "Approval Due Date",
           "type": [
               "Date"
           ],
           "required": true,
           "editable": true,
           "scope": "WorkflowActivation"
       }
   ]
}
```

## Request: Change State

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/lifecycle_actions/approve__c/entry_requirements
```

## Response: Change State

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseMessage": "Success",
   "properties": [
       {
           "name": "country__v",
           "description": "Country",
           "type": [
               "ObjectReference"
           ],
           "objectTypeReferenced": {
               "name": "country__v",
               "label": "Country",
               "url": "/api/v26.2/metadata/vobjects/country__v",
               "label_plural": "Countries"
           },
           "required": true,
           "editable": true,
           "repeating": true,
           "scope": "Document",
           "currentSetting": [
               {
                   "name": "00C000000000109",
                   "label": "United States",
                   "value": "/api/v26.2/vobjects/country__v/00C000000000109"
               }
           ],
           "records": "/api/v26.2/vobjects/country__v"
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
| `scope` | Indicates where the entry criteria property is defined. This value can be one of:  * `Document`: This field must be set on the document before the action can be initiated. * `WorkflowActivation`: This field must be included in the body of the initiate request. * `ControlledCopy`: This field must be included in the body of the initiate request. * `EmailFragment` or `CreatePresentation` |

#### Response Details: Start Legacy Workflow

This example requests entry criteria for the `start_approval__c` workflow on document ID 17. The `properties` array in the response shows there are two entry criteria:

##### Approver: user\_control\_multiple\_\_c

| Name | Description |
| --- | --- |
| `name` | The name of this entry criteria in the API is `user_control_multiple__c`. Use this name when referring to this field in the API. |
| `description` | The label of this entry criteria in the UI is **Approver**. This should tell you the intended usage of this field. |
| `type` | This field is an `ObjectReference`. |
| `objectTypeReferenced` | This field is an `ObjectReference` to a `User`. |
| `repeating` | This field can accept more than one value, meaning more than one user can be assigned as the approver. |
| `scope` | The scope is `WorkflowActivation`, which means you can include this data as a name-value pair in the [initiate](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-document-user-action) request. |

##### Approval Due Date: date\_control\_\_c

| Name | Description |
| --- | --- |
| `name` | The name of this entry criteria in the API is `date_control__c`. Use this name when referring to this field in the API. |
| `description` | The label of this entry criteria in the UI is **Approval Due Date**. This should tell you the intended usage of this field. |
| `type` | This field is a `Date`. |
| `scope` | The scope is `WorkflowActivation`, which means you can include this data as a name-value pair in the [initiate](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-document-user-action) request. |

#### Response Details: Change State

This example requests entry criteria for the `approve__c` user action on document ID 17. The `properties` array in the response shows there is one entry criteria:

##### Country: country\_\_v

| Name | Description |
| --- | --- |
| `name` | The name of this entry criteria in the API is `country__v`. |
| `description` | The label of this entry criteria in the UI is **Country**. |
| `type` | This field is an `ObjectReference`. |
| `objectTypeReferenced` | This field is an `ObjectReference` to the `Country` object. |
| `repeating` | This field can accept more than one value, meaning the document can belong to more than one country. |
| `scope` | The scope is `Document`, which means this document field must have a value before you can [initiate](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-document-user-action) the action. |
| `currentSetting` | The field on this document is currently set to `United States`. If you're okay with this setting, you can [initiate](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-document-user-action) the action. If this was blank, you'd need to set it first. |
