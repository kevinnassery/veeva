<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/retrieve-document-template-collection/ -->
<!-- title: Retrieve Document Template Collection -->

# Retrieve Document Template Collection

Retrieve all document templates.

GET`/api/{version}/objects/documents/templates`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/templates
```

## Response

Copy to clipboard

```
{
   "responseStatus":"SUCCESS",
   "data":[
      {
         "name__v":"claim_document_template__c",
         "label__v":"Claim Document Template",
         "active__v":true,
         "type__v":"claim__c",
         "format__v": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         "size__v": 2781904,
         "created_by__v": 12021,
         "file_uploaded_by__v": 12021,
         "md5checksum__v": 98238947109287333
      },
      {
         "name__v":"clinical_study_document_template__c",
         "label__v":"Clinical Study Document Template",
         "active__v":true,
         "type__v":"reference_document__c",
         "subtype__v":"clinical_study__c",
         "format__v": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         "size__v": 15776,
         "created_by__v": 12021,
         "file_uploaded_by__v": 12021,
         "md5checksum__v": 75886214401031117
      },
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

The response lists all document templates which have been added to the Vault. Shown above, three document templates exist in our Vault:

* The first `claim_document_template__c` exists at the document type level. It is intended for use with new documents of the `claim__c` type.
* The second `clinical_study_document_template__c` exists at the document subtype level. It is intended for use with new documents of the `clinical_study__c` subtype.
* The third `promo_ad_print_document_template__c` exists at the document classification level. It is intended for use with new documents of the `print__c` classification.

For information about the document template metadata, refer to the "Retrieve Document Template Attributes" response below.
