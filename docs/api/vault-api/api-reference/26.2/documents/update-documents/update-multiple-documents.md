<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/update-documents/update-multiple-documents/ -->
<!-- title: Update Multiple Documents -->

# Update Multiple Documents

Bulk update editable field values on multiple documents. You can only update the latest version of each document. To update past document versions, see [Update Document Version](/vault-api/api-reference/26.2/documents/update-documents/update-document-version).

* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 1,000.

PUT`/api/{version}/objects/documents/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `text/csv` |
| `X-VaultAPI-MigrationMode` | When set to `true`, Vault allows you to change the document number. Vault does not send notifications in Document Migration Mode. All other Document Migration Mode overrides available at document creation are ignored, but do not generate an error message. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |
| `X-VaultAPI-NoTriggers` | If set to `true` and [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) is enabled, it bypasses all system, standard, and custom doctype triggers. |

## Body Parameters

You can use Name-Value pairs in the body of your request or upload a CSV file. `id` is the only required field, and you can update values of any editable document field. To find these fields, [Retrieve Document Fields](/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-all-document-fields) configured on documents. Editable fields will have `editable:true`. To remove existing field values, include the field name and set its value to null.

The following table includes required fields, and some optional document fields you may want to update:

| Name | Description |
| --- | --- |
| `id` conditional | The ID of the document to update. Only required when uploading a CSV file. |
| `docIds` conditional | Comma-separated list of the IDs of documents to update. Only required when entering key-value pairs in the body of your request. |
| `archive__v` optional | To archive a document, set to `true`. To unarchive a document, set to `false`. The default is `false`. Document archive is not available in all Vaults. [Learn more in Vault Help.](https://platform.veevavault.help/en/gr/34126) |
| `template_doctype__v` optional | If you need to create a controlled document template from this document, enter a value for the *Template Document Type* field. To retrieve a list of all possible field values for this field, [Retrieve the Object Collection](/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) for `doc_type_detail__v`. Learn more about [controlled document template creation in Vault Help](https://platform.veevavault.help/en/gr/46025). |

[Download Input File](/sample-files/vault-update-documents-sample-csv-input.csv)

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id,product__v,country__v,language__v,audience__vs
771,00P1110,00C0001,English,Consumer
772,00P2220,00C0002,French,Healthcare Provider
773,00P3330,00C0003,Japanese,Managed Markets' \
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
        }
    ]
}
```
