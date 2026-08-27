<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-partial-submission/ -->
<!-- title: Export Partial Submission (Legacy) -->

# Export Partial Submission (Legacy)

Caution

This endpoint will be replaced as of the 26R3 release on December 4th, 2026. Although this endpoint will continue to work, it will no longer generate Vault Binder substructures, and instead only create the top-level Vault Binder (Submissions Archive > Structure). To ensure new submissions comply with the updated data model, use the new [Export Single Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-single-submission) or [Export Multiple Submissions](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-multiple-submissions) endpoints instead.

Use this request to export only specific sections and documents from the latest version of a submissions binder in your Vault. This will export only parts of the binder, not the complete binder. Exporting a binder section node will automatically include all of its subsections and documents therein.

Before submitting this request:

* The Export Binder feature must be enabled in your Vault.
* You must be assigned permissions to use the API.
* You must have the *Export Binder* permission.
* You must have the *View Document* permission for the binder. Only documents in the binder which you have the *View Document* permission are available to export.

To export the latest version of a submissions binder:

POST`/api/{version}/objects/binders/{binder_id}/actions/export?submission={submission_id}`

To export a specific version of a submissions binder:

POST`/api/{version}/objects/binders/{binder_id}/versions/{major_version}/{minor_version}/actions/export?submission={submission_id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{binder_id}` | The binder `id` field value. See [Retrieve Binders](/regulatory/vault-api/api-reference/26.2/binders/retrieve-binders). |
| `{major_version}` | The `major_version_number__v` field value of the binder. |
| `{minor_version}` | The `minor_version_number__v` field value of the binder. |
| `{submission_id}` | The `id` field value of the `submission__v` object record. To get this value, [use VQL to retrieve all records](/regulatory/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) on the `submission__v` object. |

#### Body

Create a CSV or JSON input file with the `id` values of the binder sections and/or documents to be exported. You may include any number of valid nodes. Vault will ignore `id` values which are invalid.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
--data-raw 'id
2101
2102
2103' \
https://myvault.veevavault.com/api/v26.2/objects/binders/454/1/0/actions/export?submission=00S000000000101
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "URL": "https://myvault.veevavault.com/api/v26.2/services/jobs/1201",
  "job_id": 1201
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

* `URL` - The URL to retrieve the current status of the export job.
* `job_id` - The `job_id` field value is used to retrieve the [results](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/retrieve-submission-export-results) of the export request.
