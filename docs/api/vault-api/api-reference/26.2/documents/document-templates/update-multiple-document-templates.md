<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/update-multiple-document-templates/ -->
<!-- title: Update Multiple Document Templates -->

# Update Multiple Document Templates

Update up to 500 document templates in your Vault.

PUT`/api/{version}/objects/documents/templates`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

To update document templates, prepare a CSV or JSON input file. You can update the following fields on document templates:

| Name | Description |
| --- | --- |
| `name__v` required | Include the name of an existing document template. |
| `new_name` optional | Change the name of an existing document template. |
| `label__v` optional | Change the label of an existing document template. This is the name users will see among the available binder templates in the UI. |
| `active__v` optional | Set to `true` or `false` to indicate whether or not the document templates should be set to active, i.e., available for selection when creating a document. |

[Download Input File](/sample-files/bulk-update-document-templates.json)

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
-H "Content-Type: text/csv" \
--data-raw 'name__v,active__v
claim_document_template__c,true
clinical_study_document_template__c,false
clinical_trial_document_template__c,true' \
https://myvault.veevavault.com/api/v26.2/objects/documents/templates
```

## Response

Copy to clipboard

```
{
   "responseStatus":"SUCCESS",
   "data":[
      {
         "responseStatus":"SUCCESS",
         "name":"claim_document_template__c"
      },
      {
         "responseStatus":"SUCCESS",
         "name":"clinical_study_document_template__c"
      },
      {
         "responseStatus":"FAILURE",
         "errors":[
            {
               "type":"INVALID_DATA",
               "message":"Error message describing why this template was not created."
            }
         ]
      }
   ]
}
```
