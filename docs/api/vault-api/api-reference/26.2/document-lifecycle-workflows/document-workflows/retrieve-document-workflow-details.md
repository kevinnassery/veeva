<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-workflows/retrieve-document-workflow-details/ -->
<!-- title: Retrieve Document Workflow Details -->

# Retrieve Document Workflow Details

Retrieves the details for a specific document workflow.

GET`/api/{version}/objects/documents/actions/{workflow_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `workflow_name` | The document workflow `name` value. |

## Query Parameters

| Name | Description |
| --- | --- |
| `loc` | When localized (translated) strings are available, retrieve them by setting `loc` to `true`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/actions/Objectworkflow.clinical_study_report_approval__c
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "name": "Objectworkflow.clinical_study_report_approval__c",
       "controls": [
           {
               "type": "instructions",
               "instructions": "Add approvers",
               "prompts": [],
               "label": "Instructions"
           },
           {
               "type": "participant",
               "prompts": [
                   {
                       "label": "Approver",
                       "name": "approver__c"
                   }
               ],
               "required": true,
               "label": "Participants"
           },
           {
               "type": "participant",
               "prompts": [
                   {
                       "label": "Exec Approver",
                       "name": "exec_approver__c"
                   }
               ],
               "required": true,
               "label": "Participants"
           },
           {
               "prompts": [
                   {
                       "label": "Documents",
                       "name": "documents__sys"
                   }
               ],
               "label": "Documents",
               "type": "documents"
           },
           {
               "prompts": [
                   {
                       "multi_value": false,
                       "label": "Description",
                       "name": "description__sys"
                   }
               ],
               "label": "Description",
               "type": "description"
           }
       ],
       "label": "Clinical Study Report Approval",
       "type": "multidocworkflow",
       "cardinality": "OneOrMany"
   }
}
```

## Response Details

On `SUCCESS`, the response lists the fields that must be configured with values in order to initiate the document workflow. These are based on the controls configured in the workflow start step.

The response may include the following types of controls:

| Name | Description |
| --- | --- |
| `prompts` | The input prompts which accept values when initiating the workflow. |
| `instructions` | Contains static instruction text regarding workflow initiation. |
| `participant` | Used to specify users who will be part of the workflow. |
| `date` | Date selections for the workflow, such as due date. |
| `documents` | Used to specify the documents for inclusion in the workflow. |
| `description` | The document workflow description. |
| `variable` | The variable prompts which accept values when initiating the workflow. |

For each control, the following data may be returned:

| Name | Description |
| --- | --- |
| `label` | UI Label for the control. |
| `type` | Type of control (`instructions`, `participant`, `date`, `documents`, `description`, or `variable`). |

Additionally, the response includes following fields describing the workflow:

| Name | Description |
| --- | --- |
| `name` | The workflow name. |
| `label` | UI Label for the workflow. |
| `type` | Type of workflow (`multidocworkflow`). |
| `cardinality` | Indicates how many contents (`One`, `OneOrMany`) can be included in a workflow. |
