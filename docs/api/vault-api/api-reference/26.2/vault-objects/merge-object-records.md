<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/merge-object-records/ -->
<!-- title: Merge Object Records -->

# Merge Object Records

Duplicate records in Vault can happen due to migrations, integrations, or day-to-day activities and may be difficult to resolve. Vault provides a solution to duplicate records by allowing you to merge two records together. You can only initiate record merges through Vault API or [Vault Java SDK](/vault-sdk/entry-points/record-merge/), and you cannot initiate a record merge through the Vault UI.

Your organization may want to create custom [Record Merge Event Handlers](/vault-sdk/entry-points/record-merge/record-merge-handlers) with Vault Java SDK, which can execute custom logic immediately when a record merge begins or after a record merge completes. For example, directly after a merge starts, you can retrieve the field values on the duplicate record. Directly after the merge completes, you can update any desired information from the duplicate record to the main record. This overrides the default merge behavior which does not copy data between the duplicate and main record.

Learn more about [merging records in Vault Help](https://platform.veevavault.help/en/gr/659058).
