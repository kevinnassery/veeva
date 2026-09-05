<!-- source: https://general.veevavault.dev/mdl/component-types/doctype/ -->
<!-- title: Doctype -->

# Doctype

**Class:**  `metadata`

Document types refer to a hierarchical taxonomy to differentiate the various types of documents stored in Vault.

Learn about [Document Types in Vault Help](https://platform.veevavault.help/en/lr/618).

| Attribute | Metadata | Description |
| --- | --- | --- |
| `auto_bring_forward_annotations` | Type: Boolean | If `true`, Vault automatically brings forward annotations when a new document version is created. |
| `auto_bring_forward_annotation_types` | Type: Enum Multi-value Allowed values:  * anchor\_\_sys * auto\_link\_\_sys * line\_\_sys * link\_\_sys * note\_\_sys * resolved\_note\_\_sys | The types of annotations to automatically bring forward. |
| `milestone_types` | Type: String Max length: 1500 Multi-value | The type of milestone. |
| `default_workflows` | Type: String Max length: 1500 Multi-value | The list consists of `Doclifecycle`/`Workflow` combinations separated by a colon **(:)** (e.g., `promotional_field__c:start_mld_review__c`). |
| `relationship_types` | Type: String Max length: 1500 Multi-value | The list of `Docrelationshiptype` names supported. |
| `etmf_rm_v2` | Type: String Max length: 1500 | eTMF Reference Model V2 Hierarchy Item external id, (e.g.,`tmf_rm_v2_04.02`)  *Available in eTMF Vaults only.* |
| `etmf_rm_v3` | Type: String Max length: 1500 | eTMF Reference Model V3 Hierarchy Item external id, (e.g., `tmf_rm_v3_04.02`)  *Available in eTMF Vaults only.* |
| `clinical_docs_rm` | Type: String Max length: 1500 | Veeva Clinical Docs Hierarchy Item id.  *Available in eTMF Vaults only.* |
| `document_number_format` | Type: String Max length: 512 | The document numbering pattern. If none are specified, the default value is inherited from parent or base |
| `document_name_format` | Type: String Max length: 512 | The document numbering pattern. If none are specified the default value is inherited from parent or base  If not specified at root, the default is:`{FileName}` |
| `crosslink` | Type: String Max length: 1500 | Determines whether CrossLinks created for this document type use the source document’s source file or viewable rendition. |
| `enable_suggested_links_source` | Type: Boolean | Each document type, subtype, and classification can be enabled or disabled for the Suggest Links action.  *Available in PromoMats Vaults only.* |
| `enable_suggested_links_target` | Type: Boolean | Each document type, subtype, and classification can be enabled as eligible or not eligible for Suggested Links references.  *Available in PromoMats Vaults only.* |
| `enable_binder_thumbnail` | Type: Boolean | Use a document from within the binder as the binder thumbnail instead of the standard Vault binder icon. |
| `binder_unbound_document_display_option` | Type: Enum Allowed values:  * latest\_version * latest\_viewable\_version * latest\_steady\_state\_version | Select display options for unbound documents. |
| `create_document_permissions` | Type: String Max length: 1500 Multi-value | The list of group or user IDs in the form of `user:username` or `group:Group.name__v`. |
| `create_binder_permissions` | Type: String Max length: 1500 Multi-value | The list of group or user IDs in the form of `user:username` or `group:Group.name__v`. |
| `role_defaulting_editors` | Type: String Max length: 1500 Multi-value | The list of group or user IDs in the form of `user:username` or `group:Group.name__v`. |
| `role_defaulting_viewers` | Type: String Max length: 1500 Multi-value | The list of group or user IDs in the form of `user:username` or `group:Group.name__v`. |
| `role_defaulting_consumers` | Type: String Max length: 1500 Multi-value | The list of group or user IDs in the form of `user:username` or `group:Group.name__v`. |
| `inherit_doctype_groups` | Type: Boolean | Indicates whether the `doctype_group` values are inherited from the parent `Doctype`. |
| `doctype_group` | Type: String Max length: 1500 Multi-value | List of Document Group (`doc_type_group__v`) linked to this Doctype. |
| `regen_doc_name_on_save` | Type: Boolean | Whether auto-generated names should be refreshed when saving the document. |
| `allow_attachments` | Type: Boolean | Whether documents of this type can have attachments. |
| `rendition_types` | Type: String Max length: 1500 Multi-value | The list of `Renditiontype` names supported. |
| `available_lifecycles` | Type: String Max length: 1500 Multi-value | The list of `Doclifecycle` names. If none are specified, the default value is inherited from parent or base. |
| `processes` | Type: String Max length: 1500 Multi-value | The list of process names.  These come from processes picklists. |
| `etmf_department` | Type: String Max length: 1500 | The department name from the `etmf_departmnet` picklist  *Available in eTMF Vaults only.* |
| `filters` | Type: String Max length: 1500 Multi-value | Names of fields for document fields using MDL notation (e.g., `Docfield.field__v`)  Additional special filters:  * `date_search` * `user_search` * `version_search` * `file_format_search` |
| `active` | Type: Boolean **Required** | Indicates whether the field is active. |
| `fields` | Type: String Max length: 1500 Multi-value | The list of `Docfield` components linked to this Doctype. |
| `description` | Type: String Max length: 500 | A general description of the Doctype. |
| `label` | Type: String **Required** Max length: 200 | UI-friendly string. |

### Supported Operations

| Operation | Support |
| --- | --- |
| Create |  |
| Recreate |  |
| Alter | \* |
| Drop |  |
| Rename |  |
| Describe |  |
| Generate Recreate |  |
| Queryable |  |

**Notes:**

* **Alter:** MDL Operation may not be supported for some multi-value attributes.
