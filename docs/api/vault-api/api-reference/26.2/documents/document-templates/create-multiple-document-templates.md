<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/create-multiple-document-templates/ -->
<!-- title: Create Multiple Document Templates -->

# Create Multiple Document Templates

Create up to 500 document templates. You cannot create templates if your Vault exceeds template limits. Learn more about [document template limits in Vault Help](https://platform.veevavault.help/en/gr/5509/#limits).

POST`/api/{version}/objects/documents/templates`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

#### Body Parameters: Basic Document Templates

To create basic document templates, create a CSV or JSON input file with the following fields:

| Name | Description |
| --- | --- |
| `name__v` optional | The name of the new document template. If not included, Vault will use the specified `label__v` value to generate a value for the `name__v` field. |
| `label__v` required | The label of the new document template. This is the name users will see among the available binder templates in the UI. |
| `type__v` required | The name of the document type to which the template will be associated. |
| `subtype__v` optional | The name of the document subtype to which the template will be associated. |
| `classification__v` optional | The name of the document classification to which the template will be associated. |
| `active__v` required | Set to `true` or `false` to indicate whether or not the new document template should be set to active, i.e., available for selection when creating a document. |
| `file` required | The filepath of the file for this document template, from file staging. Maximum allowed size is 4GB. |

[Download Input File](/sample-files/bulk-create-document-templates.json)

#### Body Parameters: Controlled Document Templates

To create controlled document templates, create a CSV or JSON input file with the following fields:

| Name | Description |
| --- | --- |
| `name__v` optional | The name of the new document template. If not included, Vault will use the specified `label__v` value to generate a value for the `name__v` field. |
| `label__v` required | The label of the new document template. This is the name users will see among the available binder templates in the UI. |
| `active__v` required | Set to `true` or `false` to indicate whether or not the new document template should be set to active, i.e., available for selection when creating a document. |
| `is_controlled__v` required | Set to `true` to indicate this template is a controlled document template. |
| `template_doc_id__v` required | The document `id` value to use as the Template Document for this controlled document template. Learn more about [setting up valid Template Documents in Vault Help](https://platform.veevavault.help/en/gr/46025). |

#### Example CSV Input: Basic Document Templates

| `file` | `name__v` | `label__v` | `type__v` | `subtype__v` | `classification__v` | `active__v` |
| --- | --- | --- | --- | --- | --- | --- |
| templates/doc\_template\_1.doc | site\_document\_template\_\_c | SMF Template | site\_master\_file\_\_v |  |  | true |
| templates/doc\_template\_2.doc |  | TMF Document Template | trial\_master\_file\_\_v |  |  | true |
| templates/doc\_template\_3.doc |  | Trial Protocol Document Template | central\_trial\_documents\_\_vs | trial\_documents\_\_vs | protocol\_\_vs | true |
| templates/doc\_template\_4.doc |  | Clinical Study Report Document Template | central\_trial\_documents\_\_vs | reports\_\_vs | clinical\_study\_report\_\_vs | false |

In this example input, we're creating four new document templates in our Vault:

* We've included the `file` parameter with the path/name of four document template source files located in the "templates" directory of our Vault's staging server.
* We've only specified the `name__v` value for the first template and given it a different `label__v` value. The other templates will inherit their `name__v` values from the `label__v` values.
* We've specified the document type, subtype, and classification to which each document template will be associated.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
--data-raw 'file,name__v,label__v,type__v,subtype__v,classification__v,active__v
templates/doc_template_1.doc,site_document_template__c,SMF Template,site_master_file__v	,,true
templates/doc_template_2.doc,tmf_document_template__c,trial_master_file__v,true
templates/doc_template_3.doc,trial_protocol_document_template__c,central_trial_documents__vs,trial_documents__vs	protocol__vs,true
templates/doc_template_4.doc,clinical_study_report_document_template__c,central_trial_documents__vs,reports__vs	clinical_study_report__vs,false' \
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
         "name":"site_document_template__c"
      },
      {
         "responseStatus":"SUCCESS",
         "name":"tmf_document_template__c"
      },
      {
         "responseStatus":"SUCCESS",
         "name":"trial_protocol_document_template__c"
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
