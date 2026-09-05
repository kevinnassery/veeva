<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-xmljson/ -->
<!-- title: Retrieve Component Record (XML/JSON) -->

# Retrieve Component Record (XML/JSON)

Retrieve metadata of a specific component record as JSON or XML. To retrieve as MDL, see [Retrieve Component Record MDL](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-mdl). Not all component types are eligible for record description retrieval. For details, see the Describe row of the Supported Operations table in the [Component Type Reference](/mdl/component-types).

GET`/api/{version}/configuration/{component_type_and_record_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{component_type_and_record_name}` | The component type name (`Picklist`, `Docfield`, `Doctype`, etc.) followed by the name of the record from which to retrieve metadata. The format is `{Componenttype}.{record_name}`. For example, `Picklist.color__c`. Find this with the [Retrieve Component Record Collection](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-collection) endpoint. |

## Query Parameters

| Name | Description |
| --- | --- |
| `loc` | When localized (translated) strings or Label Sets are available, retrieve them by setting `loc` to `true`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/configuration/Picklist.color__c
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "name": "color__c",
        "label": "Color",
        "Picklistentry": [
            {
                "name": "red__c",
                "value": "Red",
                "order": 1,
                "active": true
            },
            {
                "name": "blue__c",
                "value": "Blue",
                "order": 2,
                "active": true
            },
            {
                "name": "green__c",
                "value": "Green",
                "order": 3,
                "active": true
            }
        ],
        "active": true,
        "used_in": []
    }
}
```

## Response Details

On `SUCCESS`, the response contains the complete definition for a specific component record. If a field returns as blank or null, it means the record has no value for that field.
