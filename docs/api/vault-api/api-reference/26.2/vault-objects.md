<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/ -->
<!-- title: Vault Objects -->

# Vault Objects

Each Vault is configured with a set of standard objects (`product__v`, `country__v`, `study__v`, etc.). These vary by application and configuration.

Vault is also configured with a set of system objects (`user__sys`, `person__sys`, `locale__sys`, etc.) These are available for all Vault applications and configurations.

Admins may also create custom objects (`region__c`, `agency__c`, `manufacturer__c`, etc.).

Each object can have multiple object records. For example, the `product__v` object may have records for products named `CholeCap`, `Nyaxa`, and `WonderDrug`. All object records are user-defined.

Vault API supports the retrieval of Vault object records and their metadata as well as creating, updating, and deleting object records. It does not support creating or updating Vault objects. This must be done by an Admin in the UI.

Learn about [Vault objects](https://platform.veevavault.help/en/gr/15298) in Vault Help.
