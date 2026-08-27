<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/ -->
<!-- title: Resumable Upload Sessions -->

# Resumable Upload Sessions

Use resumable upload sessions to upload files larger than 50MB to file staging in three steps:

1. **Create Resumable Upload Session**: Generate an `upload_session_id`, which you can use to upload file parts, resume an interrupted session, retrieve information about a session, and, if necessary, abort a session.
2. **Upload File Parts**: Use the `upload_session_id` from step 1 to upload parts of a file to an upload session. File parts can be from 5-50MB by default, although limits for your Vault may vary.
3. **Commit Upload Session**: After you upload all file parts, use this endpoint to end the session and make the completed, reassembled file available in file staging.

Use the additional helper endpoints in this section to manage upload sessions. Each Vault allows up to 50 active upload sessions at a time. By default, upload sessions remain active for 72 hours after creation. If a session expires before it is committed, Vault will auto-purge all parts of the upload.
