<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/update-single-document-template/ -->
<!-- title: Update Single Document Template -->

# Update Single Document Template

Update a single document template in your Vault.

PUT`/api/{version}/objects/documents/templates/{template_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{template_name}` | The document template `name__v` field value. |

## Body Parameters

You can update the following fields on document templates:

| Field Name | Description |
| --- | --- |
| `name__v` optional | The name of an existing document template. This is required. |
| `new_name` optional | Change the name of an existing document template. |
| `label__v` optional | Change the label of an existing document template. This is the name users will see among the available document templates in the UI. |
| `active__v` optional | Set to `true` or `false` to indicate whether or not the document template should be set to active, i.e., available for selection when creating a document. |

#### Convert Basic Document Template to Controlled Document Template

To convert a basic document template to a controlled document template, specify the Template Document. Vault will automatically update `is_controlled__v` on this template to `true`.

It is not possible to convert a controlled document template into a basic document template.

| Field Name | Description |
| --- | --- |
| `template_doc_id__v` optional | The document `id` value to use as the Template Document for this controlled document template. Learn more about [setting up valid Template Documents in Vault Help](https://platform.veevavault.help/en/gr/46025). |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-H "Accept: application/json" \
-d "name__v=promo_ad_web_document_template__c" \
-d "label__v=Promo Ad Web Document Template" \
-d "active__v=true" \
https://myvault.veevavault.com/api/v26.2/objects/documents/templates/promo_ad_print_document_template__c
```

## Response

Copy to clipboard

```
responseStatus,name,errors
SUCCESS,promo_ad_web_document_template__c,
```
