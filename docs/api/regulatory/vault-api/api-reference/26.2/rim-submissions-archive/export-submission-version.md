<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-submission-version/ -->
<!-- title: Export Submission Version (Legacy) -->

# Export Submission Version (Legacy)

Caution

This endpoint will be replaced as of the 26R3 release on December 4th, 2026. Although this endpoint will continue to work, it will no longer generate Vault Binder substructures, and instead only create the top-level Vault Binder (Submissions Archive > Structure). To ensure new submissions comply with the updated data model, use the new [Export Single Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-single-submission) or [Export Multiple Submissions](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-multiple-submissions) endpoints instead.

Use the following requests to export a specific version of a Submissions Archive binder, including submissions published by RIM Submissions Publishing. Learn more about [RIM Submissions Publishing in Vault Help](https://regulatory.veevavault.help/en/gr/48611).

You can export submissions with the following *Dossier Status* values:

* *Import Successful*
* *Publishing Active*
* *Publishing Inactive*
* *Transmission Failed*
* *Transmission Successful*
* *Transmission in Queue*
* *Transmission in Progress*

POST`/api/{version}/objects/binders/{binder_id}/versions/{major_version}/{minor_version}/actions/export?submission={submission_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{binder_id}` | The binder `id` field value. See [Retrieve Binders](/regulatory/vault-api/api-reference/26.2/binders/retrieve-binders). |
| `{major_version}` | The `major_version_number__v` field value of the binder. |
| `{minor_version}` | The `minor_version_number__v` field value of the binder. |
| `{submission_id}` | The `id` field value of the `submission__v` object record. To get this value, [use VQL to retrieve all records](/regulatory/vql/query-targets/vault-objects) on the `submission__v` object. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/binders/454/versions/0/2/actions/export?submission=00S000000000101
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Job for Binder Export Started",
    "URL": "https://myvault.veevavault.com/api/v26.2/services/jobs/1202",
    "job_id": 1202
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

* `URL` - The URL to retrieve the current status of the export job.
* `job_id` - The Job ID value is used to retrieve the [status](/regulatory/vault-api/api-reference/26.2/jobs/retrieve-job-status) and results of the request.
