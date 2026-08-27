<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-loader/multi-file-load/load-data-objects/ -->
<!-- title: Load Data Objects -->

# Load Data Objects

Create a loader job and load a set of data files. You can load a maximum of 10 data objects per request.

Note

Vault Loader splits loaded datasets into chunks of 500 records to be processed in parallel across multiple available threads. Therefore, the exact order in which data objects are loaded into Vault is not guaranteed. Vault Loader aggregates final execution results to ensure that the resulting success and failure logs maintain a structure that maps back to the order of the original input dataset.

POST`/api/{version}/services/loader/load`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` |
| `Accept` | `application/json` |

## Body Parameters

The body of your request should be a JSON file containing the set of data objects to load.

| Name | Description |
| --- | --- |
| `entity_type` required | The type of entity to load. The following values are allowed:  * `vobjects__v` * `documents__v` * `document_versions__v` * `document_relationships__v` * `groups__v` * `document_roles__v` * `document_versions_roles__v` * `document_renditions__v` * `document_attachments__v` |
| `object` conditional | If the `entity_type=vobjects__v`, include the object name. For example, `product__v`. |
| `action` required | The action type to `create`, `update`, `upsert`, or `delete` data objects. If the `entity_type`=`vobjects__v`, the action types `create_attachments`, `delete_attachments`, `assign_roles`, and `remove_roles` are also available. |
| `file` required | Include the filepath to reference the CSV load file on [file staging](/vault-api/guides/file-staging). |
| `changeobjecttype` conditional | If the `entity_type=vobjects__v` and the `action` is `update` or `upsert`, you can set this to `true` to change the object type of existing object records. This operation is only supported for objects with object types enabled. The CSV load file must include the `id` and `object_type__v` columns. |
| `order` optional | Specifies the order of the load task. |
| `idparam` optional | Identify object records by any unique field value. Can only be used if `entity_type` is `vobjects__v` and `action` is `upsert`, `update`, or `delete`. You can use any object field which has `unique` set to `true` in the object metadata. For example, `idparam=external_id__v`. |
| `recordmigrationmode` optional | Set to `true` to create, update, or delete object records in a noninitial state and with minimal validation, bypass rules such as entry criteria, create inactive records, and set system-managed fields such as `created_by__v`. Does not bypass record triggers. Use `notriggers` to bypass triggers. The `recordmigrationmode` parameter can only be used if `entity_type` is `vobjects__v` and `action` is `create`, `update`, or `upsert`. Vault does not send notifications in Record Migration Mode. You must have the [Record Migration](https://platform.veevavault.help/en/gr/22824#vault-owner-actions) permission to use this parameter. Learn more about [Record Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/761685). |
| `notriggers` optional | If set to `true`, [Record](https://platform.veevavault.help/en/gr/761685) or [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) bypasses record or document triggers. |
| `documentmigrationmode` optional | Set to `true` to create documents, document versions, document version roles, or document renditions in a specific state or state type. Also allows you to set the name, document number, and version number. For `update` actions, only allows you to manually reset document numbers. Vault does not send notifications in Document Migration Mode. You must have the [Document Migration](https://platform.veevavault.help/en/gr/22824#vault-owner-actions) permission to use this parameter. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |

## Query Parameters

| Name | Description |
| --- | --- |
| `sendNotification` | To send a Vault notification when the job completes, set to `true`. If omitted, this defaults to `false` and Vault does not send a notification when the job completes. |

#### About File Validation

Vault evaluates header rows in CSV load files to ensure they include all required fields. Required fields vary depending on the `object_type` and `action`. Learn more about Vault Loader input files for [documents](https://platform.veevavault.help/en/gr/26605#preparing), [document roles](https://platform.veevavault.help/en/gr/26613#preparing), [document attachments](https://platform.veevavault.help/en/gr/67267#prepare), [objects](https://platform.veevavault.help/en/gr/26607#prepare), and [object attachments](https://platform.veevavault.help/en/gr/67288#prepare) in Vault Help.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
- H "Content-Type: application/json" \
--data-raw '[
  {
    "entity_type": "documents__v",
    "action": "create",
    "file": "documents.csv",
    "documentmigrationmode": true,
    "order": 1
  },
  {
    "entity_type": "vobjects__v",
    "object": "veterinary_patient__c",
    "action": "create",
    "file": "patients.csv",
    "recordmigrationmode": true,
    "order": 2
  },
  {
    "entity_type": "vobjects__v",
    "object": "product__v",
    "action": "upsert",
    "file": "products.csv",
    "order": 3,
    "idparam": "external_id__v"
  },
  {
    "entity_type": "groups__v",
    "action": "update",
    "file": "groups.csv",
    "order": 4
  },
  {
    "entity_type": "vobjects__v",
    "object": "product__v",
    "action": "update",
    "changeobjecttype": true,
    "file": "change_object_type.csv",
    "order": 5,
    "idparam": "id"
  }
]' \
https://myvault.veevavault.com/api/v26.2/services/loader/load
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "url": "/api/v26.2/services/jobs/92201",
    "job_id": 92201,
    "tasks": [
        {
            "task_id": "1",
            "entity_type": "documents__v",
            "action": "create",
            "documentmigrationmode": true,
            "file": "documents.csv"
        },
        {
            "task_id": "2",
            "entity_type": "vobjects__v",
            "object": "veterinary_patient__c",
            "action": "create",
            "recordmigrationmode": true,
            "file": "patients.csv"
        },
        {
            "task_id": "3",
            "entity_type": "vobjects__v",
            "object": "product__v",
            "action": "upsert",
            "idparam": "external_id__v",
            "file": "products.csv"
        },
        {
            "task_id": "4",
            "entity_type": "groups__v",
            "action": "update",
            "file": "groups.csv"
        },
	    {
            "task_id": "5",
            "entity_type": "vobjects__v",
            "object": "product__v",
            "action": "update",
            "idparam": "id",
            "changeobjecttype": true,
            "file": "change_object_type.csv"
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

| Name | Description |
| --- | --- |
| `job_id` | The Job ID value to retrieve the [status](/vault-api/api-reference/26.2/jobs/retrieve-job-status) of the loader extract request. |
| `tasks` | The `task_id` for each load request. |
