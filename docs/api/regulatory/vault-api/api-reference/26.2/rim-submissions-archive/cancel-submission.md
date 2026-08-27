<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/cancel-submission/ -->
<!-- title: Cancel Submission -->

# Cancel Submission

You can use this request on a submission object record that has a Submissions Archive Status (`archive_status__v`) of:

| Name | Description |
| --- | --- |
| `IMPORT_IN_PROGRESS` | This will terminate the import job and set the `archive_status__v` field on the `submission__v` object record to "Error". The submission must be removed before a re-import can be done. See [Remove Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/remove-submission). |
| `REMOVAL_IN_PROGRESS` | This will terminate the import removal job and set the `archive_status__v` field on the `submission__v` object record to "Error". The submission must be removed before a re-import can be done. See [Remove Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/remove-submission). |
| `IMPORT_IN_QUEUE` | This will remove the import from the job queue and set the `archive_status__v` field on the `submission__v` object record to "Null". See [Import Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/import-submission). |
| `REMOVAL_IN_QUEUE` | This will remove the import removal from the job queue and set the `archive_status__v` field on the `submission__v` object record to "Error". See [Import Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/import-submission). |

To retrieve the `archive_status__v`,

GET`/api/{version}/vobjects/submission__v/{submission_id}`

. See [Retrieve Object Record](/regulatory/vault-api/api-reference/26.2/vault-objects/retrieve-object-record).

POST`/api/{version}/vobjects/submission__v/{submission_id}/actions/import?cancel=true`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{submission_id}` | The `id` field value of the `submission__v` object record. To get this value, [use VQL to retrieve all records](/regulatory/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) on the `submission__v` object. |

## Query Parameters

| Name | Description |
| --- | --- |
| `cancel` | You must include cancel = `true` to the request endpoint. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/submission__v/00S000000000101/actions/import?cancel=true
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS"
}
```
