<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-single-submission/ -->
<!-- title: Export Single Submission -->

# Export Single Submission

Use the following request to asynchronously export the latest version of a *Submission*.

You can export submissions with the following *Dossier Status* values:

* *Import Successful*
* *Publishing Active*
* *Publishing Inactive*
* *Transmission Failed*
* *Transmission Successful*
* *Transmission in Queue*
* *Transmission in Progress*

POST`/api/{version}/app/regulatory/submissions_archive/{submission_record_id}/actions/export`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{submission_record_id}` | The system-managed ID for the specific *Submission* record you want to export. For example, `00S00000000M001`. |

## Query Parameters

| Name | Description |
| --- | --- |
| `format` | Specifies the export package format. If omitted, the default value is `zip`. Valid values: `zip`, `tgz` (tar.gz) |
| `exclude_app_correspondence` | Set to `true` to specifically omit *Application*-level correspondence. If omitted, the default value is `false`. |
| `exclude_sub_correspondence` | Set to `true` to specifically omit *Submission*-level correspondence. If omitted, the default value is `false`. |

Note

There is a known issue in Vault API v26.2 where setting only one of the `exclude_app_correspondence` and `exclude_sub_correspondence` parameters to `true` while the other is `false` or `null` still returns all correspondence. Setting both parameters to `true` excludes all correspondence.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/app/regulatory/submissions_archive/00S000000003002/actions/export
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Export from Submissions Archive initiated. You will receive a Vault notification when the export is complete.",
    "data": {
        "job_id": "417901",
        "url": "https://myvault.veevavault.com/api/v26.2/app/regulatory/submissions_archive/export_job/417901"
    }
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

* `job_id` - The unique ID assigned to the asynchronous export job in Vault. Use this to track the progress.
* `url` - The specific API endpoint URL used to query the status and retrieve the results of the running job.
