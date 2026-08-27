<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/document-user-actions/ -->
<!-- title: Document User Actions -->

# Document User Actions

This API allows you to initiate the following user action types:

* **Workflow** (legacy): This action starts the specified legacy workflow. Only legacy workflows that are already configured and active for the selected lifecycle are available. To start a document workflow, see [Document Workflows](/vault-api/api-reference/26.2/document-lifecycle-workflows/document-workflows).
* **State Change**: This action allows the user to manually move a document into a different lifecycle state. Vault enforces entry criteria and entry actions for the state change.
* **Controlled Copy**: This action is available in QualityDocs Vaults and with the QualityOne application family. It allows the user to generate and distribute a controlled copy.

To initiate user actions on binders, see [Binder User Actions](/vault-api/api-reference/26.2/document-lifecycle-workflows/binder-user-actions).

Your Vault may include other user action types, not all of which can be initiated through Vault API. Learn more about [document user action types in Vault Help](https://platform.veevavault.help/en/gr/12339#types).

The API does not support initiation of user actions requiring eSignatures.
