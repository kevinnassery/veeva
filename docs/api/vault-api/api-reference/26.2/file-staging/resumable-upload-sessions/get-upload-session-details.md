<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/get-upload-session-details/ -->
<!-- title: Get Upload Session Details -->

# Get Upload Session Details

Retrieve the details of an active upload session. Admin users can get details for all sessions, while non-Admin users can only get details for sessions if they are the owner.

GET`/api/{version}/services/file_staging/upload/{upload_session_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `upload_session_id` | The upload session ID. |

## Request

Copy to clipboard

```
curl -L -X GET -H "Authorization: {AUTH_VALUE}"\
-H "Accept: application/json" \
https://myvault.veevevault.com/api/v26.2/services/file_staging/upload/TpE_3roGfhpCppmk9ltKaEAbb8.kWbZEe6xDuW3lNa42801RbIEPJaWG07xvwrITJgVmXDw3UVL1w--
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "path": "/u10001400/cholecap-2021/Cholecap-Commercial-2021.mp4",
       "id": "TpE_3roGfhpCppmk9ltKaEAbb8.kWbZEe6xDuW3lNa42801RbIEPJaWG07xvwrITJgVmXDw3UVL1w--",
       "expiration_date": "2020-10-10T19:30:18.000Z",
       "created_date": "2020-10-07T19:30:18.000Z",
       "last_uploaded_date": "2020-10-07T19:38:29.000Z",
       "owner": 10001400,
       "uploaded_parts": 2,
       "size": 32862312,
       "uploaded": 10485760
   }
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

| Name | Description |
| --- | --- |
| `path` | The absolute path, including file name, to place the file in the staging server. This path is specific to the authenticated user. Admin users can access the root directory. All other users can only access their own user directory. |
| `id` | The upload session ID. |
| `expiration_date` | The timestamp of when the upload session will expire. |
| `created_date` | The timestamp of when the session was created. |
| `last_uploaded_date` | The timestamp of the last upload in this session. |
| `owner` | The user ID of the Vault user who initiated the upload session. |
| `uploaded_parts` | The total number of file parts uploaded so far. |
| `size` | The total size, in bytes, of the file when complete. |
| `uploaded` | The total number of bytes uploaded so far in the session. |
