<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/create-folder-or-file/ -->
<!-- title: Create Folder or File -->

# Create Folder or File

Upload files or folders up to 50MB to file staging. To upload files larger than 50MB, see [Resumable Upload Sessions](/vault-api/api-reference/26.2/file-staging/resumable-upload-sessions). You can only create one file or folder per request.

POST`/api/{version}/services/file_staging/items`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |
| `Content-MD5` | Optional: The MD5 checksum of the file being uploaded. |

## Body Parameters

| Name | Description |
| --- | --- |
| `kind` required | The kind of item to create. This can be either `file` or `folder`. |
| `path` required | The absolute path, including file or folder name, to place the item in file staging. This path is specific to the authenticated user. Admin users can access the root directory. All other users can only access their own user directory. |
| `overwrite` optional | If set to `true`, Vault will overwrite any existing files with the same name at the specified destination. For folders, this is always `false`. |

#### File Upload

To upload a file, use the multi-part attachment with the file component `"file={file_name}"`. The maximum allowed file size is 50MB.

#### Uploading Files to the Inbox Directory

You can create *Staged* documents by uploading files to the *Inbox* directory on your Vault's file staging. [Learn more in Vault Help](https://platform.veevavault.help/en/gr/38653#inbox-details).

## Request: Create a File

Copy to clipboard

```
curl -L -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Accept: application/json" \
-H "Content-Type: multipart/form-data" \
-F "path=/Wonder Drug Reference.docx" \
-F "kind=file" \
-F "overwrite=true" \
-F "file=@/Wonder Drug Reference.docx"\
https://myvault.veevavault.com/api/v26.2/services/file_staging/items
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "kind": "file",
       "path": "/Wonder Drug Reference.docx",
       "name": "Wonder Drug Reference.docx",
       "size": 11922,
       "file_content_md5": "3b2130fbfa377c733532f108b5e50411"
   }
}
```

## Request: Create a Folder

Copy to clipboard

```
curl -L -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Accept: application/json" \
-H "Content-Type: multipart/form-data" \
-F "path=/u10001400/cholecap2021" \
-F "kind=folder" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/items
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "kind": "folder",
       "path": "/u10001400/cholecap2021/",
       "name": "cholecap2021"
   }
}
```
