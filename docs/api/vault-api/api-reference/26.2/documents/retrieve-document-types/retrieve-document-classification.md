<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-document-types/retrieve-document-classification/ -->
<!-- title: Retrieve Document Classification -->

# Retrieve Document Classification

Retrieve all metadata from a document classification.

GET`/api/{version}/metadata/objects/documents/types/{type}/subtypes/{subtype}/classifications/{classification}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{type}` | The document type. See [Retrieve Document Types](/vault-api/api-reference/26.2/documents/retrieve-document-types). |
| `{subtype}` | The document type. See [Retrieve Document Type](/vault-api/api-reference/26.2/documents/retrieve-document-types/retrieve-document-type). |
| `{classification}` | The document classification. See [Retrieve Document Subtype](/vault-api/api-reference/26.2/documents/retrieve-document-types/retrieve-document-subtype). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/advertisement__c/classifications/print__c
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
| `properties` | List of all the document fields associated to the document classification. |
| `templates` | List of all templates available for the document classification. This will not appear if the classification has no templates. |
| `availableLifecycles` | List of all lifecycles available for the document classification. |
| `renditions` | List of all rendition types available for the document classification. This will not appear if the classification has no renditions configured. |
