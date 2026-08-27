<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/create-users/create-multiple-users/ -->
<!-- title: Create Multiple Users -->

# Create Multiple Users

Note

Beginning in v18.1, Admins create and manage users with `user__sys` object records. Unless you are adding cross-domain or VeevaID users or adding users to a domain without assigning Vault membership, we strongly recommend using the [Create Object Records](/vault-api/api-reference/26.2/vault-objects/create-upsert-object-records) endpoint to create new users.

Create new users and assign them to Vaults in bulk. You can also add multiple existing users as cross-domain users or VeevaID users.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

POST`/api/{version}/objects/users`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |

## Body Parameters

Prepare a JSON or CSV input file. You may add values to any other editable user field, unless you are adding a [cross-domain](/vault-api/api-reference/26.2/users/create-users/create-multiple-users/#Cross_Domain_Users) user or [VeevaID](/vault-api/api-reference/26.2/users/create-users/create-multiple-users/#VeevaID) user.
See [Retrieve Users](/vault-api/api-reference/26.2/users/retrieve-all-users) for all possible values.
Using only the required fields will add users to your domain but will not assign them to individual Vaults within your domain.
To assign users to individual Vaults, you must also use the required [Vault Membership](/vault-api/api-reference/26.2/users/update-users) parameters.

| Name | Description |
| --- | --- |
| `user_name__v` required | The user’s Vault username (login credential). For example, `ewoodhouse@veepharm.com` |
| `user_first_name__v` required | The user's first name. |
| `user_last_name__v` required | The user's last name. |
| `user_email__v` required | The user's email address. |
| `user_timezone__v` required | The user's time zone. Retrieve values from [Retrieve Users](/vault-api/api-reference/26.2/users/retrieve-all-users). |
| `user_locale__v` required | The user's location. Retrieve values from [Retrieve Users](/vault-api/api-reference/26.2/users/retrieve-all-users). |
| `security_policy_id__v` required | The user's security policy. Retrieve values from [Retrieve All Security Policies](/vault-api/api-reference/26.2/security-policies/retrieve-all-security-policies). |
| `user_language__v` required | The user's preferred language. Retrieve values from [Retrieve Users](/vault-api/api-reference/26.2/users/retrieve-all-users). |
| `domain` optional | If you set this to `true`, the user will not be assigned to a Vault. |
| `security_profile__v` optional | The user’s security profile. If omitted, the default value is `document_user__v`. |
| `license_type__v` optional | The license type is the first level of access control that Vault applies to a user. If your Vault utilizes user-based licensing, assign application licensing using the `app_licensing` field. |
| `vault_membership` optional | Use this field to assign a user to individual Vaults within your domain. This is required to create cross-domain users or VeevaID users. Learn how to configure this parameter in the [Vault Membership](/vault-api/api-reference/26.2/users/update-users) section. |
| `app_licensing` optional | Use this field to assign a user to individual applications within your Vault. Learn how to configure this parameter in the [Application Licensing](/vault-api/api-reference/26.2/users/update-users) section. |

## Vault Membership

To assign user permissions across Vaults, create cross-domain users,or create VeevaID users, you must include the `vault_membership` column configured with the following fields:

| Name | Description |
| --- | --- |
| `vault_id` required | The Vault ID to assign the user to. |
| `active__v` optional | Set the user to active (`true`) or inactive (`false`). If not specified, default value is `true`. |
| `security_profile__v` optional | Set the user's security profile, for example, `read_only_user__v`. If not specified, this value defaults to `document_user__v`. |
| `license_type__v` optional | Set the user's license type, for example, `read_only__v`. If not specified, this value defaults to `full__v`. |

For example, to add an active user to Vault ID 3003 with the `system_admin__v` security profile and the `full__v` license type:

| `vault_membership` |
| --- |
| `3003`:`true`:`system_admin__v`:`full__v` |

## Application Licensing

To add a user to specific applications within a Vault or across Vaults, you must include the `app_licensing` column configured with the following fields:

| Name | Description |
| --- | --- |
| `vault_id` required | The Vault ID to assign the user to. |
| `active__v` optional | Set the user to active (`true`) or inactive (`false`). If not specified, default value is `true`. |
| `application_name` required | The application to add the user to. For example, use `rimReg_v` to assign a user to the RIM Registrations application. |
| `license_type__v` optional | Set the user's license type for a specific application, for example, `read_only__v`. You must select a license value for at least one application. Possible values are:  * `full__v` * `external__v` * `learner_user__v` * `read_only__v`  Some license values may be invalid depending on the application. The `license_type__v` for an application cannot be more permissive than the user's Vault-wide license type. If omitted, the default value is `full__v`. The request fails if you provide an invalid `license_type__v` value for a specific application. Learn more about [valid license values by application in Vault Help](https://platform.veevavault.help/en/gr/5721#application-license). |

The format for adding these fields is:

`{vault_id}|{application_name}{:active__v}{:license_type__v}`

To add a user to more than one application, separate the applications with a pipe. To add a user to applications in multiple Vaults, separate the Vaults with a semicolon. For example:

| `app_licensing` |
| --- |
| `3003`|`rimReg_v:true:full__v`|`rimSubs_v:true:full__v;4112`|`rimSubs_v:true:full__v` |

This adds an active user to both RIM Registrations and RIM Submissions in Vault ID 3003, and to the RIM Submissions application in Vault ID 4112, all with the `full__v` license type.

## Add Cross-Domain Users

The following are the only fields required to add cross-domain users. All other fields are ignored. Learn more about cross-domain users in [Vault Help](https://platform.veevavault.help/en/gr/38996).

| Name | Description |
| --- | --- |
| `user_name__v` required | The user’s Vault username (login credential). For example, `ewoodhouse@veepharm.com`. |
| `vault_membership` required | Assign this user permissions across domains. Learn how to configure this parameter in the [Vault Membership](/vault-api/api-reference/26.2/users/update-users) section. |

## Add VeevaID Users

The following are the only fields required to add an existing VeevaID user to Vault. All other fields are ignored.

| Name | Description |
| --- | --- |
| `user_name__v` required | The user’s Vault username (login credential). For example, `ewoodhouse@veepharm.com`. |
| `vault_membership` required | Assign this user permissions across domains. Learn how to configure this parameter in the [Vault Membership](/vault-api/api-reference/26.2/users/update-users) section. |
| `security_policy_id__v` required | The `name__v` value of your Vault’s VeevaID security profile, for example, `25285`. You can retrieve this ID from the [Retrieve All Security Policies](/vault-api/api-reference/26.2/security-policies/retrieve-all-security-policies) endpoint. |

## Upsert Users

Upsert is a combination of create and update. Use one input file to create new users and update existing users at the same time. If a matching user record is found in your Vault, it is updated with the field values specified in the input. If no matching user record is found, a new user is created using values in the input.

### Query Parameters

| Name | Description |
| --- | --- |
| `operation` | To upsert users, you must include `operation=upsert` |
| `idParam` | To upsert users, you must include either `idParam=id` or `idParam=user_name__v` to the request endpoint. |

[Download Input File](/sample-files/vault-create-users-sample-csv-input.csv)

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'user_name__v,user_first_name__v,user_last_name__v,user_email__v,user_timezone__v,user_locale__v,user_language__v,security_policy_id__v,vault_membership,app_licensing
jim@veevapharm.com,Jim,Nabors,jim@veevapharm.com,America/Denver,en_US,en,821,3003:true:business_admin__v:full__v,3003|rimSubs_v:true:full__v
steve@veevapharm.com,Steve,Perry,steve@veevapharm.com,Europe/London,en_GB,en,821,3003:true:document_user__v:full__v,3003|rimSubs_v:true:full__v
megan@veevapharm.com,Megan,Murray,megan@veevapharm.com,Australia/Sydney,en_AU,en,554,4114:true:system_admin__v:full__v,3003|rimSubs_v:true:full__v|rimSubsArch_v:true:full__v
igor@veevapharm.com,Igor,Sikorsky,igor@veevapharm.com,Asia/Shanghai,zh_CN,zh_CN,554,3003:true:document_user__v:full__v,3003|rimSubs_v:true:full__v|rimSubsArch_v:true:full__v;4114rimReg_v:true:full__v' \
https://myvault.veevavault.com/api/v26.2/objects/users
```

## Response

Copy to clipboard

```
{
   "responseStatus":"SUCCESS",
   "data":[
      {
         "responseStatus":"SUCCESS",
         "id":"12021"
      },
      {
         "responseStatus":"SUCCESS",
         "id":"12022"
      },
      {
         "responseStatus":"SUCCESS",
         "id":"12023"
      },
      {
         "responseStatus":"FAILURE",
         "errors":[
            {
               "type":"INVALID_DATA",
               "message":"Error message describing why this user was not created."
            }
         ]
      }
   ]
}
```

## Response Details

On `SUCCESS`, Vault responds will list the `id` of each user. The order results are displayed in the response is the same as the order of records in the input.
