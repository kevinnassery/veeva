<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-relationships/retrieve-document-type-relationships/ -->
<!-- title: Retrieve Document Type Relationships -->

# Retrieve Document Type Relationships

Retrieve all relationships from a document type.

GET`/api/{version}/metadata/objects/documents/types/{type}/relationships`

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
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/types/promotional__c/relationships
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
            "length": 20,
            "editable": false,
            "queryable": true,
            "required": true,
            "multivalue": false,
            "onCreateEditable": false
        },
        {
            "name": "source_doc_id__v",
            "type": "id",
            "length": 20,
            "editable": true,
            "queryable": true,
            "required": true,
            "multivalue": false,
            "onCreateEditable": true
        },
        {
            "name": "source_major_version__v",
            "type": "Integer",
            "length": 10,
            "editable": false,
            "queryable": true,
            "required": false,
            "multivalue": false,
            "onCreateEditable": true
        },
        {
            "name": "source_minor_version__v",
            "type": "Integer",
            "length": 10,
            "editable": false,
            "queryable": true,
            "required": false,
            "multivalue": false,
            "onCreateEditable": true
        },
        {
            "name": "target_doc_id__v",
            "type": "id",
            "length": 20,
            "editable": false,
            "queryable": true,
            "required": true,
            "multivalue": false,
            "onCreateEditable": true
        },
        {
            "name": "target_major_version__v",
            "type": "Integer",
            "length": 10,
            "editable": false,
            "queryable": true,
            "required": false,
            "multivalue": false,
            "onCreateEditable": true
        },
        {
            "name": "target_minor_version__v",
            "type": "Integer",
            "length": 10,
            "editable": false,
            "queryable": true,
            "required": false,
            "multivalue": false,
            "onCreateEditable": true
        },
        {
            "name": "relationship_type__v",
            "type": "String",
            "length": 255,
            "editable": false,
            "queryable": true,
            "required": true,
            "multivalue": false,
            "onCreateEditable": true
        },
        {
            "name": "created_date__v",
            "type": "DateTime",
            "length": 0,
            "editable": false,
            "queryable": true,
            "required": false,
            "multivalue": false,
            "onCreateEditable": false
        },
        {
            "name": "created_by__v",
            "type": "ObjectReference",
            "length": 10,
            "object": "users",
            "editable": false,
            "queryable": true,
            "required": false,
            "multivalue": false,
            "onCreateEditable": false
        },
        {
            "name": "source_vault_id__v",
            "type": "id",
            "length": 20,
            "editable": false,
            "queryable": true,
            "required": false,
            "multivalue": false,
            "onCreateEditable": false
        }
    ],
    "relationshipTypes": [
        {
            "value": "crosslink_document_latest__v",
            "label": "CrossLink Latest Bindings",
            "sourceDocVersionSpecific": true,
            "targetDocVersionSpecific": false,
            "system": true,
            "singleUse": false,
            "targetDocumentTypes": [
                {
                    "label": "Attachment",
                    "value": "attachment__v"
                },
                {
                    "label": "Staged",
                    "value": "staged__v"
                },
                {
                    "label": "Medication Packaging Text",
                    "value": "medication_packaging_text__c"
                },
                {
                    "label": "Promotional",
                    "value": "promotional__c"
                },
                {
                    "label": "Unclassified",
                    "value": "undefined__v"
                }
            ]
        },
        {
            "value": "supporting_documents__c",
            "label": "Supporting Documents",
            "sourceDocVersionSpecific": false,
            "targetDocVersionSpecific": false,
            "system": false,
            "singleUse": false,
            "targetDocumentTypes": [
                {
                    "label": "Attachment",
                    "value": "attachment__v"
                },
                {
                    "label": "Staged",
                    "value": "staged__v"
                },
                {
                    "label": "Medication Packaging Text",
                    "value": "medication_packaging_text__c"
                },
                {
                    "label": "Promotional",
                    "value": "promotional__c"
                },
                {
                    "label": "Unclassified",
                    "value": "undefined__v"
                }
            ]
        },
        {
            "value": "references__v",
            "label": "Linked Documents",
            "sourceDocVersionSpecific": true,
            "targetDocVersionSpecific": true,
            "system": true,
            "singleUse": false,
            "targetDocumentTypes": [
                {
                    "label": "Attachment",
                    "value": "attachment__v"
                },
                {
                    "label": "Staged",
                    "value": "staged__v"
                },
                {
                    "label": "Medication Packaging Text",
                    "value": "medication_packaging_text__c"
                },
                {
                    "label": "Promotional",
                    "value": "promotional__c"
                },
                {
                    "label": "Unclassified",
                    "value": "undefined__v"
                }
            ]
        },
        {
            "value": "crosslink_document_latest_steady_state__v",
            "label": "CrossLink Latest Steady State Bindings",
            "sourceDocVersionSpecific": true,
            "targetDocVersionSpecific": false,
            "system": true,
            "singleUse": false,
            "targetDocumentTypes": [
                {
                    "label": "Attachment",
                    "value": "attachment__v"
                },
                {
                    "label": "Staged",
                    "value": "staged__v"
                },
                {
                    "label": "Medication Packaging Text",
                    "value": "medication_packaging_text__c"
                },

                {
                    "label": "Promotional",
                    "value": "promotional__c"
                },
                {
                    "label": "Unclassified",
                    "value": "undefined__v"
                }
            ]
        },
        {
            "value": "basedon__v",
            "label": "Based on",
            "sourceDocVersionSpecific": false,
            "targetDocVersionSpecific": true,
            "system": true,
            "singleUse": false,
            "targetDocumentTypes": [
                {
                    "label": "Attachment",
                    "value": "attachment__v"
                },
                {
                    "label": "Staged",
                    "value": "staged__v"
                },
                {
                    "label": "Medication Packaging Text",
                    "value": "medication_packaging_text__c"
                },
                {
                    "label": "Promotional",
                    "value": "promotional__c"
                },
                {
                    "label": "Unclassified",
                    "value": "undefined__v"
                }
            ]
        },
        {
            "value": "original_source__v",
            "label": "Original Source",
            "sourceDocVersionSpecific": false,
            "targetDocVersionSpecific": true,
            "system": true,
            "singleUse": false,
            "targetDocumentTypes": [
                {
                    "label": "Attachment",
                    "value": "attachment__v"
                },
                {
                    "label": "Staged",
                    "value": "staged__v"
                },
                {
                    "label": "Medication Packaging Text",
                    "value": "medication_packaging_text__c"
                },
                {
                    "label": "Promotional",
                    "value": "promotional__c"
                },
                {
                    "label": "Unclassified",
                    "value": "undefined__v"
                }
            ]
        },
        {
            "value": "crosslink_document_static__v",
            "label": "CrossLink Static Bindings",
            "sourceDocVersionSpecific": true,
            "targetDocVersionSpecific": true,
            "system": true,
            "singleUse": false,
            "targetDocumentTypes": [
                {
                    "label": "Attachment",
                    "value": "attachment__v"
                },
                {
                    "label": "Staged",
                    "value": "staged__v"
                },
                {
                    "label": "Medication Packaging Text",
                    "value": "medication_packaging_text__c"
                },
                {
                    "label": "Doc Roles Doc",
                    "value": "doc_roles_doc__c"
                },
                {
                    "label": "Promotional",
                    "value": "promotional__c"
                },
                {
                    "label": "Unclassified",
                    "value": "undefined__v"
                }
            ]
        }
    ],
    "relationships": [
        {
            "relationship_name": "source__vr",
            "relationship_label": "Source Relationship",
            "relationship_type": "reference_outbound",
            "object": {
                "name": "documents"
            }
        },
        {
            "relationship_name": "target__vr",
            "relationship_label": "Target Relationship",
            "relationship_type": "reference_outbound",
            "object": {
                "name": "documents"
            }
        }
    ]
}
```

## Response Details

The example response shows the metadata for the relationship type configured for the specified document type `promotional__c`.

##### Relationship Fields

The relationships object includes the following fields:

| Field Name | Description |
| --- | --- |
| `id` | The relationship `id` field. |
| `source_doc_id__v` | The document `id` field of the source document on which the relationship is defined. |
| `source_major_version__v` | The `major_version_number__v` of the source document. This only applies when the target document is bound to a specific version of the source document. |
| `source_minor_version__v` | The `minor_version_number__v` of the source document. This only applies when the target document is bound to a specific version of the source document. |
| `target_doc_id__v` | The document `id` field of the target document which is bound to the source document. |
| `target_major_version__v` | The `major_version_number__v` of the target document. This only applies when the source document is bound to a specific version of the target document. |
| `target_minor_version__v` | The `minor_version_number__v` of the target document. This only applies when the source document is bound to a specific version of the target document. |
| `relationship_type__v` | The relationship type (`basedon__c`, `supporting_documents__c`, `related_claims__c`, `related_pieces__c`, etc.). |
| `created_date__v` | The date and time when the relationship is created. |
| `created_by__v` | The user `id` value of the person who creates the relationship. |
| `source_vault_id__v` | The Vault `id` value where the source document exists. [Learn more](/vault-api/api-reference/26.2/domain-information/retrieve-domain-information). |

##### Relationship Type Properties

Relationship types and their properties are configurable and vary from Vault to Vault.

| Metadata Field | Description |
| --- | --- |
| `value` | The relationship type name (API key). |
| `label` | The relationship type label. |
| `sourceDocVersionSpecific` | Indicates whether or not the relationship type applies to a specific version of the source document. If `false`, the relationship type applies to all versions. |
| `targetDocVersionSpecific` | Indicates whether or not the relationship type applies to a specific version of the target document. If `false`, the relationship type applies to all versions. |
| `system` | Indicates whether or not the relationship type is a standard Vault relationship type. |
| `singleUse` | Indicates whether or not the relationship type can only be used once for each document. |
| `targetDocumentTypes` | Lists all document types which are valid target documents for the relationship type. |

#### Relationships

The `source__vr` and `target__vr` relationship names can be used to perform document relationship lookup queries.
