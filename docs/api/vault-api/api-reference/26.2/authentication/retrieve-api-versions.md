<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/retrieve-api-versions/ -->
<!-- title: Retrieve API Versions -->

# Retrieve API Versions

Retrieve all supported versions of Vault API.

GET`/api/`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "values": {
       "v7.0": "https://myvault.veevavault.com/api/v7.0",
       "v8.0": "https://myvault.veevavault.com/api/v8.0",
       "v9.0": "https://myvault.veevavault.com/api/v9.0",
       "v10.0": "https://myvault.veevavault.com/api/v10.0",
       "v11.0": "https://myvault.veevavault.com/api/v11.0",
       "v12.0": "https://myvault.veevavault.com/api/v12.0",
       "v13.0": "https://myvault.veevavault.com/api/v13.0",
       "v14.0": "https://myvault.veevavault.com/api/v14.0",
       "v15.0": "https://myvault.veevavault.com/api/v15.0",
       "v16.0": "https://myvault.veevavault.com/api/v16.0",
       "v17.1": "https://myvault.veevavault.com/api/v17.1",
       "v17.2": "https://myvault.veevavault.com/api/v17.2",
       "v17.3": "https://myvault.veevavault.com/api/v17.3",
       "v18.1": "https://myvault.veevavault.com/api/v18.1",
       "v18.2": "https://myvault.veevavault.com/api/v18.2",
       "v18.3": "https://myvault.veevavault.com/api/v18.3",
       "v19.1": "https://myvault.veevavault.com/api/v19.1",
       "v19.2": "https://myvault.veevavault.com/api/v19.2",
       "v19.3": "https://myvault.veevavault.com/api/v19.3",
       "v20.1": "https://myvault.veevavault.com/api/v20.1",
       "v20.2": "https://myvault.veevavault.com/api/v20.2",
       "v20.3": "https://myvault.veevavault.com/api/v20.3",
       "v21.1": "https://myvault.veevavault.com/api/v21.1"
   }
}
```

## Response Details

On success, Vault returns every supported API version. The last version listed in the response may be the Beta version, which is subject to change. Learn more about [Vault API versioning](/vault-api/getting-started/endpoint-structure/#Vault_API_Versioning).
