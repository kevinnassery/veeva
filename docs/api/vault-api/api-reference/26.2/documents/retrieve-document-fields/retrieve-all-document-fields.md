<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-all-document-fields/ -->
<!-- title: Retrieve All Document Fields -->

# Retrieve All Document Fields

Retrieve all standard and custom document fields and field properties.

GET`/api/{version}/metadata/objects/documents/properties`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/properties
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "properties": [
       {
           "name": "id",
           "type": "id",
           "required": true,
           "maxLength": 20,
           "minValue": 0,
           "maxValue": 9223372036854775807,
           "repeating": false,
           "systemAttribute": true,
           "editable": false,
           "setOnCreateOnly": true,
           "disabled": false,
           "hidden": true,
           "queryable": true,
           "facetable": false
       },
       {
            "name": "language__c",
            "scope": "DocumentVersion",
            "type": "Picklist",
            "required": false,
            "repeating": false,
            "systemAttribute": false,
            "editable": true,
            "setOnCreateOnly": false,
            "disabled": false,
            "defaultValue": [
                "English"
            ],
            "label": "Language",
            "entryLabels": [
                "Spanish",
                "English",
                "French"
            ],
            "entryNames": [
                "spanish__c",
                "english__c",
                "french__c"
            ],
            "section": "general__c",
            "sectionPosition": 1000,
            "hidden": false,
            "queryable": true,
            "shared": false,
            "definedInType": "type",
            "definedIn": "base_document__v",
            "noCopy": false,
            "secureRelationship": false,
            "facetable": true
       },
       {
           "name": "name__v",
           "scope": "DocumentVersion",
           "type": "String",
           "required": true,
           "maxLength": 100,
           "repeating": false,
           "systemAttribute": true,
           "editable": true,
           "setOnCreateOnly": false,
           "disabled": false,
           "label": "Name",
           "section": "generalProperties",
           "sectionPosition": 0,
           "hidden": false,
           "queryable": true,
           "shared": false,
           "helpContent": "Displayed throughout application for the document, including in Library, Reporting, Notifications and Workflows.",
           "definedInType": "type",
           "definedIn": "base_document__v",
           "noCopy": false,
           "secureRelationship": false,
           "facetable": false
       },
       {
           "name": "template_document__v",
           "scope": "DocumentVersion",
           "type": "Boolean",
           "required": false,
           "repeating": false,
           "systemAttribute": true,
           "editable": false,
           "setOnCreateOnly": false,
           "disabled": false,
           "defaultValue": "false",
           "label": "Template Document",
           "section": "generalProperties",
           "sectionPosition": 1001,
           "hidden": true,
           "queryable": true,
           "shared": false,
           "definedInType": "type",
           "definedIn": "base_document__v",
           "noCopy": false,
           "secureRelationship": false,
           "facetable": true
       }
    ]
}
```

## Response Details

The response lists all standard and custom document fields and field metadata. Note the following field metadata:

| Metadata Field | Description |
| --- | --- |
| `required` | When `true`, the field value must be set when creating new documents. |
| `editable` | When `true`, the field value can be defined by the currently authenticated user. When `false`, the field value is read-only or system-managed, or the current user does not have adequate permissions to edit this field. |
| `setOnCreateOnly` | When `true`, the field value can only be set once (when creating new documents). |
| `hidden` | Boolean indicating field availability to the UI. When `true`, the field is never available to nor visible in the UI. When `false`, the field is always available to the UI but visibility to users is subject to field-level security overrides. If field-level security is configured to hide a field for the currently authenticated API user, the field is not returned in this API response. |
| `queryable` | When `true`, field values can be retrieved using [VQL](/vql/overview). If field-level security is configured to hide the field from the user running this API, the field is not queryable by that user and will not appear in the API response. |
| `noCopy` | When `true`, field values are not copied when using the **Make a Copy** action. |
| `facetable` | When `true`, the field is available for use as a faceted filter in the Vault UI. Learn more about [faceted filters in Vault Help](https://platform.veevavault.help/en/gr/1616). |
