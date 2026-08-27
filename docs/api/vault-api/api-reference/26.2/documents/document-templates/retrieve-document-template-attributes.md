<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/retrieve-document-template-attributes/ -->
<!-- title: Retrieve Document Template Attributes -->

# Retrieve Document Template Attributes

Retrieve the attributes from a document template.

GET`/api/{version}/objects/documents/templates/{template_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{template_name}` | The document template `name__v` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/templates/promo_ad_print_document_template__c
```

## Response

Copy to clipboard

```
{
   "responseStatus":"SUCCESS",
   "data":[
      {
         "name__v":"promo_ad_print_document_template__c",
         "label__v":"Promo Ad Print Document Template",
         "active__v":true,
         "type__v":"promotional_piece__c",
         "subtype__v":"advertisement__c",
         "classification__v":"print__c",
         "format__v": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         "size__v": 82923,
         "created_by__v": 12021,
         "file_uploaded_by__v": 12021,
         "md5checksum__v": 52478042594365555
      }
   ]
}
```

## Response Details

The response lists all attributes configured on a specific document template in the Vault. Shown above are the attributes configured on the specified template:

| Field Name | Description |
| --- | --- |
| `name__v` | Name of the document template. This value is not displayed to end users in the UI. It is seen by Admins and used in the API. |
| `label__v` | Label of the document template. When users in the UI create documents from templates, they see this value in the list of available templates. |
| `type__v` | Vault document type to which the template is associated. |
| `subtype__v` | Vault document subtype to which the template is associated. This field is only displayed if the template exists at the document subtype or classification level. |
| `classification__v` | Vault document classification to which the template is associated. This field is only displayed if the template exists at the document classification level. The template shown in this response is configured for use with documents of the `print__c` classification. |
| `format__v` | File format of the document template. |
| `size__v` | Size of the document template (Kb). |
| `created_by__v` | Vault user ID of the person who created the document template. |
| `file_uploaded_by__v` | Vault user ID of the person who uploaded the document template. |
| `md5checksum__v` | A string calculated using MD5 algorithm that can be used to uniquely identify the source file. |
