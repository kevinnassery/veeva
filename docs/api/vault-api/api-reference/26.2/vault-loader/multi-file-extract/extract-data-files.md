<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-loader/multi-file-extract/extract-data-files/ -->
<!-- title: Extract Data Files -->

# Extract Data Files

Create a Loader job to extract one or more data files. Learn more about [extracting data files with Vault Loader in Vault Help](https://platform.veevavault.help/en/gr/31536). You can extract a maximum of 10 data objects per request.

POST`/api/{version}/services/loader/extract`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` |
| `Content-Type` | `application/json` |

## Body Parameters

The body of your request should be a JSON file containing the set of data objects to extract.

| Name | Description |
| --- | --- |
| `entity_type` required | The type of entity to extract. The following values are allowed:  * `vobjects__v` * `documents__v` * `document_versions__v` * `document_relationships__v` * `groups__v` |
| `object` conditional | If `entity_type=vobjects__v`, include the object name. For example, `product__v`. |
| `extract_options` optional | Include to specify whether or not to extract renditions, source files, and/or text for the `documents__v` and `document_versions__v` object types. The following values are allowed:  * `include_source__v` * `include_renditions__v` * `include_text__v`  If omitted, Vault returns all document properties in the [Retrieve Loader Extract Results](/vault-api/api-reference/26.2/vault-loader/multi-file-extract/retrieve-loader-extract-results) endpoint. |
| `fields` required | A JSON array with the field information for the specified object type. For example, `id`, `name__v`, `descriptions__v`, etc. |
| `vql_criteria__v` optional | A VQL-like expression used to optionally filter the data set to only those records that meet a specified criterion. Learn more about [Criteria VQL](https://platform.veevavault.help/en/gr/1037069). |

## Query Parameters

| Name | Description |
| --- | --- |
| `sendNotification` | To send a Vault notification when the job completes, set to `true`. If omitted, this defaults to `false` and Vault does not send a notification when the job completes. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
--data-raw '[
{
    "entity_type": "documents__v",
    "extract_options": "include_renditions__v",
    "fields":[
        "id",
        "name__v",
        "type__v"
    ],
    "vql_criteria__v":"site__v=123 MAXROWS 500 SKIP 100"
},
{   
    "entity_type": "vobjects__v",
    "object": "product__v",
    "fields":[
        "id",
        "name__v",
        "object_type__v"
    ],
    "vql_criteria__v":"site__v=123 MAXROWS 500 SKIP 100"
    },
    {
    "entity_type": "groups__v",
    "fields":[
        "id",
        "name__v"
    ]
}
]' \
https://myvault.veevavault.com/api/v26.2/services/loader/extract
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "url": "/api/v26.2/services/jobs/61907",
    "job_id": 61907,
    "tasks": [
        {
            "task_id": "1",
            "entity_type": "documents__v",
            "fields": [
                "id",
                "name__v",
                "type__v"
            ],
            "vql_criteria__v": "site__v=123 MAXROWS 500 SKIP 100",
            "extract_options": "include_renditions__v"
        },
        {
            "task_id": "2",
            "entity_type": "vobjects__v",
            "object": "product__v",
            "fields": [
                "id",
                "name__v",
                "object_type__v"
            ],
            "vql_criteria__v": "site__v=123 MAXROWS 500 SKIP 100"
        },
        {
            "task_id": "3",
            "entity_type": "groups__v",
            "fields": [
                "id",
                "name__v"
            ]
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

| Name | Description |
| --- | --- |
| `job_id` | The Job ID value to retrieve the [status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) of the loader extract request. |
| `tasks` | A set of tasks with a `task_id` for each extract request. |
