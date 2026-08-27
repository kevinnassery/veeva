<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/upload-to-a-session/ -->
<!-- title: Upload to a Session -->

# Upload to a Session

The session owner can upload parts of a file to an active upload session. By default, you can upload up to 9616 parts per upload session, and each part can be up to 52MB. Use the `Range` header to specify the range of bytes for each upload, or split files into parts and add each part as a separate file. Each part must be the same size, except for the last part in the upload session.

PUT`/api/{version}/services/file_staging/upload/{upload_session_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |
| `Content-Type` | `application/octet-stream` |
| `Content-Length` | The size of the file part in bytes. Parts must be at least 5MB in size, except for the last part uploaded in a session. |
| `Content-MD5` | Optional: The MD5 checksum of the file part being uploaded. |
| `X-VaultAPI-FilePartNumber` | The part number, which uniquely identifies a file part and defines its position within the file as a whole. This can be any value between `1` and `9616`. If a part is uploaded using a part number that has already been used, Vault overwrites the previously uploaded file part. You must upload parts in numerical order. For example, you cannot upload part 3 without first uploading parts 1 and 2. |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `upload_session_id` | The upload session ID. |

## Request

Copy to clipboard

```
curl -L -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Accept: application/json" \
-H "Content-Type: application/octet-stream" \
-H "Content-Length: 5242880" \
-H "X-VaultAPI-FilePartNumber: 2" \
--data-binary "@/chunk-ab." \
https://myvault.veevavault.com/api/v26.2/services/file_staging/upload/.lqX6rv1jbu5vABJoy5XoSZmQXTTJV_jwxO.kFuS.qISxQJDiFm0s_kfb8oRS9DBDGg--
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "size": 5242880,
       "part_number": 2,
       "part_content_md5": "d6762077325b9ec3b75ada3b269e17d3"
   }
}
```

## Response Details

Upon `SUCCESS`, the response includes the `size`, `part_number`, and `part_content_MD5` for the file part.
