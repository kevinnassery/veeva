<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/update-documents/create-single-document-version/ -->
<!-- title: Create Single Document Version -->

# Create Single Document Version

Note

If you need to create more than one document version, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/update-documents/create-multiple-document-versions).

Add a new draft version of an existing document. You can choose to either use the existing source file or a new source file. These actions increase the target document’s minor version number. This is analogous to using the *Create Draft* action in the UI.

Not all documents are eligible for draft creation, however, this endpoint does support creating a new draft version of a checked-out document. [See below](#Upload_New_Version) for details. Learn more about [creating new draft versions in Vault Help](https://platform.veevavault.help/en/gr/1560).

POST`/api/{version}/objects/documents/{doc_id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Body Parameters

| Name | Description |
| --- | --- |
| `createDraft` conditional | Choose one of the two available values:  `latestContent`: Create a new draft version from the existing document in the Vault. This does not require uploading a file. This option is only available if both the source file and rendition are each 4 GB or less. This is analogous to the **Copy file from current version** option in the *Create Draft* UI.  `uploadedContent`: Create a new draft version by uploading the document source file. This requires uploading a new source file with an additional `file` body parameter. The maximum allowed file size is 4GB. This is analogous to the **Upload a new file** option in the *Create Draft* UI.  This parameter is only required to create a new draft version from an existing document or by uploading a source file. To create a new version for a placeholder document, you must omit this parameter. |
| `file` conditional | The filepath of the source document. This parameter is only required in the following scenarios:  * If `createDraft=uploadedContent`, use this parameter to include the new document source file. * If your target document is a placeholder, use this parameter to upload a source file and create a new draft version of the document. * If your target document is currently checked out, use this parameter to upload a new version of the document source file. |
| `description__v` optional | Add a *Version Description* for the new draft version. Other users may view this description in the document’s *Version History*. Maximum 1,500 characters. |

## Query Parameters

| Name | Description |
| --- | --- |
| `suppressRendition` | Set to `true` to suppress automatic generation of the viewable rendition. If omitted, defaults to `false`. |

##### Upload New Version

When *Enable Upload New Version* is enabled by an Admin, you can upload a new version of a checked out document if you already have an updated version of the document source file available. This is analogous to using the *Upload New Version* action in the UI. To achieve this, omit the `createDraft` parameter and include the `file` parameter when sending a request to this endpoint. If the document has not yet been checked out in the UI, you can send a request to [Create Document Lock](/vault-api/api-reference/26.2/documents/document-locks/create-document-lock) to check it out. Learn more about [versioning documents in Vault Help](https://platform.veevavault.help/en/gr/162).

## Request: Copy file from current version

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "createDraft=latestContent" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534
```

## Request: Upload a new file & Suppress rendition

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "file=CholeCap-Presentation.pptx" \
-F "createDraft=uploadedContent" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534?suppressRendition=true
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseMessage": "New draft successfully created.",
  "major_version_number__v": 0,
  "minor_version_number__v": 2
}
```

## Request: Upload new version

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "file=CholeCap-Presentation.pptx" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534
```

## Response: Upload new version

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Document successfully checked in.",
    "major_version_number__v": 0,
    "minor_version_number__v": 5
}
```

## Response Details

On `SUCCESS`, Vault creates a new draft version and the response includes the document's `major_version_number__v` and `minor_version_number__v`. When you create a new draft version, Vault automatically increments the minor version number.

When uploading a new version of a checked out document, on `SUCCESS`, Vault checks in the document and creates a new draft version. The response includes the document’s `major_version_number__v` and `minor_version_number__v`.
