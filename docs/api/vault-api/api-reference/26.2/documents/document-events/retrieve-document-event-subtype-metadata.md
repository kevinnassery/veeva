<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-events/retrieve-document-event-subtype-metadata/ -->
<!-- title: Retrieve Document Event Subtype Metadata -->

# Retrieve Document Event Subtype Metadata

GET`/api/{version}/metadata/objects/documents/events/{event_type}/types/{event_subtype}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{event_type}` | The event type. For example, `distribution__v`. |
| `{event_subtype}` | The event subtype. For example, `approved_email__v`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/events/distribution__v/types/approved_email__v
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "name": "approved_email__v",
    "label": "Approved Email",
    "properties": [
        {
            "name": "event_date__v",
            "label": "Event Date",
            "type": "DateTime",
            "queryable": true,
            "systemAttribute": true
        },
        {
            "name": "document_id__v",
            "label": "Document ID",
            "type": "ObjectReference",
            "objectType": "Documents",
            "queryable": true
        },
        {
            "name": "major_version_number__v",
            "label": "Document Major Version Number",
            "type": "Number",
            "queryable": true
        },
        {
            "name": "minor_version_number__v",
            "label": "Document Minor Version Number",
            "type": "Number",
            "queryable": true
        },
        {
            "name": "triggered_by__v",
            "label": "User ID",
            "type": "ObjectReference",
            "objectType": "Users",
            "queryable": true,
            "systemAttribute": true
        },
        {
            "name": "event_type__v",
            "label": "Event Type",
            "type": "String",
            "required": true,
            "queryable": true
        },
        {
            "name": "event_subtype__v",
            "label": "Event Subtype",
            "type": "String",
            "required": true,
            "queryable": true
        },
        {
            "name": "classification__v",
            "label": "Event Classification",
            "type": "String",
            "values": [
                {
                    "name": "distribute__v",
                    "label": "Distribute"
                },
                {
                    "name": "view__v",
                    "label": "View"
                },
                {
                    "name": "download__v",
                    "label": "Download"
                }
            ],
            "required": true,
            "queryable": true
        },
        {
            "name": "external_id__v",
            "label": "External ID",
            "type": "String",
            "required": true,
            "queryable": true
        },
        {
            "name": "user_email__v",
            "label": "User Email",
            "type": "String",
            "required": true,
            "queryable": true
        },
        {
            "name": "document_title__v",
            "label": "Document Title",
            "type": "String",
            "queryable": true,
            "systemAttribute": true
        },
        {
            "name": "document_number__v",
            "label": "Document Number",
            "type": "String",
            "queryable": true,
            "systemAttribute": true
        },
        {
            "name": "document_name__v",
            "label": "Document Name",
            "type": "String",
            "queryable": true,
            "systemAttribute": true
        }
    ]
}
```

## Response Details

On `SUCCESS`, Vault returns all metadata for the specified event subtype.
