<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/download-controlled-copy-job-results/ -->
<!-- title: Download Controlled Copy Job Results -->

# Download Controlled Copy Job Results

Note

This endpoint is intended for use by integrations requesting and routing controlled copies of content as a system integrations account on behalf of users.

This endpoint is for Extensible Controlled Copy; `controlled_copy_trace__v` and `controlled_copy_user_input__v` objects. If your organization is not using these objects, you should use the endpoints for [Legacy Controlled Copy](/vault-api/api-reference/26.2/documents/document-events).

After initiating a controlled copy user action, use this endpoint to download the controlled copy. To execute this request in an integration flow, [Retrieve the Job Status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) and use the `href` under `"rel": "artifacts"`. We do not recommend executing this request outside of this flow.

Before submitting this request:

* You must have previously requested an initiate controlled copy job (via the API) which is no longer active
* You must be the user who initiated the job or have the *Admin: Jobs: Read* permission

GET`/api/{version}/objects/documents/actions/{lifecycle_and_state_and_action}/{job_id}/results`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml`. For this request, the `Accept` header controls only the error response. On `SUCCESS`, the response is a file stream (download). |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{lifecycle_and_state_and_action}` | The `name__v` values for the lifecycle, state, and action in the format `{lifecycle_name}.{state_name}.{action_name}`. To get this value, [Retrieve the Job Status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) and find the `href` under `"rel": "artifacts"`. |
| `{job_id}` | The ID of the job, returned from the original job request. For controlled copy, you can find this ID in the [Initiate User Action](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/initiate-document-user-action) response. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/actions/draft_to_effective_lifecycle__c.effective__c.downloadControlledCopya95fbf38/39303/results
  -OJ
```

## Response

Copy to clipboard

```
Content-Type: application/octet-stream;charset=UTF-8
Content-Disposition: attachment;filename="Download Issued Batch Record - 2018-10-10T22-01-18.473Z.zip"
```

## Response Details

On `SUCCESS`, Vault downloads your controlled copy.

The HTTP Response Header `Content-Type` is set to `application/octet-stream`. The HTTP Response Header `Content-Disposition` contains a default filename component which you can use when naming the local file.

By default, your file is named in the format `{user action label} - {now()}.zip`, which is consistent with downloading this file through the Vault UI. If you choose to name this file yourself, make sure you add the `.zip` extension.
