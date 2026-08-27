<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/salesforcetrade-delegated-requests/ -->
<!-- title: Salesforce Delegated Requests -->

# Salesforce Delegated Requests

If your Vault uses Salesforce Delegated Authentication, you can call Vault API using your Salesforce session token. Learn about Salesforce Delegated Authentication in [Vault Help](https://platform.veevavault.help/en/gr/9594).

The following prerequisites apply:

* A valid Vault user must exist with a Security Policy enabled for Salesforce.com Delegated Authentication.
* The trusted 18-character Salesforce.com Org ID must be provided.
* A user with a matching username must exist in Salesforce.com Org ID.

## Headers

| Name | Description |
| --- | --- |
| `Authorization` | Your Salesforce session token. |
| `X-Auth-Host` | Salesforce URL which Vault can use to validate the Salesforce session token. |
| `X-Auth-Provider` | Set to `sfdc` to indicate that Salesforce is the authorization provider. |

## Query Parameters

You can also use query string parameters instead of the headers outlined above.

| Name | Description |
| --- | --- |
| `auth` | Your Salesforce session token. |
| `ext_url` | Salesforce URL which Vault can use to validate the Salesforce session token. |
| `ext_ns` | Set to `sfdc` to indicate that Salesforce is the authorization provider. |

## Request

Copy to clipboard

```
curl -X GET \
-H "Authorization: {SFDC_SESSION_TOKEN}" \
-H "X-Auth-Provider: sfdc" \
-H "X-Auth-Host: https://{my_sfdc_domain}" \
https://myveevavault.com/api/{version}/{Vault_Endpoint}
```
