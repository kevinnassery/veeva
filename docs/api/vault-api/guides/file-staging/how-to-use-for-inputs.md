<!-- source: https://general.veevavault.dev/vault-api/guides/file-staging/how-to-use-for-inputs/ -->
<!-- title: How to Use File Staging for Inputs -->

# How to Use File Staging for Inputs

Bulk creation APIs such as [Create Multiple Documents](/vault-api/api-reference/26.2/documents/create-documents/create-multiple-documents), [Create Multiple Object Record Attachments](/vault-api/api-reference/26.2/vault-objects/object-record-attachments/create-multiple-object-record-attachments), and [Add Multiple Document Renditions](/vault-api/api-reference/26.2/documents/document-renditions/add-multiple-document-renditions) require a JSON or CSV input file that includes references to source files on file staging.

To reference files:

* Use the [Create Folder or File](/vault-api/api-reference/26.2/file-staging/create-folder-or-file) and [Update Folder or File](/vault-api/api-reference/26.2/file-staging/update-folder-or-file) APIs to create, rename, and move subdirectories as desired in your file staging.
* Upload files using either the [Create Folder or File](/vault-api/api-reference/26.2/file-staging/create-folder-or-file) API (files up to 50MB) or a [Resumable Upload Session](/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions/create-resumable-upload-session) (files over 50 MB).
* Add the `file` column to your input and enter the path/name of each file relative to the root, for example, `Feb-2016-Batch/Gludacta_Brochure.pdf`.

## How to Create Staged Documents

Each user's root directory has an *Inbox* directory located at `/u{user_id}/Inbox` (*Vault Owner* or *System Admin*) or `/Inbox` (non-Admins). For each file you upload to an *Inbox* directory, Vault creates a *Staged* document. Learn more about [*Staged* documents in Vault Help](https://platform.veevavault.help/en/gr/38653).
