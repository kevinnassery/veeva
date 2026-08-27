<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/export-attachment-field-files/ -->
<!-- title: Export Attachment Field Files -->

# Export Attachment Field Files

Export all *Attachment* field files in bulk from the specified object records. This endpoint starts a job to create a `tar.gz` export file for later retrieval.
When the job has completed:

* Use [Retrieve Attachment Field Files Export Results](/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/retrieve-attachment-field-files-export-results) to retrieve the job results and name of the export file.
* Use [Download Attachment Field Files Export](/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/download-attachment-field-files-export) to download the export file.

POST`/api/{version}/vobjects/{object_name}/attachment_fields/actions/export`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `field_names` | A comma-separated list of *Attachment* field names from which to retrieve attached files. If omitted, retrieves files from all *Attachment* fields on the object. |
| `idParam` | If you’re identifying attachments in your input by a unique field, add `idParam={fieldname}` to the request endpoint. You can use any object field with `unique` set to `true` in the object metadata, with the exception of picklists. For example, `idParam=external_id__v`. |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The `name` of the object from which to retrieve *Attachment* field files. |

## Body Parameters

Include up to 500 object records as JSON or CSV.

| Name | Description |
| --- | --- |
| `id` conditional | The ID of the record from which to retrieve *Attachment* field files. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `{fieldname}` conditional | The unique field name to use instead of the `id`. You must also add the `idParam` query parameter, such as `idParam=external_id__v`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/attachment_fields/actions/export?field_names=attachments__c' \
--data ''[
    {
        "id": "00P000000000201"
    },
    {
        "id": "00P000000000202"
    }
]'
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "records": [
            {
                "responseStatus": "WARNING",
                "warnings": [
                    {
                        "warning_type": "INVALID_DATA",
                        "message": "No attachment field values found for resource [00P000000000201]"
                    }
                ]
            },
            {
                "responseStatus": "SUCCESS",
                "data": {
                    "id": "00P000000000202",
                    "id_param_value": "00P000000000202"
                }
            }
        ],
        "job_id": 1069401
    }
}
```

## Response Details

This endpoint generates a job request. If the job runs for more than 23 hours, the job request terminates. Vault skips this job if there are no *Attachment* field files on the requested records or if all of the request data is invalid. Use the [Retrieve Job Status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) endpoint to monitor the job.

On `SUCCESS`, the response includes the following metadata:

| Name | Description |
| --- | --- |
| `job_id` | The job’s ID. |
| `records` | A list of the records from which to export *Attachment* field files and their `responseStatus`. |
