<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/update-users/update-multiple-users/ -->
<!-- title: Update Multiple Users -->

# Update Multiple Users

Note

Beginning in v18.1, Admins create and manage users with `user__sys` object records. Unless you are updating domain-only users, we strongly recommend using the [Update Object Records](/vault-api/api-reference/26.2/vault-objects/update-object-records) endpoint to update users.

Update information for multiple users at once.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the [standard format](https://datatracker.ietf.org/doc/html/rfc4180).
* The maximum batch size is 500.

PUT`/api/{version}/objects/users`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |

## Body Parameters

Prepare a JSON or CSV input file. You can include any editable user field and
value in the input. Note this endpoint does not support the `security_profile`
attribute for updating profiles.

| Name | Description |
| --- | --- |
| `id` required | The ID of the user to update. |
| `vault_membership` optional | See [Vault Membership](/vault-api/api-reference/26.2/users/update-users) for how to configure. |

[Download Input File](/sample-files/vault-update-users-sample-csv-input.csv)

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id,user_title__v,mobile_phone__v,office_phone__v
11001,Senior Product Manager,+1 (866) 478-9492
11002,Director, Product Management,+1 (925) 452-6500' \
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
         "id":"22124",
         "errors":[
            {
               "type":"INVALID_DATA",
               "message":"Error message describing why this user was not updated."
            }
         ]
      }
   ]
}
```
