<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/end-session/ -->
<!-- title: End Session -->

# End Session

Given an active `sessionId`, inactivate an API session. If a user has multiple active sessions, inactivating one session does not inactivate all sessions for that user. Each session has its own unique `sessionId`.

DELETE`/api/{version}/session`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |
| `Authorization` | The Vault `sessionId` to end. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/session
```

## Response

Copy to clipboard

```
{
"responseStatus": "SUCCESS"
}
```
