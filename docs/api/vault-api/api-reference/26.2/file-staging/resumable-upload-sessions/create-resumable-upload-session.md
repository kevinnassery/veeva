<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/create-resumable-upload-session/ -->
<!-- title: Create Resumable Upload Session -->

# Create Resumable Upload Session

Initiate a multipart upload session and return an upload session ID.

POST`/api/{version}/services/file_staging/upload`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

| Name | Description |
| --- | --- |
| `path` required | The absolute path, including file name, to place the file in the staging server. This path is specific to the authenticated user. Admin users can access the root directory. All other users can only access their own user directory. |
| `size` required | The size of the file in bytes. The maximum file size is 500GB. |
| `overwrite` optional | If set to `true`, Vault will overwrite any existing files with the same name at the specified destination. |

## Request

Copy to clipboard

```
curl -L -X POST -H "Authorization: {AUTH_VALUE}" \
-H 'Accept: application/json' \
-H 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'path=Cholecap-Commercial-2021.mp4' \
--data-urlencode 'size=32862312' \
--data-urlencode 'overwrite=true'\
https://myvault.veevavault.com/api/v26.2/services/file_staging/upload
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "path": "/Cholecap-Commercial-2021.mp4",
        "name": "Cholecap-Commercial-2021.mp4",
        "id": "31a6aba21bf6e0005b718407a78739e6",
        "expiration_date": "2020-12-14T23:30:43.000Z",
        "created_date": "2020-12-11T23:30:43.000Z",
        "last_uploaded_date": "2020-12-11T23:30:43.000Z",
        "owner": 275657,
        "uploaded_parts": 0,
        "size": 32862312,
        "uploaded": 0,
        "overwrite": true
    }
}
```

## Response Details

Upon SUCCESS, the response includes the following information:

| Name | Description |
| --- | --- |
| `path` | The path to the file as specified in the request. |
| `id` | The upload session ID. |
| `expiration_date` | The timestamp of when the upload session will expire. |
| `created_date` | The timestamp of when the session was created. |
| `last_uploaded_date` | The timestamp of the last upload in this session. Because the session was just created, this will be the same as the `created_date`. |
| `owner` | The user ID of the Vault user who initiated the upload session. |
| `uploaded_parts` | The number of parts uploaded to the session so far. Because the session was just created, this will be 0. |
| `size` | The size of the file in bytes as specified in the request. |
| `uploaded` | The total size, in bytes, uploaded so far in the session. Because the session was just created, this will be 0. |
