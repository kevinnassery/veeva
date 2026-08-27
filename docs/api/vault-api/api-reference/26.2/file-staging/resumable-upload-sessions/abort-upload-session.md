<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/abort-upload-session/ -->
<!-- title: Abort Upload Session -->

# Abort Upload Session

Abort an active upload session and purge all uploaded file parts. Admin users can see and abort all upload sessions, while non-Admin users can only see and abort sessions where they are the owner.

DELETE`/api/{version}/services/file_staging/upload/{upload_session_id}`

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
curl -L -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H "Accept: application/json" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/upload/TpE_3roGfhpCppmk9ltKaEAbb8.kWbZEe6xDuW3lNa42801RbIEPJaWG07xvwrITJgVmXDw3UVL1w--
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS"
}
```
