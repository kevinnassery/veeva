<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/user-name-and-password/ -->
<!-- title: User Name and Password -->

# User Name and Password

Authenticate your account using your Vault user name and password to obtain a Vault Session ID.

Note

We recommend using [API access tokens](/vault-api/explanation/api-access-tokens/) to authenticate to Vault API. Instead of initiating a session with a user name and password, users can provide the value of their access token in place of the session ID when sending requests.

If the specified user cannot successfully authenticate to the given `vaultDNS`, the subdomain is considered invalid and this request instead generates a session for the user’s [most relevant available Vault](/vault-api/explanation/auth-defaulting). A DNS is considered invalid for the given user if the user cannot access any Vaults in that subdomain, for example, if the user does not exist in that DNS or if all Vaults in that DNS are inactive. For this reason, it is best practice to inspect the response, compare the desired Vault ID with the list of returned Vault IDs, and confirm the DNS matches the expected login.

Vault limits the number of Authentication API calls based on the user name and the domain name used in the API call. To determine the Vault Authentication API burst limit for your Vault or the length of delay for a throttled response, check the [response headers](/vault-api/references/api-rate-limits/#Auth_API_Rate_Limit_Headers) or the [API Usage Logs](https://platform.veevavault.help/en/gr/14341#API_Usage_Logs).

POST`https://{vaultDNS}/api/{version}/auth`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `vaultDNS` | The DNS of the Vault for which you want to generate a session. If the requesting user cannot successfully authenticate to this `vaultDNS`, this request generates a session for the user’s [most relevant available Vault](/vault-api/explanation/auth-defaulting). |
| `version` | The Vault API version. Your authentication version does not need to match the version in subsequent calls. For example, you can authenticate with v17.3 and run your integrations with v20.1. |

## Body Parameters

| Name | Description |
| --- | --- |
| `username` required | Your Vault user name assigned by your administrator. |
| `password` required | Your Vault password associated with your assigned Vault user name. |
| `vaultDNS` optional | The DNS of the Vault for which you want to generate a session. If specified, this optional `vaultDNS` body parameter overrides the value in the URI `vaultDNS`. If the requesting user cannot successfully authenticate to this `vaultDNS`, this request generates a session for the user’s [most relevant available Vault](/vault-api/explanation/auth-defaulting). If this `vaultDNS` body parameter is omitted, this request instead generates a session for the domain specified in the URI `vaultDNS`. |

## Request

Copy to clipboard

```
curl -X POST https://myvault.veevavault.com/api/v26.2/auth \
-H "Content-Type: application/x-www-form-urlencoded" \
-H "Accept: application/json" \
-d "username={username}&password={password}"
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

## Response Details

On `SUCCESS`, this request returns a valid `sessionId` for any Vault DNS where the user has access.

The Vault DNS for the returned session is calculated in the following order:

1. Generates a session for the DNS in the optional `vaultDNS` body parameter
   * If this `vaultDNS` is invalid, generates a session for the user’s [most relevant available Vault](/vault-api/explanation/auth-defaulting):
     1. Generates a session for the Vault where the user last logged in
     2. If the user has never logged in, or if the last logged-in Vault is inactive, generates a session for the oldest active Vault where that user is a member
     3. If the user is not a member of any active Vaults, the user cannot authenticate and the API returns `FAILURE`
2. If the optional `vaultDNS` body parameter is omitted, generates a session for the DNS specified in the `vaultDNS` URI parameter
   * If this `vaultDNS` is invalid, generates a session for the user’s [most relevant available Vault](/vault-api/explanation/auth-defaulting):
     1. Generates a session for the Vault where the user last logged in
     2. If the user has never logged in, or if the last logged-in Vault is inactive, generates a session for the oldest active Vault where that user is a member
     3. If the user is not a member of any active Vaults, the user cannot authenticate and the API returns `FAILURE`

An invalid DNS is any DNS which the specified user cannot access, for example, if the DNS does not exist, if the user does not exist in that DNS, or if all Vaults in that DNS are inactive.

It is best practice to inspect the response, compare the desired Vault ID with the list of returned `vaultIds`, and confirm the DNS matches the expected login.

This API only returns `FAILURE` if it is unable to return a valid `sessionId` for any Vault the user can access.
