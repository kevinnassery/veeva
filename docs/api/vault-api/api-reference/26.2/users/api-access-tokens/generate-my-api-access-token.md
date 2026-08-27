<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/api-access-tokens/generate-my-api-access-token/ -->
<!-- title: Generate My API Access Token -->

# Generate My API Access Token

Generate an API access token for the currently authenticated user. Each user can be granted up to 25 active access tokens. Learn more about [generating access tokens](/vault-api/explanation/api-access-tokens/#Generating_Access_Tokens).

POST`https://{vaultDNS}/api/{version}/objects/users/me/api_access_token__sys`

## Headers

| Name | Description |
| --- | --- |
| `Authorization` | The Vault `sessionId` or `Bearer {access_token}`. If you do not have any existing access tokens, you must use another method to [authenticate](/vault-api/api-reference/26.2/authentication) to Vault API and obtain a valid session ID. |
| `Content-Type` | `application/x-www-form-urlencoded` or `application/json` |
| `Accept` | `application/json` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `vaultDNS` | The DNS of the Vault for which you want to generate a session. If the requesting user cannot successfully authenticate to this `vaultDNS`, this request generates a session for the user’s [most relevant available Vault](/vault-api/explanation/auth-defaulting). |
| `version` | The Vault API version. Your authentication version does not need to match the version in subsequent calls. For example, you can authenticate with v17.3 and run your integrations with v20.1. |

## Body Parameters

| Name | Description |
| --- | --- |
| `name__v` required | The name or description of the access token. |
| `expiry_date__v` optional | The expiration date of the access token, in `YYYY-MM-DDTHH:MM:SSZ` format. Dates and times are in UTC. If the time is not specified, it will default to before midnight (`23:59:59`) in the user's timezone on the specified date. The maximum expiration period may vary based on the user's security profile. If allowed by the user's security profile, this parameter can be omitted to indicate the access token never expires. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-H 'Accept: application/json' \
-d "name__v=IntegrationKey" \
-d "expiry_date__v=2026-12-31T12:00:00:00.000Z" \
https://myvault.veevavault.com/api/v26.2/objects/users/me/api_access_token__sys
```

## Response

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

## Response Details

On `SUCCESS`, this request returns the `id` for the access token as well as its value (`token__sys`). The access token's value is only visible upon creation and should be stored safely. If lost, you cannot recover this value and must generate a new access token.
