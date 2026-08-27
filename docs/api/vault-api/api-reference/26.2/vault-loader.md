<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-loader/ -->
<!-- title: Vault Loader -->

# Vault Loader

The following endpoints allow you to leverage Loader Services to load a set of data objects to your Vault or extract one or more data files from your Vault. Learn more about Vault Loader, such as limits and required permissions, [in Vault Help](https://platform.veevavault.help/en/gr/26597).

Note

To take advantage of functionality available in later versions, the Vault Loader API uses Vault Loader v21.3 or later:

* With API v21.3 and earlier, Vault Loader passes v21.3 through to underlying APIs. For example, a request to Vault Loader API v21.2 will use the v21.3 Vault Objects, Documents, and VQL APIs.
* With API v22.1+, Vault Loader passes the API request version through to underlying APIs. For example, a request to Vault Loader API v22.2 will use the v22.2 Vault Objects, Documents, and VQL APIs as specified.
