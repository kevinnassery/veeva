<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-workflows/initiate-document-workflow/ -->
<!-- title: Initiate Document Workflow -->

# Initiate Document Workflow

Initiate a document workflow on a set of documents.

POST`/api/{version}/objects/documents/actions/{workflow_name}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` (default) or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{workflow_name}` | The document workflow `name` value. |

## Body Parameters

The following parameters are required, but an Admin may set other fields as required in your Vault. To find which fields are required to start this workflow, [Retrieve Document Workflow Details](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-workflows/retrieve-document-workflow-details).

| Name | Description |
| --- | --- |
| `contents__sys` required | Input a comma-separated list of document `id` field values, in the format `Document:{doc_id}`. For example, `Document:101,Document:102,Document:103`. To indicate specific document versions, use the format `DocumentVersion:{doc_version_id}`. For example, `DocumentVersion:115_0_1,DocumentVersion:116_0_2`. Maximum 100 documents. |
| `description__sys` required | Description of the workflow. Maximum 128 characters. |

##### Add Participants

To add participants to a workflow, add the name of the participant control to the body of the request. The value should be a comma-separated list of user and group IDs in the format `{user_or_group}:{id}`. For example, `approvers__c: user:123,group:234`. Use [Retrieve Document Workflow Details](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-workflows/retrieve-document-workflow-details) to get the names of all participant controls for the workflow.

# Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
-d "contents__sys: Document:501,Document:502" \
-d "description__sys: Content Approval" \
https://myvault.veevavault.com/api/v26.2/objects/documents/actions/Objectworkflow.content_document_workflow__c
```

## Response: Success

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "record_url": "/api/v26.2/vobjects/envelope__sys/0ER000000000501",
        "record_id__v": "0ER000000000501",
        "workflow_id": "1301"
    }
}
```

## Response: Failure

Copy to clipboard

```
{
    "responseStatus": "FAILURE",
    "errors": [
      {
      "type": "INVALID_DATA",
      "message": "Invalid value [501,502] for parameter [contents__sys] specified"
    }
  ]
}
```

## Response Details

If any document is not in the relevant state or does not meet configured field conditions, the API returns `INVALID_DATA` for the invalid documents and the workflow does not start.

On `SUCCESS`, the response includes the following:

| Name | Description |
| --- | --- |
| `record_id__v` | The `id` value of the `envelope__sys` record. |
| `workflow_id` | The workflow `id` field value. |

#### Manage Document Workflow Tasks

Document workflows share some of the same capabilities as object workflows and are configured on the `envelope__sys` object. You can use the [Workflow Task](/vault-api/api-reference/26.2/workflows/workflow-tasks) endpoints to retrieve document workflow tasks, task details, and initiate document workflow tasks.

#### Remove Documents from Envelope

You can remove one or more documents from an `envelope__sys` object using the `removecontent` action in the [Initiate Workflow Action](/vault-api/api-reference/26.2/workflows/initiate-workflow-action) endpoint.
