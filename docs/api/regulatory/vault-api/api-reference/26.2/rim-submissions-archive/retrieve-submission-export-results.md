<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/retrieve-submission-export-results/ -->
<!-- title: Retrieve Submission Export Results (Legacy) -->

# Retrieve Submission Export Results (Legacy)

Caution

This endpoint will be replaced as of the 26R3 release on December 4th, 2026. Although this endpoint will continue to work, it will no longer return the data array containing submission binder information after the 26R3 release. Use the new [Retrieve Submission Export Results](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/retrieve-submission-export-result) endpoint instead.

After submitting a request to export a submission from your Vault, you can query Vault to determine the results of the request.

Before submitting this request:

* You must have previously requested a submission export job (via the API) which is no longer active.
* You must have a valid `job_id` field value returned from the [Export Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-submission) request.

GET`/api/{version}/objects/binders/actions/export/{job_id}/results`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{job_id}` | The `jobId` field value returned from the [Export Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-submission) request. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/binders/actions/export/1201/results
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "job_id": 1201,
  "id": 454,
  "major_version_number__v": 1,
  "minor_version_number__v": 0,
  "file": "/1201/454/1_0/RIM Submission Packet.zip",
  "user_id__v": 44533
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

| Name | Description |
| --- | --- |
| `job_id` | The `job_id` field value of the submission export request. |
| `id` | The `id` field value of the exported submission. |
| `major_version_number__v` | The major version number of the exported submission. |
| `minor_version_number__v` | The minor version number of the exported submission. |
| `file` | The path/location of the exported submission. This is packaged in a ZIP file on file staging. |
| `user_id__v` | The `id` field value of the Vault user who initiated the submission export job. |
