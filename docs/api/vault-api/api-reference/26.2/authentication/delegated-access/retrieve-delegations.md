<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/delegated-access/retrieve-delegations/ -->
<!-- title: Retrieve Delegations -->

# Retrieve Delegations

Retrieve Vaults where the currently authenticated user has delegate access. You can then use this information to [Initiate a Delegated Session](/vault-api/api-reference/26.2/authentication/delegated-access/initiate-delegated-session).

GET`/api/{version}/delegation/vaults`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/delegation/vaults
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "delegated_vaults": [
       {
           "id": 19523,
           "name": "PromoMats",
           "dns": "mypromomatsvault.veevavault..com",
           "delegator_userid": "61579"
       }
   ]
}
```

## Response Details

On `SUCCESS`, Vault returns the name, Vault ID, DNS, and user ID for any Vaults the authenticated user has delegate access to. If the response is empty, the authenticated user does not have delegate access to any Vaults.
