<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-workflows/retrieve-all-document-workflows/ -->
<!-- title: Retrieve All Document Workflows -->

# Retrieve All Document Workflows

Retrieve all available document workflows that can be initiated on a set of documents which:

* The authenticated user has permissions to view or initiate
* Can be initiated through the API

GET`/api/{version}/objects/documents/actions`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `loc` | When localized (translated) strings are available, retrieve them by setting `loc` to `true`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/actions
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": [
       {
           "name": "Objectworkflow.clinical_study_report_approval__c",
           "label": "Clinical Study Report Approval",
           "type": "multidocworkflow",
           "cardinality": "OneOrMany"
       },
       {
           "name": "Objectworkflow.medical_docs_review_and_approval__c",
           "label": "Medical Docs Review and Approval",
           "type": "multidocworkflow",
           "cardinality": "OneOrMany"
       }
   ]
}
```

## Response Details

On `SUCCESS`, the response lists all available document workflows and includes the following:

| Name | Description |
| --- | --- |
| `name` | The workflow name. |
| `label` | UI Label for the workflow. |
| `type` | Type of workflow. |
| `cardinality` | Indicates how many contents (`One`, `OneOrMany`) can be included in a workflow. |

For users without the *Workflow: Start* permission, the response returns an `INSUFFICIENT_ACCESS` error.
