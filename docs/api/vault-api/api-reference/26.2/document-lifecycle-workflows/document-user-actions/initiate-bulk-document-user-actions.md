<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-bulk-document-user-actions/ -->
<!-- title: Initiate Bulk Document User Actions -->

# Initiate Bulk Document User Actions

For each bulk action, you may only select a single workflow that Vault will start for all selected and valid documents.

PUT`/api/{version}/objects/documents/lifecycle_actions/{user_action_name}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{user_action_name}` | The user action `name__v` field value. Find this value with the [Retrieve User Actions on Multiple Documents](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/retrieve-user-actions-on-multiple-documents) endpoint. |

## Body Parameters

| Name | Description |
| --- | --- |
| `docIds` required | Include a comma-separated list of document IDs and major and minor version numbers. For example, `222:0:1,223:0:1,224:0:1` specifies version 0.1 of document IDs 222, 223, and 224. The user action is only executed on document IDs in the `lifecycle` and `state` specified in the request body. Document IDs listed in this parameter which are not in the specified `lifecycle` and `state` are skipped. |
| `lifecycle` required | Include the name of the document lifecycle. |
| `state` required | Include the current state of your document. |

#### Request Details

In this request:

* The input file format is set to accept name-value pairs.
* The lifecycle is specified. These documents are assigned to the `general_lifecycle__c`.
* The state is specified. We're changing the state of all four documents from draft to approved.

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "docIds=222:0:1,223:0:1,224:0:1,225:0:1" \
-d "lifecycle=general_lifecycle__c" \
-d "state=draft__c" \
https://myvault.veevavault.com/api/v26.2/objects/documents/lifecycle_actions/approve__c
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS"
}
```

## Response Details

On `SUCCESS`, the initiating user receives a summary email detailing which documents succeeded and failed the requested action.
