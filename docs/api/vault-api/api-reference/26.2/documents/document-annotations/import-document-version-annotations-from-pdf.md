<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/import-document-version-annotations-from-pdf/ -->
<!-- title: Import Document Version Annotations from PDF -->

# Import Document Version Annotations from PDF

Load annotations from a PDF to Vault. This is equivalent to the *Import Annotations* action in the Vault document viewer UI. The file must be a PDF created by exporting annotations for the specified version of the same document through either the *Export Annotations* action in the Vault UI or the [Export Document Version Annotations as PDF](/vault-api/api-reference/26.2/documents/document-annotations/export-document-version-annotations-to-pdf) endpoint. You must have a role on the document that includes the *Annotate* permission.

POST`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/annotations/file`

#### File Upload

To upload the file, use the multi-part attachment with the file component `"file={file_name}"`. The maximum allowed file size is 4GB. Vault truncates annotations that exceed the following character limits:

* **Note annotations**: *Subject* (in Header) limited to 32,000 characters
* **Note, Line, and Reply annotations**: *Comment* limited to 32,000 characters

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{major_version}` | The document `major_version_number__v` field value. |
| `{minor_version}` | The document `minor_version_number__v` field value. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "file=document2016.pdf" \
https://myvault.veevavault.com/api/v26.2/objects/documents/548/versions/2/1/annotations/file
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "OK",
    "replies": 0,
    "failures": 0,
    "new": 0
}
```

## Response Details

On `SUCCESS`, Vault uploads the file and its annotations.
