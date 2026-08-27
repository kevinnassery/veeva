<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-loader/multi-file-extract/retrieve-loader-extract-renditions-results/ -->
<!-- title: Retrieve Loader Extract Renditions Results -->

# Retrieve Loader Extract Renditions Results

After submitting a request to extract object types from your Vault, you can query Vault to retrieve results of a specified job task that includes renditions requested with documents.

GET`/api/{version}/services/loader/{job_id}/tasks/{task_id}/results/renditions`

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
https://myvault.veevavault.com/api/v26.2/services/loader/61907/tasks/1/results/renditions
```

## Response

Copy to clipboard

```
file,rendition_type__v,id,name__v,type__v
/61915/50/0_1/renditions/viewable_rendition__v.pdf,viewable_rendition__v,50,Facts about High Cholesterol Spring 2016,Promotional Material
/61915/8/0_1/renditions/viewable_rendition__v.pdf,viewable_rendition__v,8,ashley-harvey,Personnel
```

## Response Details

On `SUCCESS`, the response includes CSV output containing paths to rendition files for documents or document versions on your Vault's file staging. When an export includes multiple rendition types for a document or document version, the CSV output includes a separate row for each rendition type.
