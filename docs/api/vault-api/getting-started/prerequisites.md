<!-- source: https://general.veevavault.dev/vault-api/getting-started/prerequisites/ -->
<!-- title: Prerequisites -->

# Prerequisites

To make API calls against Vault, you need a Vault user account with API access. Once you have this, you can authenticate using an API access token.

## Vault User Account & Permissions

Your security profile and permission set may grant the following permissions:

* **Access**: This permission controls general access to Vault API and allows you to successfully make API calls. Note that this permission does not control the ability to authenticate. All users can authenticate to Vault without a specific permission.
* **Events**: This permission controls access to the [Document Events API](/vault-api/api-reference/26.2/documents/document-events).
* **Metadata**: Grants access to metadata APIs, including read and write access to MDL APIs.

### Insufficient Access

If your user does not have sufficient API access, your authentication request will succeed, but any other API calls you make will return the following error:

> `INSUFFICIENT_ACCESS: User [ID] not licensed for permission [VaultActions_API_Access].`

If you do not have API access, contact your Vault administrator to adjust your security profile and permission set.
