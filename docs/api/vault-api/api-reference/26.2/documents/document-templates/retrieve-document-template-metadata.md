<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/retrieve-document-template-metadata/ -->
<!-- title: Retrieve Document Template Metadata -->

# Retrieve Document Template Metadata

Retrieve the metadata which defines the shape of document templates in your Vault.

GET`/api/{version}/metadata/objects/documents/templates`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/templates
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "data": [
    {
      "name": "name__v",
      "type": "String",
      "requiredness": "required",
      "max_length": 50,
      "editable": true,
      "multi_value": false
    },
    {
      "name": "label__v",
      "type": "String",
      "requiredness": "required",
      "max_length": 100,
      "editable": true,
      "multi_value": false
    },
    {
      "name": "active__v",
      "type": "Boolean",
      "requiredness": "required",
      "editable": true,
      "multi_value": false
    },
    {
      "name": "type__v",
      "type": "Component",
      "requiredness": "required",
      "editable": true,
      "multi_value": false,
      "component": "Doctype"
    },
    {
      "name": "subtype__v",
      "type": "Component",
      "requiredness": "conditional",
      "editable": true,
      "multi_value": false,
      "component": "Doctype"
    },
    {
      "name": "classification__v",
      "type": "Component",
      "requiredness": "optional",
      "editable": true,
      "multi_value": false,
      "component": "Doctype"
    },
    {
      "name": "format__v",
      "type": "String",
      "requiredness": "required",
      "max_length": 200,
      "editable": false,
      "multi_value": false
    },
    {
      "name": "size__v",
      "type": "Number",
      "requiredness": "required",
      "max_value": 9223372036854775807,
      "min_value": 0,
      "scale": 0,
      "editable": false,
      "multi_value": false
    },
    {
      "name": "created_by__v",
      "type": "Number",
      "requiredness": "required",
      "max_value": 9223372036854775807,
      "min_value": 0,
      "scale": 0,
      "editable": false,
      "multi_value": false
    },
    {
      "name": "file_uploaded_by__v",
      "type": "Number",
      "requiredness": "required",
      "max_value": 9223372036854775807,
      "min_value": 0,
      "scale": 0,
      "editable": false,
      "multi_value": false
    },
    {
      "name": "md5checksum__v",
      "type": "String",
      "requiredness": "required",
      "max_length": 100,
      "editable": false,
      "multi_value": false
    }
  ]
}
```

## Response Details

| Field Name | Field Type | Description | Required | Editable |
| --- | --- | --- | --- | --- |
| `name__v` | String | Document template name. Used in the API when retrieving/creating/updating templates. | True | True |
| `label__v` | String | Document template label. The name users see in the UI when selecting templates. | True | True |
| `active__v` | Boolean | Indicates whether or not the template is available for creating documents. | True | True |
| `type__v` | Component | The document type to which the template is associated. | True | True |
| `subtype__v` | Component | The document subtype to which the template is associated. | Conditional \* | True |
| `classification__v` | Component | The document classification to which the template is associated. | Conditional \* | True |
| `format__v` | String | Document template format (.doc, .pdf, etc.). | System-Managed | False |
| `size__v` | Number | Document template size (Kb). | System-Managed | False |
| `created_by__v` | Number | Vault user ID of the person who created the template. | System-Managed | False |
| `file_uploaded_by__v` | Number | Vault user ID of the person who uploaded the template file. | System-Managed | False |
| `md5checksum__v` | String | A string calculated using MD5 algorithm that can be used to uniquely identify the source file. | System-Managed | False |

\* The document subtype and classification fields are "conditional" in that they are only required if the template exists at the document subtype or classification level.
