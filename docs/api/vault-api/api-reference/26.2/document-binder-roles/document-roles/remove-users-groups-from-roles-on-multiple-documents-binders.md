<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-binder-roles/document-roles/remove-users-groups-from-roles-on-multiple-documents-binders/ -->
<!-- title: Remove Users & Groups from Roles on Multiple Documents & Binders -->

# Remove Users & Groups from Roles on Multiple Documents & Binders

Remove users and groups from roles on documents and binders in bulk.

* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 1000.

DELETE`/api/{version}/objects/documents/roles/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

You can add parameters in the request body or upload them as a CSV file. When adding parameters in the request body, you can only remove the same set of users and groups from the same set of documents and binders (`docIds`). Use a CSV file to remove different sets of users and groups from different documents or binders by adding multiple rows to the `id` column.

| Name | Description |
| --- | --- |
| `id` conditional | The document or binder ID. Required if uploading a CSV file. |
| `docIds` conditional | A list of document and binder IDs. Required instead of `id` when adding parameters to the request body. |
| `role__v.users` optional | A string of comma-separated user `id` values to remove. |
| `role__v.groups` optional | A string of comma-separated group `id` values to remove. |

For example,

| `id` | `reviewer__v.users` | `reviewer__v.groups` | `approver__v.users` | `approver__v.groups` |
| --- | --- | --- | --- | --- |
| 771 | "12021,12022" | "3311303,3311404" | 22124 | 4411606 |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: application/json" \
--data-raw 'id,coordinator__v.users,consumer__v.users
5,"1008313","1006595"' \
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
            "id": 5,
            "coordinator__v.users": [
                1008313
            ],
            "consumer__v.users": [
                1006595
            ]
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response lists the IDs of the users or groups removed from the provided document roles. On `FAILURE`, the response returns an error message describing the reason for the failure. For example, a user or group may not be removed if the role assignment is system-managed.
