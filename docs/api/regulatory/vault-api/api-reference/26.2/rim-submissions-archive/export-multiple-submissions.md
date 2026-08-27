<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-multiple-submissions/ -->
<!-- title: Export Multiple Submissions -->

# Export Multiple Submissions

Use the following request to asynchronously export the latest versions of multiple *Submissions* across multiple *Applications* in a single call.

You can export submissions with the following *Dossier Status* values:

* *Import Successful*
* *Publishing Active*
* *Publishing Inactive*
* *Transmission Failed*
* *Transmission Successful*
* *Transmission in Queue*
* *Transmission in Progress*

POST`/api/{version}/app/regulatory/submissions_archive/actions/bulk_export`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `text/csv` |
| `Content-Type` | `application/json` (default) or `text/csv` |

## Body Parameters

Prepare a JSON or CSV input file with the following body parameters:

| Name | Description |
| --- | --- |
| `applications` required | Contains all parent *Application* ID values. |
| `applications[].application__v` required | The system-managed ID value for an *Application* in Veeva RIM. For example, `00A000000002001`. |
| `applications[].submissions` optional | Contains an array of specific *Submission* ID values within a given *Application*. If an empty array is provided, the system exports the entire *Application*. |
| `applications[].submissions[].submission__v` optional | The system-managed ID value for a *Submission*. For example, `00S00000000R003`. If omitted, the entire *Application* is exported. |
| `exclude_app_correspondence` optional | Set to `true` to omit *Application*-level correspondence. If omitted, the default value is `false`. |
| `exclude_sub_correspondence` optional | Set to `true` to omit *Submission*-level correspondence. If omitted, the default value is `false`. |

[Download Sample CSV](/sample-files/export-multiple-submissions.csv)
[Download Sample JSON](/sample-files/export-multiple-submissions.json)

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
--data-binary '@/path/to/bulk-export-submissions.csv' \
https://myvault.veevavault.com/api/v26.2/app/regulatory/submissions_archive/actions/bulk_export
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Export from Submissions Archive initiated. You will receive a Vault notification when the export is complete.",
    "data": {
        "job_id": "418101",
        "url": "https://myvault.veevavault.com/api/v26.2/app/regulatory/submissions_archive/export_job/418101"
    }
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

* `job_id` - The unique ID assigned to the asynchronous export job in Vault. Use this to track the progress.
* `url` - The specific API endpoint URL used to query the status and retrieve the results of the running job.
