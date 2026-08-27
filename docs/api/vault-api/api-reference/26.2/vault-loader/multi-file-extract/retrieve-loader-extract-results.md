<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-loader/multi-file-extract/retrieve-loader-extract-results/ -->
<!-- title: Retrieve Loader Extract Results -->

# Retrieve Loader Extract Results

After submitting a request to extract data files from your Vault, you can query Vault to retrieve the results of a specified job task.

GET`/api/{version}/services/loader/{job_id}/tasks/{task_id}/results`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `text/csv` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `job_id` | The `id` value of the requested extract job. Obtain this from the [Extract Data Files](/vault-api/api-reference/26.2/vault-loader/multi-file-extract/extract-data-files) request. |
| `task_id` | The `id` value of the requested extract task. Obtain this from the [Extract Data Files](/vault-api/api-reference/26.2/vault-loader/multi-file-extract/extract-data-files) request. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/services/loader/61907/tasks/2/results
```

## Response

Copy to clipboard

```
file,rendition_type__v,id,name__v,type__v
/61915/50/0_1/renditions/viewable_rendition__v.pdf,viewable_rendition__v,50,Facts about High Cholesterol Spring 2016,Promotional Material
/61915/8/0_1/renditions/viewable_rendition__v.pdf,viewable_rendition__v,8,ashley-harvey,Personnel
```

## Response Details

On `SUCCESS`:

* If the Loader job task was successful, the response includes CSV output containing the results of a specific extract job task.
* If the Loader job task was unsuccessful, the response is blank. To view the failure log, log into your Vault, go to **Admin > Operations > Job Status**, and select the Job ID from the History section.

If the extract includes document or document version renditions, the CSV output contains paths to rendition files on your Vault's file staging. When an export includes multiple rendition types for a document or document version, the CSV output includes a separate row for each rendition type.
