<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-document-types/retrieve-document-subtype/ -->
<!-- title: Retrieve Document Subtype -->

# Retrieve Document Subtype

Retrieve all metadata from a document subtype, including all of its classifications (when available).

GET`/api/{version}/metadata/objects/documents/types/{type}/subtypes/{subtype}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{type}` | The document type. See [Retrieve Document Types](/vault-api/api-reference/26.2/documents/retrieve-document-types). |
| `{subtype}` | The document subtype. See [Retrieve Document Type](/vault-api/api-reference/26.2/documents/retrieve-document-types/retrieve-document-type). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/advertisement__c
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "name": "advertisement__c",
  "label": "Advertisement",
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
      "queryable": true
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
      "sectionPosition": 1,
      "hidden": false,
      "queryable": true,
      "shared": false,
      "helpContent": "The document name.",
      "definedInType": "type",
      "definedIn": "base_document__v"
    },
    {
      "name": "product__v",
      "scope": "DocumentVersion",
      "type": "ObjectReference",
      "required": true,
      "repeating": true,
      "systemAttribute": true,
      "editable": true,
      "setOnCreateOnly": false,
      "disabled": false,
      "objectType": "product__v",
      "label": "Product",
      "section": "productInformation",
      "sectionPosition": 1,
      "hidden": false,
      "queryable": true,
      "shared": false,
      "definedInType": "type",
      "definedIn": "base_document__v",
      "relationshipType": "reference",
      "relationshipName": "document_product__vr"
    },
  ],
  "classifications": [
    {
      "label": "Print",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/advertisement__c/classifications/print__c"
    },
    {
      "label": "Television",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/advertisement__c/classifications/television__c"
    },
    {
      "label": "Web",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/advertisement__c/classifications/web__c"
    }
  ],
  "relationshipTypes": [
    {
      "label": "Linked Documents",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/relationships"
    },
    {
      "label": "Based on",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/relationships"
    },
    {
      "label": "Related Claims",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/relationships"
    },
    {
      "label": "Supporting Documents",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/relationships"
    },
  ],
  "templates": [
    {
      "label": "ANSM Submission",
      "name": "ansm_submission__c",
      "kind": "binder",
      "definedIn": "promotional_piece__c",
      "definedInType": "type"
    }
  ],
  "availableLifecycles": [
    {
      "name": "promotional_piece__c",
      "label": "Promotional Piece"
    }
  ]
}
```

## Response Details

The response may contain the following details, depending on the configuration of your Vault:

| Name | Description |
| --- | --- |
| `name` | Name of the document subtype. |
| `label` | UI label for the document subtype. |
| `properties` | List of all the document fields associated to the document subtype. |
| `classifications` | This will not appear if the subtype has no classifications. |
| `templates` | List of all templates available for the document subtype. This will not appear if the subtype has no templates. |
| `availableLifecycles` | List of all lifecycles available for the document subtype. |
| `renditions` | List of all rendition types available for the document subtype. This will not appear if the subtype has no renditions configured. |
