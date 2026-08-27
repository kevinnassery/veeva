<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/update-multiple-document-attachment-descriptions/ -->
<!-- title: Update Multiple Document Attachment Descriptions -->

# Update Multiple Document Attachment Descriptions

Update multiple document attachments in bulk with a JSON or CSV input file. This works for version-specific attachments and attachments at the document level. You can only update the latest version of an attachment.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

PUT`/api/{version}/objects/documents/attachments/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` or `application/xml` |

## Body Parameters

Prepare a CSV or JSON input file.

| Name | Description |
| --- | --- |
| `id` conditional | The attachment ID to update. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `external_id__v` conditional | Identify attachments by their external ID instead of regular `id`. You must also add the `idParam=external_id__v` query parameter. |
| `description__v` required | Description of the attachment. Maximum 1,000 characters. |

[Download Input File](/sample-files/bulk-update-multiple-attachment-descriptions.json)

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you’re identifying attachments in your input by external id, add `idParam=external_id__v` to the request endpoint. |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id__sys,document_version_id__sys
58,1_0_1' \
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
            "id": 38,
            "version": 2
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response gives the `id` and `version` of all successfully updated attachments.
