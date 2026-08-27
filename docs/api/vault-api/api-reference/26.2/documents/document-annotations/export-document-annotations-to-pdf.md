<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/export-document-annotations-to-pdf/ -->
<!-- title: Export Document Annotations to PDF -->

# Export Document Annotations to PDF

Export the latest version of any document, along with its annotations, as an annotated PDF. This is equivalent to the *Export Annotations* action in the Vault document viewer UI. You can then view annotations, reply to existing annotations, and create new annotations in a [supported PDF editor](https://platform.veevavault.help/en/gr/23833#supported-pdf-editors). When finished, you can import your new notes and replies to Vault using the [Import Document Annotations from PDF](/vault-api/api-reference/26.2/documents/document-annotations/import-document-annotations-from-pdf) endpoint.

You must have *View Content* permission on the latest document version and a security profile that grants the *Document: Download Rendition* permission to export annotations.

GET`/api/{version}/objects/documents/{doc_id}/annotations/file`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Response

On `SUCCESS`, Vault retrieves the specified version document rendition and its associated annotations in PDF format.

* The HTTP Response Header `Content-Type` is set to `application/pdf`.
* The HTTP Response Header `Content-Disposition` contains a `filename` component which is used as the default name for the local file.

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/14/annotations/file
```
