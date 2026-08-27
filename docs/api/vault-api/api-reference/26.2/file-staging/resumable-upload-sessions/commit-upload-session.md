<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/commit-upload-session/ -->
<!-- title: Commit Upload Session -->

# Commit Upload Session

Mark an upload session as complete and assemble all previously uploaded parts to create a file.

POST`/api/{version}/services/file_staging/upload/{upload_session_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |
| `Content-Type` | `application/json`(default) |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `upload_session_id` | The upload session ID. |

## Request

Copy to clipboard

```
curl -L -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Accept: application/json" \
-H "Content-Type: application/json" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/upload/.lqX6rv1jbu5vABJoy5XoSZmQXTTJV_jwxO.kFuS.qISxQJDiFm0s_kfb8oRS9DBDGg--
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "job_id": 100954
   }
}
```

## Response Details

On `SUCCESS`, Vault returns the `job_id` for the commit. Use the [Job Status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) API to retrieve the job results. Upon successful completion of the job, the file will be available on the staging server.
