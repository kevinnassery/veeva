<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/create-documents/create-single-document/ -->
<!-- title: Create Single Document -->

# Create Single Document

Note

If you need to create more than one document, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/create-documents/create-multiple-documents).

Create a single document.

The API supports all security settings.

POST`/api/{version}/objects/documents`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |
| `X-VaultAPI-MigrationMode` | When set to `true`, you can use the `status__v` field to create documents in any lifecycle state. Additionally, you can manually set the name, document number, and version number. Vault also bypasses entry criteria, entry actions, and event actions and does not send notifications for documents created in migration mode. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |
| `X-VaultAPI-NoTriggers` | If set to `true` and [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) is enabled, it bypasses all system, standard, and custom doctype triggers. |

## Body Parameters

There are multiple ways to create a document.

### Create Document from Uploaded File

Most documents in your Vault are created from uploaded source files, such as a file from your computer. Learn about [Supported File Formats](https://platform.veevavault.help/en/gr/25210) in Vault Help. Once uploaded with values assigned to document fields, Vault generates the viewable rendition, e.g., "mydocument.docx.pdf". Learn about [Viewable Renditions](https://platform.veevavault.help/en/gr/3815) in Vault Help.

| Name | Description |
| --- | --- |
| `file` conditional | The filepath of the source document. The maximum allowed file size is 4GB. Only required when creating a document from an uploaded file. If omitted, creates a placeholder. |
| `name__v` required | The name of the new document. |
| `type__v` required | The name or label of the document type to assign to the new document. |
| `subtype__v` optional | The name or label of the document subtype (if one exists on the document type). |
| `classification__v` optional | The name or label of the document classification (if one exists on the document subtype). |
| `lifecycle__v` required | The name or label of the document lifecycle to assign to the new document. |
| `major_version_number__v` optional | The major version number to assign to the new document. |
| `minor_version_number__v` optional | The minor version number to assign to the new document. |

### Create Document from Template

When you create the new document, Vault copies the template file and uses that copy as the source file for the new document. This process bypasses the content upload process and allows for more consistent document creation. Document templates are associated with a specific document type, like documents themselves. Learn about [Document Templates](https://platform.veevavault.help/en/gr/5509) in Vault Help.

| Name | Description |
| --- | --- |
| `fromTemplate` conditional | The name of the template to apply. Only required when creating a document from a template. |
| `name__v` required | The name of the new document. |
| `type__v` required | The name or label of the document type to assign to the new document. |
| `subtype__v` optional | The name or label of the document subtype (if applicable). |
| `classification__v` optional | The name or label of the document classification (if one exists on the document subtype). |
| `lifecycle__v` required | The name or label of the document lifecycle to assign to the new document. |
| `major_version_number__v` optional | The major version number to assign to the new document. |
| `minor_version_number__v` optional | The minor version number to assign to the new document. |

### Create Content Placeholder Document

Creating a content placeholder document is just like creating a document from an uploaded file, but the `file` parameter is not included in the request. Learn about [Content Placeholders](https://platform.veevavault.help/en/gr/15087) in Vault Help. Admin may set other standard or custom document fields to required in your Vault.

| Name | Description |
| --- | --- |
| `name__v` required | The name of the new document. |
| `type__v` required | The name or label of the document type to assign to the new document. |
| `subtype__v` optional | The name or label of the document subtype (if one exists on the document type). |
| `classification__v` optional | The name or label of the document classification (if one exists on the document subtype). |
| `lifecycle__v` required | The name or label of the document lifecycle to assign to the new document. |
| `major_version_number__v` optional | The major version number to assign to the new document. |
| `minor_version_number__v` optional | The minor version number to assign to the new document. |

### Create Unclassified Document

Unclassified documents are documents which have a source file, but no document type. Learn about [Unclassified Documents](https://platform.veevavault.help/en/gr/15020) in Vault Help.

| Name | Description |
| --- | --- |
| `file` conditional | The filepath of the source document. The maximum allowed file size is 4GB. Only required when creating a document from an uploaded file. |
| `type__v` required | Set the document type to `Unclassified` or `Undefined` (`undefined__v`).\* |
| `lifecycle__v` required | Set the document lifecycle to `Inbox` or `Unclassified` (`unclassified__v`).\* |

In eTMF Vaults, you can also (optionally) set the following fields:

* `product__v`
* `study__v`
* `study_country__v`
* `site__v`

Any other fields included in the input will be ignored. The document `name__v` will default to the name of the uploaded file.

\* Prior to 21R1.3 (API v21.2), the `Unclassified` (`undefined__v`) document type and `Inbox` (`unclassified__v`) lifecycle were known as the `Undefined` document type and `Unclassified` lifecycle. Relabeling the `Undefined` document type and `Unclassified` lifecycle may impact the functionality of custom integrations that use the old labels. Check your integrations before updating this label. We recommend that customers experiencing errors change the labels back to their original values until this issue is resolved.

### Create CrossLink Document

When creating a CrossLink document, you must include all document fields that are required for the specified document type/subtype/classification and no file is uploaded. You must also specify the Vault ID and document ID for the source document which will be bound to the new CrossLink document. Learn about [CrossLinks](https://platform.veevavault.help/en/gr/23143) in Vault Help.

| Name | Description |
| --- | --- |
| `name__v` required | The name of the new CrossLink document. |
| `type__v` required | The label of the document type to assign to the new CrossLink document. |
| `subtype__v` optional | The label of the document subtype (if one exists on the document type). |
| `classification__v` optional | The label of the document classification (if one exists on the document subtype). |
| `lifecycle__v` required | The label of the document lifecycle to assign to the new CrossLink document. |
| `major_version_number__v` optional | The major version number to assign to the new CrossLink document |
| `minor_version_number__v` optional | The minor version number to assign to the new CrossLink document. |
| `source_vault_id__v` conditional | The Vault `id` field value of the Vault containing the source document that will be bound to the new CrossLink document. Only required when creating a CrossLink document. [Learn more](/vault-api/api-reference/26.2/domain-information/retrieve-domain-information). |
| `source_document_id__v` conditional | The document `id` field value of the source document that will be bound to the new CrossLink document. Only required when creating a CrossLink document. |
| `source_binding_rule__v` optional | Possible values are `Latest version`, `Latest Steady State version`, or `Specific document version`. These define which version of the source document will be bound to the CrossLink document. If not specified, this defaults to the `Latest Steady State version`. |
| `bound_source_major_version__v` optional | When the `source_binding_rule__v` is set to `Specific document version`, you must specify the major version number of the source document to bind to the CrossLink document. |
| `bound_source_minor_version__v` optional | When the `source_binding_rule__v` is set to `Specific document version`, you must specify the minor version number of the source document to bind to the CrossLink document. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "file=@gludacta-document-01.docx" \
-F "name__v=Gludacta Document" \
-F "type__v=Promotional Piece" \
-F "subtype__v=Advertisement" \
-F "classification__v=Web" \
-F "lifecycle__v=Promotional Piece" \
-F "major_version_number__v=0" \
-F "minor_version_number__v=1" \
-F "product__v=0PR0303" \
-F "external_id__v=GLU-DOC-0773" \
https://myvault.veevavault.com/api/v26.2/objects/documents
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "successfully created document",
    "id": 773
}
```

## Response Details

On `SUCCESS`, the document is created and assigned a system-managed document `id` field value. The generated document `id` may not be in sequential order.
