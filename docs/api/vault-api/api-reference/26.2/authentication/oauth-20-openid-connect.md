<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/oauth-20-openid-connect/ -->
<!-- title: OAuth 2.0 / OpenID Connect -->

# OAuth 2.0 / OpenID Connect

Authenticate your account using OAuth 2.0 / Open ID Connect token to obtain a Vault Session ID. Learn more about [OAuth 2.0 / Open ID Connect in Vault Help](https://platform.veevavault.help/en/gr/43329), such as configuration steps and [supported signing algorithms](https://platform.veevavault.help/en/gr/43329#signing-algorithms).

When requesting a `sessionId`, Vault allows the ability for Oauth2/OIDC client applications to pass the `client_id` with the request. Vault uses this `client_id` when talking with the introspection endpoint at the authorization server to validate that the `access_token` presented by the application is valid. Learn more about [Client ID in Vault Help](https://platform.veevavault.help/en/gr/43329#client-mapping).

POST`https://login.veevavault.com/auth/oauth/session/{oath_oidc_profile_id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Authorization` | Bearer access\_token |
| `Accept` | application/json (default) |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `oath_oidc_profile_id` | The ID of your OAuth2.0 / Open ID Connect profile. |

## Body Parameters

| Name | Description |
| --- | --- |
| `vaultDNS` optional | The DNS of the Vault for which you want to generate a session. If omitted, the session is generated for the user’s [most relevant available Vault](/vault-api/explanation/auth-defaulting). |
| `client_id` optional | The ID of the client application at the Authorization server. |

## Request

Copy to clipboard

```
curl -X POST \
-H "Content-Type: application/x-www-form-urlencoded" \
-H "Authorization: Bearer 1C29326C3DF" \
-H "Host: Bearer 1C29326C3DF" \
https://myserver.com/auth/oauth/session/_9ad0a091-cbd6-4c59-ab5a-d4f2870f218c
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "sessionId": "3B3C45FD240E26F0C3DB4F82BBB0C15C7EFE4B29EF9916AF41AF7E44B170BAA01F232B462BE5C2BE2ACB82F6704FDA216EBDD69996EB23A6050723D1EFE6FA2B",
  "userId": 12021,
  "vaultIds": [
    {
      "id": 1776,
      "name": "PromoMats",
      "url": "https://promomats-veevapharm.veevavault.com/api"
    },
    {
      "id": 1777,
      "name": "eTMF",
      "url": "https://etmf-veevapharm.veevavault.com/api"
    },
    {
      "id": 1779,
      "name": "QualityDocs",
      "url": "https://qualitydocs-veevapharm.veevavault.com/api"
    }
  ],
  "vaultId": 1776
}
```
