<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/session-keep-alive/ -->
<!-- title: Session Keep Alive -->

# Session Keep Alive

Given an active `sessionId`, keep the session active by refreshing the session duration.

A Vault session is considered active as long as some activity (either through the UI or API) happens within the maximum inactive session duration. This maximum inactive session duration varies by Vault and is configured by your Vault Admin. The maximum active session duration is 48 hours, which is not configurable. Learn more about [best practices for session management](/vault-api/explanation/session-management).

POST`/api/{version}/keep-alive`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |
| `Authorization` | The Vault `sessionId` to keep active. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/keep-alive
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS"
}
```
