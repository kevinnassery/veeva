<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/update-documents/create-multiple-document-versions/ -->
<!-- title: Create Multiple Document Versions -->

# Create Multiple Document Versions

Create or add document versions in bulk.

* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

POST`/api/{version}/objects/documents/versions/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |
| `X-VaultAPI-MigrationMode` | Must be set to `true`. Vault allows you to manually set the name and version number and to create documents in any lifecycle state using the `status__v` field, but does not allow you to change the document number. Vault also bypasses entry criteria, entry actions, and event actions and does not send notifications. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |
| `X-VaultAPI-NoTriggers` | If set to `true` and [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) is enabled, it bypasses all system, standard, and custom doctype triggers. |

## Body Parameters

| Name | Description |
| --- | --- |
| `file` required | The filepath of your source file. The maximum allowed file size is 500GB. |
| `id` conditional | The system-assigned document ID of the document to add the versions to. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `external_id__v` conditional | Instead of `id`, you can use this user-defined document external ID. |
| `name__v` required | Enter a name for the new document. This may be the same name as the existing document/version or a different name. |
| `type__v` required | Enter the name or label of the document type to assign to the new document. |
| `subtype__v` optional | Enter the name or label of the document subtype (if one exists on the document type). |
| `classification__v` optional | Enter the name or label of the document classification (if one exists on the document subtype). |
| `lifecycle__v` required | Enter the name or label of the document lifecycle to assign to the new document. This may be the same lifecycle as the existing document/version or a different lifecycle. |
| `major_version_number__v` required | Enter the major version number to assign to the new document version. This must be a version that does not yet exist on the document being updated. |
| `minor_version_number__v` required | Enter the minor version number to assign to the new document. This must be a version that does not yet exist on the document being updated. |
| `status__v` required | Enter the name or label of the status for the new document, e.g., Draft, In Review, Approved, etc. |
| `product__v` optional | Example: This is an example object reference field. To assign value for this field type, include either the document field name `product__v` or the document field name plus the name field on the object `product__v.name__v`. |

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you're identifying documents in your input by a unique field, add `idParam={fieldname}` to the request endpoint. You can use any object field which has `unique` set to `true` in the object metadata, with the exception of picklists. For example, `idParam=external_id__v`. |

[Download Input File](/sample-files/vault-add-document-versions-sample-csv-input.csv)

**Note**: In PromoMats Vaults with Automated Claims Linking enabled, when a reference document is updated with the Create Multiple Document Versions API, the associated claim record is updated to reference the new version and remains in the approved state, and the reference is not removed.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-binary @"filename" \
https://myvault.veevavault.com/api/v26.2/objects/documents/versions/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 771,
            "external_id__v": "ALT-DOC-0771",
            "major_version_number__v": 0,
            "minor_version_number__v": 2
        },
        {
            "responseStatus": "SUCCESS",
            "id": 772,
            "external_id__v": "CHO-DOC-0772",
            "major_version_number__v": 0,
            "minor_version_number__v": 2
        },
        {
            "responseStatus": "SUCCESS",
            "id": 773,
            "external_id__v": "GLU-DOC-0773",
            "major_version_number__v": 1,
            "minor_version_number__v": 0
        },
        {
            "responseStatus": "FAILURE",
            "errors": [
                {
                    "type": "INVALID_DATA",
                    "message": "Error message describing why this document version was not added."
                }
            ]
        }
    ]
}
```
