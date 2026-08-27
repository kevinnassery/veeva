<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/list-upload-sessions/ -->
<!-- title: List Upload Sessions -->

# List Upload Sessions

Return a list of active upload sessions.

GET`/api/{version}/services/file_staging/upload`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -L -X GET -H "Authorization: {AUTH_VALUE}" \
-H "Accept: application/json" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/upload
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": [
       {
           "path": "/u10001400/Gludacta-2021/Gludacta-Flyer.docx",
           "id": "yYFg7jN_fZBmUD9Tj98RkL2yqtbTdIh17iy02nd5pby62oqVJLXv.R.ea1jSr786rgwpf7Vx3RmmQ--",
           "expiration_date": "2020-10-10T18:32:55.000Z",
           "created_date": "2020-10-07T18:32:55.000Z",
           "last_uploaded_date": "2020-10-07T19:27:07.000Z",
           "owner": 10001400,
           "uploaded_parts": 1,
           "size": 1273267,
           "uploaded": 1273267
       },
       {
           "path": "/u10001400/Gludacta-2021/GludactaPackageBrochure.pdf",
           "id": "JEtOyUb9i.DXVbtW7xZT7jWr2rNLWtdWrV7IPCo9aILqd.k8nlNNlG3SbplEVDJulPijrFwnelJw--",
           "expiration_date": "2020-10-10T19:11:57.000Z",
           "created_date": "2020-10-07T19:11:57.000Z",
           "last_uploaded_date": "2020-10-07T19:11:57.000Z",
           "owner": 10001400,
           "uploaded_parts": 0,
           "size": 1438827,
           "uploaded": 0
       },
       {
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
        ]
}
```

## Response Details

On `SUCCESS`, Vault lists all active upload sessions for a Vault, along with their fields and field values. Admin users will see upload sessions for the entire Vault, while non-Admin users will see their own sessions only.

| Name | Description |
| --- | --- |
| `path` | The absolute path, including file name, to place the file in the staging server. This path is specific to the authenticated user. Admin users can access the root directory. All other users can only access their own user directory. |
| `id` | The upload session ID. |
| `expiration_date` | The timestamp of when the upload session will expire. |
| `created_date` | The timestamp of when the session was created. |
| `last_uploaded_date` | The timestamp of the last upload in this session. Because the session was just created, this will be the same as the `created_date`. |
| `owner` | The user ID of the Vault user who initiated the upload session. |
| `uploaded_parts` | The number of file parts uploaded so far. |
| `size` | The total size, in bytes, of the file when complete. |
| `uploaded` | The total number of bytes uploaded so far in the session. |
