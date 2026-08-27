<!-- source: https://general.veevavault.dev/vql/query-targets/matched-documents/ -->
<!-- title: Matched Documents -->

# Matched Documents

Expected document lists (EDLs) measure the completeness of projects such as clinical studies by linking documents to EDL Item records based on matching field values. In v17.3+, you can use the `matched_documents` object to query matched documents.

Learn more about [EDLs in Vault Help](https://platform.veevavault.help/en/lr/33316).

## Matched Documents Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The following fields are queryable for the `matched_documents` object:

| Name | Description |
| --- | --- |
| `id` | The id of the `matched_documents` record. |
| `edl_item_id__v` | The id of the EDL Item record linked to the document. |
| `matching_doc_id__v` | The document id. |
| `major_version__v` | The document’s major version number. |
| `minor_version__v` | The document’s minor version number. |
| `created_date__v` | The date the document was created. |
| `created_by__v` | The id of the user who created the document. |
| `modified_date__v` | The date the document was last modified. |
| `modified_by__v` | The id of the user who last modified the document. |
| `include_in_total__v` | When set to `true`, indicates that the document should be applied to the matching document count for the EDL Item. |
| `version_is_locked__v` | When set to `true`, confirms that Vault has locked the document version to the EDL Item. |
| `source__v` | Indicates if the document was matched by user or auto. |

## Matched Document Query Examples

The following are examples of matched document queries.

### Query: Retrieve All Matched Documents

The following query retrieves the ID, *EDL Item* ID, and other data from all matched documents:

Copy to clipboard

```
SELECT id, edl_item_id__v, matching_doc_id__v, major_version__v, minor_version__v, created_date__v, created_by__v, modified_date__v, modified_by__v, include_in_total__v, version_is_locked__v, source__v
FROM matched_documents
```

### Query: Retrieve Matched Document Relationships

The following query retrieves the matched document name and *EDL Item* name using the `matching_documents__vr` and `edl_item__vr` object relationships:

Copy to clipboard

```
SELECT id, edl_item_id__v, matching_doc_id__v, matching_documents__vr.name__v, edl_item__vr.name__v
FROM matched_documents
```
