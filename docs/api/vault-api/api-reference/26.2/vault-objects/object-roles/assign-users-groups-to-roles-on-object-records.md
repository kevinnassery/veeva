<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-roles/assign-users-groups-to-roles-on-object-records/ -->
<!-- title: Assign Users & Groups to Roles on Object Records -->

# Assign Users & Groups to Roles on Object Records

Assign users and groups to roles on an object record in bulk.

* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

Assigning users and groups to roles is additive, and duplicate groups are ignored. For example, if groups 1 and 2 are currently assigned to a particular role and you assign groups 2 and 3 to the same role, the final list of groups assigned to the role will be 1, 2, and 3.

POST`/api/{version}/vobjects/{object_name}/roles`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/json` |
| `Accept` | `application/json` (default), `text/csv`, or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object where you want to update records. |

## Body Parameters

Prepare a JSON or CSV input file. User and group assignments are ignored if they are invalid, inactive, or already exist.

| Name | Description |
| --- | --- |
| `id` required | The object record ID. |
| `role__v.users` optional | A string of user `id` values for the new role. |
| `role__v.groups` optional | A string of group `id` values for the new role. |

See Example JSON Request Body in the right-hand column, or click the button below to download a sample CSV input file.

[Download Input File](/sample-files/vault_assign_object_record_roles.csv)

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw '[
  {
    "id": "OBE000000000412",
    "roles": [
      {
        "role": "content_creator__c",
        "users": "61590"
      }
      ]
  }
]' \
https://myvault.veevavault.com/api/v26.2/vobjects/campaign__c/roles
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "OBE000000000412"
            }
        }
    ]
}
```

## Response Details

On `SUCCESS`, The response includes the object record `id`.
