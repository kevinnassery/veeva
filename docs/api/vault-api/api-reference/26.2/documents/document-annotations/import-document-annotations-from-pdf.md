<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/import-document-annotations-from-pdf/ -->
<!-- title: Import Document Annotations from PDF -->

# Import Document Annotations from PDF

Load annotations from a PDF to Vault. This is equivalent to the *Import Annotations* action in the Vault document viewer UI. The file must be a PDF created by exporting annotations for the latest version of the same document through either the *Export Annotations* action in the Vault UI or the [Export Document Annotations as PDF](/vault-api/api-reference/26.2/documents/document-annotations/export-document-annotations-to-pdf) endpoint and edited in a [supported PDF editor](https://platform.veevavault.help/en/gr/23833#supported-pdf-editors). You must have a role on the document that includes the *Annotate* permission.

POST`/api/{version}/objects/documents/{doc_id}/annotations/file`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

#### File Upload

To upload the file, use the multi-part attachment with the file component `"file={file_name}"`. The maximum allowed file size is 4GB. Vault truncates annotations that exceed the following character limits:

* **Note annotations**: *Subject* (in Header) limited to 32,000 characters
* **Note, Line, and Reply annotations**: *Comment* limited to 32,000 characters

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "file=document2016.pdf" \
https://myvault.veevavault.com/api/v26.2/objects/documents/548/annotations/file
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
