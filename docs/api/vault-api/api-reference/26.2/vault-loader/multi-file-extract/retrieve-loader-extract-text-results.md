<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-loader/multi-file-extract/retrieve-loader-extract-text-results/ -->
<!-- title: Retrieve Loader Extract Text Results -->

# Retrieve Loader Extract Text Results

After submitting a request to extract object types from your Vault, you can query Vault to retrieve results of a specified job task that includes text requested with documents.

GET`/api/{version}/services/loader/{job_id}/tasks/{task_id}/results/text`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `text/csv` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `job_id` | The `id` value of the requested extract job. |
| `task_id` | The `id` value of the requested extract task. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/services/loader/521601/tasks/1/results/text
```

## Response

Copy to clipboard

```
"file","rendition_type__v","id","name__v","type__v"
"/1004901/201/2_1/text/text_file.txt","","201","Cholecap Prescribing Information","General Documents"
"/1004901/301/0_3/text/text_file.txt","","301","SOP_IRB-Meeting-Prep","General Documents"
"/1004901/303/0_3/text/text_file.txt","","303","CV-HarrisMD","General Documents"
```

## Response Details

On `SUCCESS`, the response includes CSV output containing paths to text files for documents or document versions on your Vault’s file staging. When an export includes multiple rendition types for a document or document version, the CSV output includes a separate row for each rendition type.
