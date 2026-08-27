<!-- source: https://general.veevavault.dev/vault-api/getting-started/authenticating/ -->
<!-- title: Generate an API Access Token -->

# Generate an API Access Token

We recommend using an API access token to authenticate to Vault API. Instead of initiating a session with a user name and password, users can provide the value of their access token in place of the session ID when sending further requests to Vault API.

If you do not have any existing access tokens, you must first send an authentication request to obtain a session ID, then send a second request to generate an access token. To do this, call the `auth` endpoint.

## Send an Authentication Request

The `auth` endpoint (`/api/{version}/auth`) expects two URL-encoded form parameters (`x-www-form-urlencoded`): `username` and `password`.

#### Request

Copy to clipboard

```
curl -X POST -H "Content-Type: application/x-www-form-urlencoded" \
-d 'username={username}&password={password}' \
"https://{server}/api/{version}/auth"
```

This call returns a JSON response that contains the session ID.

#### Response

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
      "url": "https://promo-vee.veevavault.com/api"
    },
    {
      "id": 1782,
      "name": "Platform",
      "url": "https://platform-vee.veevavault.com/api"
    }
  ],
  "vaultId": 1776
}
```

You've now authenticated to Vault API and obtained a valid session ID. While session IDs expire after a period of inactivity, an access token may be valid for up to 90 days. Now, you can send a request to generate an access token.

Tip

Rarely, you can authenticate against a different Vault if the intended Vault is inactive. In this situation, you’ll authenticate against the last Vault you accessed or the oldest Vault in your domain. As a best practice, you should always check the returned `vaultId` against the `vaultIds` in the list to ensure that it’s the Vault you intended. Learn more about [authentication defaulting](/vault-api/explanation/auth-defaulting/).

## Generate an Access Token

The [Generate My API Access Token](/vault-api/api-reference/26.2/users/api-access-tokens/generate-my-api-access-token) endpoint (`/api/{version}/objects/users/me/api_access_token__sys`) expects two URL-encoded form parameters (`x-www-form-urlencoded`): `name__v` and `expiry_date__v`.

#### Request

Copy to clipboard

```
curl -X POST -H "Authorization: {SESSION_ID}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-H 'Accept: application/json' \
-d "name__v=IntegrationKey" \
-d "expiry_date__v=2026-12-31T12:00:00:00.000Z" \
https://myvault.veevavault.com/api/v26.2/objects/users/me/api_access_token__sys
```

This API call returns the `id` of the access token as well as its value (`token__sys`).

Warning

The access token's value is only visible upon creation and should be stored safely. If lost, you cannot recover this value and must generate a new access token.

#### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "id": "V8T000000002001",
        "token__sys": "veeva-vault-019e9338..."
    }
}
```

In the response above, the generated access token value begins with `veeva-vault-` followed by a randomized string. To make subsequent API calls, the `Authorization` HTTP header accepts the access token value preceded by the `Bearer` keyword.

## Continued Learning

* To understand the purpose of API access tokens, learn more about [generating access tokens](/vault-api/explanation/api-access-tokens/).
* To keep your session active without compromising performance, learn more about [best practices for session management](/vault-api/explanation/session-management/).
* To understand what happens if you try to authenticate to an inactive Vault, learn more about [authentication defaulting](/vault-api/explanation/auth-defaulting/).
* If you're a Vault Admin, learn how to [configure *Session Duration* in Vault Help](https://platform.veevavault.help/en/gr/63061/#default-session-duration).
