<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/retrieve-user/ -->
<!-- title: Retrieve User -->

# Retrieve User

Note

This endpoint retrieves user records at the domain level. Beginning in v18.1, Admins create and manage users with `user__sys` object records. We strongly recommend using the [Retrieve Object Record](/vault-api/api-reference/26.2/vault-objects/retrieve-object-record) endpoint to retrieve a `user__sys` record.

Retrieve information for one user. To get information for all users, see [Retrieve All Users](/vault-api/api-reference/26.2/users/retrieve-all-users).

GET`/api/{version}/objects/users/{id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{id}` | The user `id` field value. To get information for the currently authenticated user, see [Validate Session User](/vault-api/api-reference/26.2/users/validate-session-user). |

## Query Parameters

| Name | Description |
| --- | --- |
| `exclude_vault_membership` | Optional: Set to `false` to include `vault_membership` fields. Including these fields may decrease performance. If omitted, `vault_membership` fields are not included in the response. |
| `exclude_app_licensing` | Optional: Set to `false` to include `app_licensing` fields. Including these fields may decrease performance. If omitted, `app_licensing` fields are not included in the response. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/users/1006546
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "users": [
       {
           "user": {
               "user_name__v": "olive@veepharm.com",
               "user_first_name__v": "Olivia",
               "user_last_name__v": "Cattington",
               "user_email__v": "olivia.cattington@veepharm.com",
               "user_timezone__v": "America/Los_Angeles",
               "user_locale__v": "en_US",
               "user_title__v": "Senior Vice President for Research & Development",
               "is_domain_admin__v": false,
               "active__v": true,
               "domain_active__v": true,
               "security_policy_id__v": 1000181,
               "user_needs_to_change_password__v": false,
               "id": 1006546,
               "created_date__v": "2022-05-23T20:49:06.000Z",
               "created_by__v": 1003079,
               "modified_date__v": "2022-06-16T17:22:49.000Z",
               "modified_by__v": 1,
               "domain_id__v": 1000076,
               "domain_name__v": "veepharm.com",
               "vault_id__v": [
                   1000660,
                   1000659
               ],
               "last_login__v": "2022-05-23T21:01:13.000Z",
               "user_language__v": "en",
               "company__v": "Veepharm",
               "group_id__v": [
                   1,
                   1394917493302,
                   6
               ],
               "security_profile__v": "vault_owner__v",
               "license_type__v": "full__v"
           }
       }
   ]
}
```
