<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/list-items-at-a-path/ -->
<!-- title: List Items at a Path -->

# List Items at a Path

Return a list of files and folders for the specified path. Paths are different for Admin users (Vault Owners and System Admins) and non-Admin users. Learn more about [paths in the Vault API Documentation](/vault-api/guides/file-staging/about-paths).

GET`/api/{version}/services/file_staging/items/{item}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `item` | The absolute path to a file or folder. This path is specific to the authenticated user. Admin users can access the root directory. All other users can only access their own user directory. |

## Query Parameters

| Name | Description |
| --- | --- |
| `recursive` | If `true`, the response will contain the contents of all subfolders. If not specified, the default value is `false`. |
| `limit` | Optional: The maximum number of items per page in the response. This can be any value between 1 and 1000. If omitted, the default value is 1000. |
| `format_result` | If set to `csv`, the response includes a `job_id`. Use the Job ID value to retrieve the [status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) and results of the request. |

## Request

Copy to clipboard

```
curl -L -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/items/Cholecap?recursive=true&limit=2
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "next_page": "https://myvault.veevavault.com/api/v26.2/services/file_staging/items?cursor=g8qOy3WDCd84tyi%2Bx6KQCA%3D%3D%3AWjeuCSM6tbtmhJ00VpjHMlimit=2&recursive=true"
   },
   "data": [
       {
           "kind": "folder",
           "path": "/Cholecap-References",
           "name": "Cholecap-References"
       },
       {
           "kind": "file",
           "path": "/Cholecap-References/cholecap-akathisia",
           "name": "cholecap-akathisia",
           "size": 35642,
           "modified_date": "2020-10-07T16:28:38.000Z"
       }
   ]
```

## Response Details

On `SUCCESS`, the response includes the following information:

| Name | Description |
| --- | --- |
| `kind` | The kind of item. This can be either `file` or `folder`. |
| `path` | The absolute path, including file or folder `name`, to the item on file staging. |
| `name` | The name of the file or folder. |
| `size` | The size of the file in bytes. Not applicable to folders. |
| `modified_date` | The timestamp of when the file was last modified. Not applicable to folders. |
| `next_page` | The pagination URL to navigate to the next page of results if the number of results exceeds the number defined by a request’s `limit`. This URL contains a `cursor` query parameter, which is valid for 30 minutes from the time of the original query. |
| `item` | The path root for the query. Included in responses where `format_result = csv`. |
