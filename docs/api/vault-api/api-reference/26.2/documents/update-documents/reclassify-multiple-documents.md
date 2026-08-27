<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/update-documents/reclassify-multiple-documents/ -->
<!-- title: Reclassify Multiple Documents -->

# Reclassify Multiple Documents

Reclassify documents in bulk. Reclassify allows you to change the document type of existing documents or assign document types to unclassified documents.

A document "type" is the combination of the `type__v`, `subtype__v`, and `classification__v` fields on a document. When you reclassify, Vault may add or remove certain fields on the document.

Not all documents are eligible for reclassification. For example, you can only reclassify the latest version of a document and you cannot reclassify a checked out document. Learn more about [reclassifying documents in Vault Help](https://platform.veevavault.help/en/gr/2271).

* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

PUT`/api/{version}/objects/documents/batch/actions/reclassify`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |
| `X-VaultAPI-MigrationMode` | When set to `true`, Vault allows you to manually set the document number and to update documents to any lifecycle state using the `status__v` field. Vault does not send notifications in Document Migration Mode. All other Document Migration Mode overrides available at document creation are ignored, but do not generate an error message. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |
| `X-VaultAPI-NoTriggers` | If set to `true` and [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) is enabled, it bypasses all system, standard, and custom doctype triggers. |

## Body Parameters

Upload parameters as a CSV file. You can also add or remove values for any other editable document field. The request may require additional fields depending on the document type, subtype, and classification being assigned to the document. If the document has the *Inbox* (`unclassified__v`) lifecycle, this request bypasses required field validation. Use the [Document Metadata API](/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-all-document-fields) to retrieve required and editable fields in your Vault. If a required field is missing, the error response will list the name of the required field.

| Name | Description |
| --- | --- |
| `id` required | The ID of the document to reclassify. |
| `lifecycle__v` required | The name of the document lifecycle. When assigning a document type to an unclassified document, you must provide *Inbox* (`unclassified__v`) as the lifecycle to bypass required field validation. |
| `type__v` required | The name of the document type. |
| `subtype__v` optional | The name of the document subtype (if one exists on the type). |
| `classification__v` optional | The name of the document classification (if one exists on the subtype). |
| `document_number__v` optional | The document number for the reclassified document. If omitted, the document retains the existing document number. You must set both the `reclassify` parameter and the `X-VaultAPI_MigrationMode` header to `true` to change the document number, and you can only include this parameter when you also change the document lifecycle or type, subtype, or classification. |
| `status__v` optional | Specifies the document lifecycle state for the reclassified document. If omitted, the document retains the existing state. You must set both the `reclassify` parameter and the `X-VaultAPI_MigrationMode` header to `true` to change the state, and you can only include this parameter when you also change the document lifecycle or type, subtype, or classification. |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id,lifecycle__v,type__v
44,"Promotional Piece","Promotional Piece"
46,"Promotional Piece","Promotional Piece"' \
https://myvault.veevavault.com/api/v26.2/objects/documents/batch/actions/reclassify
```

## Response

Copy to clipboard

```
responseStatus,id,errors,warnings
SUCCESS,44,
SUCCESS,46,
```

## Response Details

On `SUCCESS`, Vault returns the IDs of the reclassified documents.
