<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/ -->
<!-- title: Authentication -->

# Authentication

Authenticate your account using one of the methods outlined below. We recommend using [API access tokens](/vault-api/explanation/api-access-tokens/) to authenticate to Vault API. Users can provide the value of their access token in place of a session ID when sending requests.

When using Basic or Bearer token authorization, the response returns a session ID that you can use in subsequent API calls inside the `Authorization` HTTP request header. Session IDs time out after a period of inactivity, which varies by Vault. Learn more about [session duration and management](/vault-api/explanation/session-management).

## API Access Token Authorization

API access token values always begin with `veeva-vault-` followed by a randomized string. The `Authorization` HTTP header accepts the access token value preceded by the `Bearer` keyword.

| Name | Description |
| --- | --- |
| `Authorization` | Bearer {`access_token`} |

## Basic Authorization

| Name | Description |
| --- | --- |
| `Authorization` | {`sessionId`} |

Alternatively, you can use Salesforce or OAuth2/OIDC Delegated Requests.

## Bearer Token Authorization

Vault API also accepts Vault session IDs as Bearer tokens. Include the `Bearer` keyword to send Vault session IDs as Bearer tokens.

| Name | Description |
| --- | --- |
| `Authorization` | Bearer {`sessionId`} |
