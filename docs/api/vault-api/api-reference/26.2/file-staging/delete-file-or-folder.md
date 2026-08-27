<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/delete-file-or-folder/ -->
<!-- title: Delete File or Folder -->

# Delete File or Folder

Delete an individual file or folder from file staging.

DELETE`/api/{version}/services/file_staging/items/{item}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `item` | The absolute path to the file or folder to delete. This path is specific to the authenticated user. Admin users can access the root directory. All other users can only access their own user directory. |

## Query Parameters

| Name | Description |
| --- | --- |
| `recursive` | Applicable to deleting folders only. If `true`, the request will delete the contents of a folder and all subfolders. The default is `false`. |

## Request

Copy to clipboard

```
curl -L -X DELETE -H "Authorization:{SESSION_ID}"" \
-H "Accept: application/json" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/items/u10001400/promotional2021?recursive=true
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "job_id": 100953,
       "url": "/api/v26.2/services/jobs/100953"
   }
}
```

## Response Details

On `SUCCESS`, the response contains the following information:

| Name | Description |
| --- | --- |
| `job_id` | The Job ID value to retrieve the status and results of the request. |
| `url` | URL to retrieve the current job status of this request. |

#### Deleting Files in the Inbox Directory

Deleting files from your Vault's *Inbox* directory does not delete corresponding *Staged* documents Vault created when the files were uploaded. [Learn more in Vault Help](https://platform.veevavault.help/en/gr/38653#inbox-details).
