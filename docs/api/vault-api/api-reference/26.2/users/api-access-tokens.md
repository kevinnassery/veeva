<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/api-access-tokens/ -->
<!-- title: API Access Tokens -->

# API Access Tokens

API users can authenticate to Vault API using an API access token. When a user is granted permission to Vault API, they can generate an access token to make requests to Vault API. An access token does not give the user direct access to the Vault UI and is specific to a single Vault. Learn more about [API access tokens](/vault-api/explanation/api-access-tokens/).

You can use the available endpoints to generate access tokens for yourself or another specified user. When sending requests, you have the option of providing an expiration date for the access token or omitting it to allow the access token to never expire.

Note

To generate access tokens for a sandbox Vault, use the [Generate API Access Token for Sandbox](/vault-api/api-reference/26.2/sandbox-vaults/generate-api-access-token-for-sandbox) endpoint.
