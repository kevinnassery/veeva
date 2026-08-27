<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/create-documents/create-multiple-documents/ -->
<!-- title: Create Multiple Documents -->

# Create Multiple Documents

This endpoint allows you to create multiple documents at once with a CSV input file.

* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

Note that this API does not support adding multi-value relationship fields by name. To add multi-value fields, you must first retrieve the ID values and add them to the relationship field.

The API supports all security settings except document lifecycle role defaults. You must create documents through the UI if your documents require document lifecycle role defaults. Learn more about [document lifecycle role defaults in Vault Help](https://platform.veevavault.help/en/gr/6572).

POST`/api/{version}/objects/documents/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |
| `X-VaultAPI-MigrationMode` | When set to `true`, Vault allows you to create documents in any lifecycle state using the `status__v` field, and to manually set the name, document number, and version number. Vault also bypasses entry criteria, entry actions, and event actions and does not send notifications for documents created in migration mode. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |
| `X-VaultAPI-NoTriggers` | If set to `true` and [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) is enabled, it bypasses all system, standard, and custom doctype triggers. |

## Body Parameters

Prepare a CSV input file. There are multiple ways to create documents in bulk. The following shows the required standard fields needed to create documents, but an Admin may set other standard or custom document fields as required in your Vault. To find which fields are required, [retrieve document fields](/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-all-document-fields). You can also optionally include any editable document field.

### Create Documents from Uploaded Files

You must first upload the document source files to your Vault's [file staging](/vault-api/guides/file-staging).

| Name | Description |
| --- | --- |
| `file` conditional | The filepath of the source document. The maximum allowed file size is 500GB. Only required when creating a document from an uploaded file. |
| `name__v` required | The name of the new document. |
| `type__v` required | The name or label of the document type to assign to the new document. |
| `subtype__v` optional | The name or label of the document subtype (if one exists on the document type). |
| `classification__v` optional | The name or label of the document classification (if one exists on the document subtype). |
| `lifecycle__v` required | The name or label of the document lifecycle to assign to the new document. |
| `major_version_number__v` optional | The major version number to assign to the new document |
| `minor_version_number__v` optional | The minor version number to assign to the new document. |
| `suppressRendition` optional | Set to `true` to suppress generation of viewable renditions. The default is `false`. |
| `product__v` optional | Example: This is an example object reference field. To assign value for this field type, include either the document field name `product__v` or the document field name plus the name field on the object `product__v.name__v`. |

[Download Input File](/sample-files/vault-create-documents-from-uploaded-files-sample-csv-input.csv)

### Create Documents from Templates

When you create a new document from a template, Vault copies the template file in your Vault and uses that copy as the source file for the new document.

| Name | Description |
| --- | --- |
| `fromTemplate` conditional | The template to apply to the document. Only required when creating a document from a template. |
| `name__v` required | The name of the new document. |
| `type__v` required | The name or label of the document type to assign to the new document. |
| `subtype__v` optional | The name or label of the document subtype (if one exists on the document type). |
| `classification__v` optional | The name or label of the document classification (if one exists on the document subtype). |
| `lifecycle__v` required | The name or label of the document lifecycle to assign to the new document. |
| `major_version_number__v` optional | The major version number to assign to the new document |
| `minor_version_number__v` optional | The minor version number to assign to the new document. |
| `product__v` optional | Example: This is an example object reference field. To assign value for this field type, include either the document field name `product__v` or the document field name plus the name field on the object `product__v.name__v`. |

[Download Input File](/sample-files/vault-create-documents-from-document-template-sample-csv-input.csv)

### Create Content Placeholder Documents

Vault allows you to create content placeholders when the associated file is not yet available. You can add the source document at a later date.

| Name | Description |
| --- | --- |
| `file` required | Include this column in your input, but leave the values blank. |
| `name__v` required | The name of the new document. |
| `type__v` required | The name or label of the document type to assign to the new document. |
| `subtype__v` optional | The name or label of the document subtype (if one exists on the document type). |
| `classification__v` optional | The name or label of the document classification (if one exists on the document subtype). |
| `lifecycle__v` required | The name or label of the document lifecycle to assign to the new document. |
| `major_version_number__v` optional | The major version number to assign to the new document |
| `minor_version_number__v` optional | The minor version number to assign to the new document. |

[Download Input File](/sample-files/vault-create-content-placeholder-documents-sample-csv-input.csv)

### Create Unclassified Documents

Unclassified documents are documents which have a source file, but no document type. The following fields are required, but you can include any editable document field.

| Name | Description |
| --- | --- |
| `file` required | The filepath of the source document. The maximum allowed file size is 500GB. |
| `name__v` optional | The name of the new document. |
| `type__v` required | Set the document type to `Unclassified` or `Undefined` (`undefined__v`).\* |
| `lifecycle__v` required | Set the document lifecycle to `Inbox` or `Unclassified` (`unclassified__v`).\* |

\* Prior to 21R1.3 (API v21.2), the `Unclassified` (`undefined__v`) document type and `Inbox` (`unclassified__v`) lifecycle were known as the `Undefined` document type and `Unclassified` lifecycle. Relabeling the `Undefined` document type and `Unclassified` lifecycle may impact the functionality of custom integrations that use the old labels. Check your integrations before updating this label. We recommend that customers experiencing errors change the labels back to their original values until this issue is resolved.

[Download Input File](/sample-files/vault-create-unclassified-documents-sample-csv-input.csv)

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-binary @"filename" \
https://myvault.veevavault.com/api/v26.2/objects/documents/batch
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
            "external_id__v": "ALT-DOC-0771"
        },
        {
            "responseStatus": "SUCCESS",
            "id": 772,
            "external_id__v": "CHO-DOC-0772"
        },
        {
            "responseStatus": "SUCCESS",
            "id": 773,
            "external_id__v": "GLU-DOC-0773"
        },
        {
            "responseStatus": "FAILURE",
            "errors": [
                {
                    "type": "INVALID_DATA",
                    "message": "Error message describing why this document was not created."
                }
            ]
        }
    ]
}
```

## Response Details

On `SUCCESS`, the documents are created and assigned a system-managed document `id` field value. The generated document `id` may not be in sequential order.
