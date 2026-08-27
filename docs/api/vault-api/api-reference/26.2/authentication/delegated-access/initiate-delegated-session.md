<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/delegated-access/initiate-delegated-session/ -->
<!-- title: Initiate Delegated Session -->

# Initiate Delegated Session

Generate a delegated session ID. This allows you to call Vault API on behalf of a user who granted you delegate access. To find which users have granted you delegate access, [Retrieve Delegations](/vault-api/api-reference/26.2/authentication/delegated-access/retrieve-delegations).

POST`/api/{version}/delegation/login`

## Headers

| Name | Description |
| --- | --- |
| `Authorization` | The `sessionId` of the currently authenticated user who will initiate the delegated session. Cannot be a `delegated_sessionid`. |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

| Name | Description |
| --- | --- |
| `vault_id` required | The `id` value of the Vault to initiate the delegated session. |
| `delegator_userid` required | The ID of the user who granted the authenticated user delegate access in this Vault. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-d "vault_id=5791" \
-d "delegator_userid=67899" \
https://myvault.veevavault.com/api/v26.2/delegation/login
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "delegated_sessionid": "1C8DBD593EDCEAD647E5E4C97A438F1F43A25C8679BB8431BDC789BC0BAAE76E0DC42D478721624765A2BA2E923852"
}
```

## Response Details

On `SUCCESS`, Vault returns a `delegated_sessionid`. To execute Vault API calls with this delegated session, use this `delegated_sessionid` value as the `Authorization` header value.
