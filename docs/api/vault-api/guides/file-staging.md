<!-- source: https://general.veevavault.dev/vault-api/guides/file-staging/ -->
<!-- title: File Staging -->

# File Staging

Each Vault in your domain has its own file staging which you can access using [Vault API](/vault-api/api-reference/26.2/file-staging). You can use this as a temporary storage area for files you're loading. Vault also uses it to store extracted files.

Before loading any input that references a file, you must upload the file to file staging via API. These files can include source files and renditions for documents. For example, before loading documents with the [Create Multiple Documents API](/vault-api/api-reference/26.2/documents/create-documents/create-multiple-documents), you must first load the document source files to file staging using either the [Create Folder or File API](/vault-api/api-reference/26.2/file-staging/create-folder-or-file) (files up to 50 MB) or a [Resumable Upload Session](/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions) (files over 50 MB).

Note

Vault automatically deletes uploaded files on the staging server after one year. Deleted files are not recoverable. To display files using the File Staging API, see [List Items at a Path in the Vault API Reference](/vault-api/api-reference/26.2/file-staging/list-items-at-a-path).

## File Staging Permissions

Uploading to or downloading from file staging requires a security profile with the *File Staging: Access* and *API: Access API* permissions. Only the standard Vault Owner and System Admin profiles include this by default, but Admins can add this permission to other profiles.

Note

Vault does not support the ability for cross-domain users to access file staging on a cross-domain Vault. This applies even to members of cross-domain Vaults that can log in via the UI.

## How to Connect to File Staging

As of v20.3+, all new integrations should use Vault API to upload and manage files and folders on your Vault's file staging. See [file staging in the Vault API Reference](/vault-api/api-reference/26.2/file-staging) for details.

To connect legacy implementations, see [How to Connect Legacy Implementations via FTP](/vault-api/guides/file-staging/legacyftp/).
