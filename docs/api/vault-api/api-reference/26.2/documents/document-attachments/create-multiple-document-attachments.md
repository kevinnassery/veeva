<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/create-multiple-document-attachments/ -->
<!-- title: Create Multiple Document Attachments -->

# Create Multiple Document Attachments

Create multiple document attachments in bulk with a JSON or CSV input file. You must first load the attachments to [file staging](/vault-api/guides/file-staging). This works for version-specific attachments and attachments at the document level. If the attachment already exists, Vault uploads the attachment as a new version of the existing attachment. Learn more about [attachment versioning in Vault Help](https://platform.veevavault.help/en/gr/24287#version-specific).

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

POST`/api/{version}/objects/documents/attachments/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` or `application/xml` |

## Body Parameters

Prepare a CSV or JSON input file.

| Name | Description |
| --- | --- |
| `document_id__v` required | The document ID to add this attachment. |
| `filename__v` required | The name for the new attachment. This name must include the file extension, for example, `MyAttachment.pdf`. If an attachment with this name already exists, this attachment is added as a new version. |
| `file` required | The filepath of the attachment on file staging. |
| `description__v` optional | Description of the attachment. Maximum 1000 characters. |
| `major_version_number__v` optional | The major version of the source document. |
| `minor_version_number__v` optional | The minor version of the source document. |
| `external_id__v` optional | Set an external ID value on the attachment. |

[Download Input File](/sample-files/bulk-create-document-attachments.json)

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
-H "Accept: text/csv" \
--data-raw '[
    {
        "document_id__v": "5",
        "filename__v": "CholecapBrochure.docx",
        "file": "u108803/CholecapBrochure.docx"
    }
]' \
https://myvault.veevavault.com/api/v26.2/objects/documents/attachments/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 39,
            "version": 1
        }
    ]
}
```

## Response Details

On `SUCCESS`, returns the ID and version of new attachments. Attachments created unsuccessfully are reported with an error message.
