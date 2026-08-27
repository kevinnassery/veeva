<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/authentication-type-discovery/ -->
<!-- title: Authentication Type Discovery -->

# Authentication Type Discovery

Discover the authentication type of a user. With this API, applications can dynamically adjust the login requirements per user, and support either username/password or OAuth2.0 / OpenID Connect authentication schemes.

POST`https://login.veevavault.com/auth/discovery`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) |
| `X-VaultAPI-AuthIncludeMsal` | Set to `true` to include information about MSAL, an authentication library available for some SSO profiles. If omitted, the response does not include MSAL information. |

## Query Parameters

| Name | Description |
| --- | --- |
| `username` | The user’s Vault user name. |
| `client_id` | Optional: The user's mapped Authorization Server `client_id`. This only applies the SSO and OAuth / OpenID Connect Profiles `auth_type`. Learn more about [Client ID in Vault Help](https://platform.veevavault.help/en/gr/43329#client-mapping). |

## Request

Copy to clipboard

```
curl -X POST \
-H "Accept: application/json" \
-H "X-VaultAPI-AuthIncludeMsal: true" \
https://login.veevavault.com/auth/discovery?username=olivia@veepharm.com&client_id=veepharm-clinical-it-client-int0
```

## Response: Password User

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "errors": [],
    "data": {
        "auth_type": "password"
    }
}
```

## Response: SSO User

Copy to clipboard

```
{
"responseStatus": "SUCCESS",
   "errors": [],
   "data": {
       "auth_type": "sso",
       "auth_profiles": [
           {
               "id": "_a45afc-4773-4e17-9831-2905b2a6",
               "label": "OAuth Azure",
               "description": "This Security Profile connects with Microsoft Azure.",
               "vault_session_endpoint": "https://veepharm.com/auth/oauth/session/_a45a10fc-4773-290ab2a6",
               "use_adal": true,
               "use_msal": true,
               "as_metadata": {
                   "token_endpoint": "https://login.microsoftonline.com/dcf3-468/oauth2/v2.0/token",
                   "token_endpoint_auth_methods_supported": [
                       "client_secret_post",
                       "private_key_jwt",
                       "client_secret_basic"
                   ],
                   "jwks_uri": "https://login.microsoftonline.com/4618-934/discovery/v2.0/keys",
                   "response_modes_supported": [
                       "query",
                       "fragment",
                       "form_post"
                   ],
                   "subject_types_supported": [
                       "pairwise"
                   ],
                   "id_token_signing_alg_values_supported": [
                       "RS256"
                   ],
                   "response_types_supported": [
                       "code",
                       "id_token",
                       "code id_token",
                       "id_token token"
                   ],
                   "scopes_supported": [
                       "openid",
                       "profile",
                       "email",
                       "offline_access"
                   ],
                   "issuer": "https://login.microsoftonline.com/7c5d9e-53443/v2.0",
                   "request_uri_parameter_supported": false,
                   "userinfo_endpoint": "https://graph.microsoft.com/oidc/userinfo",
                   "authorization_endpoint": "https://login.microsoftonline.com/7c3-9343/oauth2/v2.0/authorize",
                   "device_authorization_endpoint": "https://login.microsoftonline.com/57-618-954-543/oauth2/v2.0/devicecode",
                   "http_logout_supported": true,
                   "frontchannel_logout_supported": true,
                   "end_session_endpoint": "https://login.microsoftonline.com/7c577a96e043/oauth2/v2.0/logout",
                   "claims_supported": [
                       "cloud_instance_name",
                       "cloud_instance_host_name",
                       "cloud_graph_host_name",
                       "msgraph_host",
                       "auth_time",
                       "nonce",
                       "preferred_username",
                       "name",
                       "email"
                   ],
                   "kerberos_endpoint": "https://login.microsoftonline.com/7c5-556343/kerberos",
                   "tenant_region_scope": "NA",
                   "cloud_instance_name": "microsoftonline.com",
                   "cloud_graph_host_name": "graph.windows.net",
                   "msgraph_host": "graph.microsoft.com",
                   "rbac_url": "https://pas.windows.net"
               },
               "oauthProviderType": "Azure"
           }
       ]
   }
}
```

## Response Details

The response specifies the user’s authentication type (`auth_type`):

* `password`: The user is configured with a username and password.
* `sso`: The user is configured with an SSO Security Policy.

##### SSO Security Policy

If the user’s `auth_type` type is `sso`, the response specifies the user’s authentication profiles (`auth_profiles`). If the user’s Security Policy is associated with:

* A *SAML* profile, the `auth_profiles` array is empty. Learn about [SAML profiles in Vault Help](https://platform.veevavault.help/en/gr/43346).
* An *OAuth 2.0 / OpenID Connect* profile, the `auth_profiles` array contains information about the policy. Learn about [Configuring OAuth 2.0 / OpenID Connect Profiles in Vault Help](https://platform.veevavault.help/en/gr/43329).

##### auth\_profiles

The `auth_profiles` array contains information about the *OAuth 2.0 / OpenID Connect* Security Policy configured in the Vault UI by your Vault Administrator.

| Name | Description |
| --- | --- |
| `id` | The security policy ID. |
| `label` | The label for this security profile, displayed to Admins in the Vault UI. |
| `use_adal` | If `true`, indicates ADAL is available for use as an authentication library. For example, if the Authorization Server Provider is set to use `ADFS` or `Azure`, the `use_adal` field will appear in the response as `true`. |
| `use_msal` | If `true`, indicates MSAL is available for use as an authentication library. If multiple libraries are available, best practice is to use MSAL. This field is included in the response only if the `X-VaultAPI-AuthIncludeMsal` header is set to `true` in the initial request. |
| `as_metadata` | Information about the *AS Metadata* uploaded by your Vault Administrator during profile configuration. |
| `oauthProviderType` | The configured *Authorization Server Provider*. For example, `ADFS` or `Okta`. |

##### Client ID

If the user provides a `client_id` and Client Application client ID mapping is defined on the OAuth 2.0 / OpenID Connect profile, the `as_client_id` field will appear in the response with the Authorization Server client ID value. If there is no defined mapping for the specified `client_id`, Vault will not include the `as_client_id` field in the response. Learn about [Client ID Mapping](https://platform.veevavault.help/en/gr/43329/#client-mapping) in Vault Help.
