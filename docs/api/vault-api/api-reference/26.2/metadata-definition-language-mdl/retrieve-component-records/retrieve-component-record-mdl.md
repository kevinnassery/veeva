<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-mdl/ -->
<!-- title: Retrieve Component Record (MDL) -->

# Retrieve Component Record (MDL)

Retrieve metadata of a specific component record as MDL. To retrieve as JSON or XML, see [Retrieve Component Record](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-xmljson). Vault does not generate RECREATE statements for all component types. For details, see the Generate RECREATE row of the Supported Operations table in the [Component Type Reference](/mdl/component-types).

GET`/api/mdl/components/{component_type_and_record_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{component_type_and_record_name}` | The component type name (`Picklist`, `Docfield`, `Doctype`, etc.) followed by the name of the record from which to retrieve metadata. The format is `{Componenttype}.{record_name}`. For example, `Picklist.color__c`. Find this with the [Retrieve Component Record Collection](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records/retrieve-component-record-collection) endpoint. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/mdl/components/Picklist.color__c
```

## Response

Copy to clipboard

```
RECREATE Picklist color__c (
   label('Color'),
   active(true),
   Picklistentry red__c(
      value('Red'),
      order(1),
      active(true)
   ),
   Picklistentry blue__c(
      value('Blue'),
      order(2),
      active(true)
   ),
   Picklistentry green__c(
      value('Green'),
      order(3),
      active(true)
   )
);
```

## Response Details

On `SUCCESS`, the response contains a RECREATE MDL statement of metadata for the specified component record. Metadata returned varies based on component type. If a field returns as blank, it means the record currently has no value for that field. Execute this RECREATE with the [Execute](/vault-api/api-reference/26.2/metadata-definition-language-mdl/execute-mdl-script) endpoint.
