<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/list-file-parts-uploaded-to-session/ -->
<!-- title: List File Parts Uploaded to Session -->

# List File Parts Uploaded to Session

Return a list of parts uploaded in a session. You must be an Admin user or the session owner.

GET`/api/{version}/services/file_staging/upload/{upload_session_id}/parts`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `upload_session_id` | The upload session ID. |

## Query Parameters

| Name | Description |
| --- | --- |
| `limit` | Optional: The maximum number of items per page in the response. This can be any value between 1 and 1000. If omitted, the default value is 1000. |

## Request

Copy to clipboard

```
curl -L -X GET -H "Authorization: {AUTH_VALUE}"\
-H "Accept: application/json" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/upload/98f46c04fa7a65ff2e5eaf90fdf613ab/parts?limit=2
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "next_page": "https://myvault.veevavault.com/api/v26.2/services/file_staging/upload/98f46c04fa7a65ff2e5eaf90fdf613ab/parts?cursor=%2BMTykDOd3PrccDRP%2F254mQ%3D%3D%3A%2BkGnLUB6M9iDNUZeJ6BgOdWKpFQ%2BC7Q0B8UHdPxfJ7U%3D&limit=2"
   },
   "data": [
       {
           "size": 5242880,
           "part_number": 1,
           "part_content_md5": "c24a2d4b1c4e03a9f4113903edac6f47"
       },
       {
           "size": 5242880,
           "part_number": 2,
           "part_content_md5": "d6762077325b9ec3b75ada3b269e17d3"
       }
   ]
}
```

## Response Details

On `SUCCESS`, the response includes the `size` and `part_number` of each file part uploaded to the session so far. If the number of parts returned exceeds 1000 or the number defined by the `limit`, Vault includes pagination links in the response.
