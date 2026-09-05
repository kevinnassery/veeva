<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-collection/ -->
<!-- title: Retrieve Component Record Collection -->

# Retrieve Component Record Collection

Retrieve all records for a specific component type.

This endpoint does not support retrieving `Object` component records. Instead, use [Retrieve Object Collection](/vault-api/api-reference/26.2/vault-objects/retrieve-object-collection).

GET`/api/{version}/configuration/{component_type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{component_type}` | The component type name (`Picklist`, `Docfield`, `Doctype`, etc.). To retrieve records for `Object`, see [Retrieve Object Collection](/vault-api/api-reference/26.2/vault-objects/retrieve-object-collection). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/configuration/Picklist
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
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
    ]
}
```

## Response Details

On `SUCCESS`, the response contains all component records in the Vault for the specified component type. Each component record returns a minimum of API `name` and UI `label`, but most types return more. Complete details of the component can be retrieved using [Retrieve Component Record](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-xmljson) or [MDL](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-mdl).
