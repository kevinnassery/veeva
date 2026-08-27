<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/update-folder-or-file/ -->
<!-- title: Update Folder or File -->

# Update Folder or File

Move or rename a folder or file on file staging. You can move and rename an item in the same request.

PUT`/api/{version}/services/file_staging/items/{item}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `item` | The absolute path to a file or folder. This path is specific to the authenticated user. Admin users can access the root directory. All other users can only access their own user directory. |

## Body Parameters

At least one of the following parameters is required:

| Name | Description |
| --- | --- |
| `parent` conditional | When moving a file or folder, specifies the absolute path to the parent directory in which to place the file. |
| `name` conditional | When renaming a file or folder, specifies the new name. |

## Request

Copy to clipboard

```
curl -L -X PUT -H "Authorization: {AUTH_VALUE}"\
-H "Content-Type: application/x-www-form-urlencoded" \
--data-urlencode "parent=/u10001400/cholecap-2021" \
--data-urlencode "name=cholecap-2021-brochure" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/items/Cholecap-References/cholecap-brochure
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "job_id": 100949,
       "url": "/api/v26.2/services/jobs/100949"
   }
}
```

## Response Details

On `SUCCESS`, the response contains the following information:

| Name | Description |
| --- | --- |
| `job_id` | The Job ID value to retrieve the status and results of the request. |
| `url` | URL to retrieve the current job status of this request. |

#### Updating Files in the Inbox Directory

Renaming a file in your Vault's *Inbox* directory creates a new *Staged* document in your Vault and does not rename, remove, or update the previously created corresponding *Staged* document. [Learn more in Vault Help](https://platform.veevavault.help/en/gr/38653#inbox-details).
