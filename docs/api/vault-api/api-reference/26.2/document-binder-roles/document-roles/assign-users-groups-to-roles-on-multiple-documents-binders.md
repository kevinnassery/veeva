<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-binder-roles/document-roles/assign-users-groups-to-roles-on-multiple-documents-binders/ -->
<!-- title: Assign Users & Groups to Roles on Multiple Documents & Binders -->

# Assign Users & Groups to Roles on Multiple Documents & Binders

Assign users and groups to roles on documents and binders in bulk.

* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 1000.

Assigning users and groups to document roles is additive. For example, if groups 1, 2, and 3 are currently assigned to a particular role and you assign groups 3, 4, and 5 to the same role, the final list of groups assigned to the role will be 1, 2, 3, 4, and 5. Users and groups (IDs) in the input that are either invalid (not recognized) or cannot be assigned to a role due to permissions are ignored and not processed.

POST`/api/{version}/objects/documents/roles/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

You can add parameters in the request body or upload them as a CSV file. When adding parameters in the request body, you can only assign one set of users and groups to one set of documents and binders (`docIds`). Use a CSV file to assign different sets of users and groups to different documents and binders by adding multiple rows to the `id` column.

| Name | Description |
| --- | --- |
| `id` conditional | The document or binder ID. Required if uploading a CSV file. |
| `docIds` conditional | A list of document and binder IDs. Required instead of `id` when adding parameters to the request body. |
| `role__v.users` conditional | A string of comma-separated user `id` values for the new role. |
| `role__v.groups` optional | A string of comma-separated user `id` values for the new group. |

For example,

| `id` | `reviewer__v.users` | `reviewer__v.groups` | `approver__v.users` | `approver__v.groups` |
| --- | --- | --- | --- | --- |
| 771 | "12021,12022" | "3311303,3311404" | 22124 | 4411606 |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id,reviewer__v.users,reviewer__v.groups
771,"12021,12022,12023,12124","3311303,4411606"
772,"12021,12022,12023,12124","3311303,4411606"
773,"12021,12022","3311303"' \
https://myvault.veevavault.com/api/v26.2/objects/documents/roles/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 771,
            "reviewer__v.groups": [
                3311303,
                4411606
            ],
            "reviewer__v.users": [
                12021,
                12022,
                12023,
                12124
            ]
        },
        {
            "responseStatus": "SUCCESS",
            "id": 772,
            "reviewer__v.groups": [
                3311303,
                4411606
            ],
            "reviewer__v.users": [
                12021,
                12022,
                12023,
                12124
            ]
        },
        {
           "responseStatus":"FAILURE",
           "id":"773",
           "errors":[
              {
                 "type":"INVALID_DATA",
                 "message":"Error message describing why the users and groups were not assigned to roles on this document.."
              }
           ]
        }
    ]
}
```

## Response Details

The response includes the IDs of the users and groups successfully assigned each role.
