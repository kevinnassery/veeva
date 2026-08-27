<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/create-single-document-template/ -->
<!-- title: Create Single Document Template -->

# Create Single Document Template

Create one basic document template. To create multiple document templates, see [Create Multiple Document Templates](/vault-api/api-reference/26.2/documents/document-templates/create-multiple-document-templates).

You cannot create templates if your Vault exceeds template limits. Learn more about [document template limits in Vault Help](https://platform.veevavault.help/en/gr/5509/#limits).

POST`/api/{version}/objects/documents/templates`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

#### Body Parameters: Basic Document Template

When creating basic document templates, the following fields are required in all Vaults:

| Name | Description |
| --- | --- |
| `name__v` optional | The name of the new document template. If not included, Vault will use the specified `label__v` value to generate a value for the `name__v` field. |
| `label__v` required | The label of the new document template. This is the name users will see among the available templates in the UI. |
| `type__v` required | The name of the document type to which the template will be associated. |
| `subtype__v` optional | The name of the document subtype to which the template will be associated. This is only required if associating the template with a document subtype. |
| `classification__v` optional | The name of the document classification to which the template will be associated. This is only required if associating the template with a document classification. |
| `active__v` required | Set to true or false to indicate whether or not the new document template should be set to active, i.e., available for selection when creating a document. |
| `file` required | The filepath of the file for this document template. Maximum allowed size is 4GB. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-H "Accept: text/csv" \
-F "file=Promo Ad Template.docx" \
-F "label__v=Promo Ad Template" \
-F "type__v=promotional_piece__c" \
-F "subtype__v=advertisement__c" \
-F "classification__v=print__c" \
-F "active__v=true" \
https://myvault.veevavault.com/api/v26.2/objects/documents/templates
```

## Response

Copy to clipboard

```
responseStatus,name,errors
SUCCESS,promo_ad_template__c,
```
