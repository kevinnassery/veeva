<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/validate-session-user/ -->
<!-- title: Validate Session User -->

# Validate Session User

Given a valid session ID, this request returns information for the currently authenticated user. If the session ID is not valid, this request returns an `INVALID_SESSION_ID` error `type`. This is similar to a [`whoami` request](https://en.wikipedia.org/wiki/Whoami).

Note

Do not use this API to refresh the current session duration. To do this, use the [Session Keep Alive](/vault-api/api-reference/26.2/authentication/session-keep-alive) API.

GET`/api/{version}/objects/users/me`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `exclude_vault_membership` optional | Set to `false` to include `vault_membership` fields. If omitted, defaults to `true` and `vault_membership` fields are not included in the response. As a best practice to increase performance, please use the default setting and do not set this parameter to `false` unless you need these fields. |
| `exclude_app_licensing` optional | Set to `false` to include `app_licensing` fields. If omitted, defaults to `true` and `app_licensing` fields are not included in the response. As a best practice to increase performance, please use the default setting and do not set this parameter to `false` unless you need these fields. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users/me
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "users": [
       {
           "user": {
               "user_name__v": "tibanez@veepharm.com",
               "user_first_name__v": "Teresa",
               "user_last_name__v": "Ibanez",
               "user_email__v": "teresa.ibanez@veepharm.com",
               "user_timezone__v": "America/Denver",
               "user_locale__v": "en_US",
               "is_domain_admin__v": true,
               "active__v": true,
               "security_policy_id__v": 1863,
               "id": 61603,
               "created_date__v": "2018-01-09T23:07:48.000Z",
               "created_by__v": 1,
               "modified_date__v": "2024-11-13T00:17:17.000Z",
               "modified_by__v": 1,
               "domain_id__v": 3826,
               "last_login__v": "2024-12-11T00:24:12.000Z",
               "user_language__v": "en",
               "group_id__v": [
                   1392631750202,
                   1392631750402,
                   1392631748902
               ],
               "security_profile__v": "vault_owner__v",
               "license_type__v": "full__v"
           }
       }
   ]
}
```

## Response Details

On `SUCCESS`, this request returns information for the currently authenticated user. If the session ID is not valid, this request returns an `INVALID_SESSION_ID` error `type`.

When interpreting the response, understand that the following fields are based on the Vault user, rather than the domain user:

* `created_date__v`
* `created_by__v`
* `modified_date__v`
* `modified_by__v`
* `last_login__v`

##### Delegated Sessions

If the currently authenticated user is in a [delegated session](/vault-api/api-reference/26.2/authentication/delegated-access), this request returns a `delegate_user_id`. For example, if Sophia initiated a delegated session on behalf of Megan, this API call would display Megan’s id and Sophia’s `delegate_user_id`.
