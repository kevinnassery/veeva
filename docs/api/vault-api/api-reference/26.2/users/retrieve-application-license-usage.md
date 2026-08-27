<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/retrieve-application-license-usage/ -->
<!-- title: Retrieve Application License Usage -->

# Retrieve Application License Usage

Retrieve your current license usage compared to the licenses that your organization has purchased. This information is similar to the information displayed in the Vault UI from **Admin > Settings > General Settings**.

Some Vaults use multiple applications, for example, a RIM Vault with Submissions and Registrations. In these Vaults, users have a license value for each application they can access. Application licensing allows Vault to track available licenses at the application level, but does not control a user’s access in most Vaults. A user assigned to multiple applications will use one (1) application license per application. Learn more about [Application Licenses in Vault Help](https://platform.veevavault.help/en/gr/5721/#application-licensing).

GET`/api/{version}/objects/licenses`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/licenses
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "doc_count": {
        "licensed": 4000,
        "used": 2380
    },
    "applications": [
        {
            "application_name": "pm_promomats__v",
            "user_licensing": {
                "full__v": {
                    "licensed": 500,
                    "used": 491,
                    "shared": false
                },
                "external__v": {
                    "licensed": 100,
                    "used": 67,
                    "shared": false
                },
                "read_only__v": {
                    "licensed": 100,
                    "used": 28,
                    "shared": false
                }
            }
        },
        {
            "application_name": "pm_multichannel__v",
            "user_licensing": {
                "full__v": {
                    "licensed": 500,
                    "used": 441,
                    "shared": false
                },
                "external__v": {
                    "licensed": 0,
                    "used": 0,
                    "shared": false
                },
                "read_only__v": {
                    "licensed": 0,
                    "used": 0,
                    "shared": false
                }
            }
        }
    ]
}
```

## Response Details

The response contains the following application license details:

| Name | Description |
| --- | --- |
| `doc_count` | PromoMats and Veeva Medical only: The number of document views across all users with view-based license type against a pre-purchased set of views for the Vault. Learn more about [view-based user licenses in Vault Help](https://platform.veevavault.help/en/gr/5721). |
| `application_name` | The API name of this application license, for example, `pm_promomats__v`. |
| `user_licensing` | An array of the available application licenses for the given `application_name`. |
| `user_licensing.licensed` | The maximum number of users who can be assigned to this application license. For example, if the `full__v` application license has a `licensed` value of `50`, you can assign this license to a maximum of 50 users. |
| `user_licensing.used` | The number of users currently assigned to this application license. To determine the number of application licenses available for assignment, subtract `used` from `licensed`. For example, if your application license has a `licensed` value of `50` and a `used` value of `40`, you can assign 10 more users to this application license. |
| `user_licensing.shared` | Indicates if this user license is shared. |
