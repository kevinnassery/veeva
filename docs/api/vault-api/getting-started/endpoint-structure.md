<!-- source: https://general.veevavault.dev/vault-api/getting-started/endpoint-structure/ -->
<!-- title: Endpoint Structure & Versioning -->

# Endpoint Structure & Versioning

As we talk about API calls, you'll need the following variables in every endpoint:

`https://{vaultDNS}/api/{version}`

* `{vaultDNS}`: The DNS of your Vault. You can find this by logging into your Vault via the UI. Once you log in, you’ll see a URL like this: `https://promo-vee.veevavault.com/ui/`. In API calls, replace the `{vaultDNS}` variable with the `promo-vee.veevavault.com` portion of the URL. If you have access to multiple Vaults on a single domain, the domain name will be different for each Vault.
* `{version}`: The Vault API version. Replace this with a version number, such as `v26.1`. You can use an API call to [retrieve the available Vault API versions](/vault-api/api-reference/26.2/authentication/retrieve-api-versions).

For example:

`https://promo-vee.veevavault.com/api/v26.1`

## Vault API Versioning

The only version of Vault API subject to change is the newest version, labelled as Beta. The latest version of Vault API which is not subject to change is the General Availability version, labelled as GA.

All older versions of Vault API (all versions besides Beta) do not change, which ensures your integration will continue to work. However, this means many new APIs and API features are not backwards compatible, and you will need to use a newer version of Vault API to access new functionality. To view the new APIs, features, and fixed issues for each Vault API version, you can check the [Release Notes](/rn).

### Version Naming

Veeva Vault releases three new API versions each year, coinciding with Vault General Releases. Vault API versions follow the pattern:

* `YY.1`
* `YY.2`
* `YY.3`

Where `YY` is the last two digits of the current year. For example, the first Vault General Release of 2026 is 26R1. The API version which coincides with this release is API `v26.1`. The third Vault General Release of 2026 is 26R3, which coincides with Vault API `v26.3`.

Each General Release is made up of multiple limited releases. For example, Vault release 26R1 includes all features released in 25R3.2, 25R3.4, and 25R3.5. Vault API versioning does not have limited release numbering. Instead, the latest version (in this example, `v26.1`) is the Beta version, and all limited release features are added to the current Beta API.
