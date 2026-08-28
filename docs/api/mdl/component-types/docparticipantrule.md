<!-- source: https://general.veevavault.dev/mdl/component-types/docparticipantrule/ -->
<!-- title: Docparticipantrule -->

# Docparticipantrule

**Class:**  `metadata`

Workflow participant rules control which document fields will force the selected role to be required or hidden in the workflow start dialog.

Learn about [Workflow Participant Rules in Vault Help.](https://platform.veevavault.help/en/lr/31851#wf-participant-rules)

| Attribute | Metadata | Description |
| --- | --- | --- |
| `lifecycle` | Type: Component **Required** | The document lifecycle the rule applies to. |
| `role` | Type: Component **Required** | The lifecycle role the rule applies to. |
| `active` | Type: Boolean **Required** | Indicates whether the component is active. |
| `description` | Type: String Max length: 255 | A general description of the rule. |
| `label` | Type: String **Required** Max length: 60 | UI-friendly string in the Vault's base language. |

### Docparticipantcriterion

| Attribute | Metadata | Description |
| --- | --- | --- |
| `object_field` | Type: Component **Required** | The field of the `object` the rule is defined on. |
| `data_field` | Type: Component **Required** | The field on the document the rule is defined on. |
| `object` | Type: Component **Required** | The Object the participant rule is defined on. This can only be `workflow_role_setup__v`. |

### Supported Operations

| Operation | Support |
| --- | --- |
| Create |  |
| Recreate |  |
| Alter |  |
| Drop |  |
| Rename |  |
| Describe |  |
| Generate Recreate |  |
| Queryable |  |
