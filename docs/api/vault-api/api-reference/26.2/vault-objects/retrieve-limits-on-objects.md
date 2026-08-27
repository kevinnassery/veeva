<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/retrieve-limits-on-objects/ -->
<!-- title: Retrieve Limits on Objects -->

# Retrieve Limits on Objects

Retrieve the limit on the number of custom objects that can be created in the authenticated Vault.

GET`/api/{version}/limits`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/limits
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "data": [
    {
      "name": "custom_objects",
      "remaining": 7,
      "max": 20
    }
  ]
}
```

## Response Details

| Field Name | Description |
| --- | --- |
| `custom_objects` | The maximum number of custom objects that can be created in the Vault and the number remaining. |
