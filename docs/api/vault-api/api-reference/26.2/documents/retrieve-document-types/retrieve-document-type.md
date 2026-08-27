<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-document-types/retrieve-document-type/ -->
<!-- title: Retrieve Document Type -->

# Retrieve Document Type

Retrieve all metadata from a document type, including all of its subtypes (when available).

GET`/api/{version}/metadata/objects/documents/types/{type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{type}` | The document type. See [Retrieve Document Types](/vault-api/api-reference/26.2/documents/retrieve-document-types). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "name": "promotional_piece__c",
  "label": "Promotional Piece",
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
    }
  ],
  "renditions": [
    "viewable_rendition__v",
    "production_proof__c",
    "distribution_package__c",
    "imported_rendition__c",
    "veeva_distribution_package__c"
  ],
  "relationshipTypes": [
    {
      "label": "CrossLink Latest Bindings",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/relationships"
    },
    {
      "label": "CrossLink Latest Steady State Bindings",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/relationships"
    },
    {
      "label": "Linked Documents",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/relationships"
    },
    {
      "label": "Based on",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/relationships"
    }
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
  ],
  "subtypes": [
    {
      "label": "Advertisement",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/advertisement__c"
    },
    {
      "label": "Direct Mail",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/direct_mail__c"
    },
    {
      "label": "Formulary Announcement",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/formulary_announcement__c"
    },
    {
      "label": "Internal Communication",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/internal_communication__c"
    },
    {
      "label": "Managed Markets Program",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/managed_markets_program__c"
    },
    {
      "label": "Healthcare Practitioner Resources",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/healthcare_practitioner_resources__c"
    },
    {
      "label": "Convention Item",
      "value": "https://promomats-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional_piece__c/subtypes/convention_item__c"
    }
  ]
}
```

## Response Details

The response includes all metadata for the document specified type. If the type contains subtypes in the document type hierarchy, the list of subtypes and the URLs pointing to their metadata will be included in the response. The list of document fields defined for the specified type are also included in the response.

Each document type may include some or all of the following fields:

| Metadata Field | Description |
| --- | --- |
| `name` | Name of the document type. Used primarily in the API. |
| `label` | Label of the document type as seen in the API and UI. |
| `renditions` | List of all rendition types available for the document type. |
| `relationshipTypes` | List of all relationship types available for the document type. |
| `properties` | List of all the document fields associated to the document type. |
| `processes` | List of all processes available for the document type (when configured). |
| `etmfDepartment` | In eTMF Vaults only. List of all eTMF departments available for the document type (when configured). |
| `referenceModels` | In eTMF Vaults only. List of all reference models available for the document type. |
| `defaultWorkflows` | List of all workflows available for the document type. |
| `availableLifecycles` | List of all lifecycles available for the document type. |
| `templates` | List of all templates available for the document type (when configured). |
| `subtypes` | List of all standard and custom document subtypes available for the document type. |
