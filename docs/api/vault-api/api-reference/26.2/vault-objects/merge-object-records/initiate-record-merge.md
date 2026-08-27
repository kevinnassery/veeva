<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/merge-object-records/initiate-record-merge/ -->
<!-- title: Initiate Record Merge -->

# Initiate Record Merge

Initiate a record merge operation in bulk. Starts a record merge job.
When merging two records together, you must select one record to be the `main_record_id` and one record to be the `duplicate_record_id`. The merging process updates all inbound references (including attachments) from other objects that point to the `duplicate` record and moves those over to the `main` record. Field values on the`main` record are not changed, and when the process is complete, the `duplicate` record is deleted. Record merges do not trigger [record triggers](/vault-sdk/entry-points/triggers/record-triggers/).

You can only merge two records together in a single operation, one `main` record and one `duplicate` record. This is called a merge set. If you have multiple `duplicate` records you wish to merge into the same`main` record, you need to create multiple merge sets and execute multiple record merges.

* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 10 merge sets.
* The maximum number of concurrent merge requests is 500.

The object must have **Enable Merges** configured, and the initiating user must have the correct permission such as the *Application: Object: Merge Records* permission. Learn more about the [configuration required for record merges in Vault Help](https://platform.veevavault.help/en/gr/659058).

Note

In Clinical Operations Vaults, this endpoint does not support merging *Person* (`person__sys`), *Organization* (`organization__v`), *Location* (`location__v`), or *Contact Information* (`contact_information__clin`) records. Instead, use [Initiate Clinical Record Merge](/clinical/vault-api/api-reference/26.2/clinical-operations/initiate-clinical-record-merge).

POST`/api/{version}/vobjects/{object_name}/actions/merge`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value. For example, `account__v`. This object must have **Enable Merges** configured. |

## Body Parameters

Upload parameters as a JSON or CSV file. You can merge up to 10 merge sets at once.

| Name | Description |
| --- | --- |
| `duplicate_record_id` required | The ID of the `duplicate` record. Each `duplicate_record_id` can only be merged into one `main_record_id` record. When the merging process is complete, Vault deletes this record. |
| `main_record_id` required | The ID of the `main` record. The merging process updates all inbound references (including attachments) from other objects that point to the `duplicate` record and moves those over to the `main` record. Vault does not change field values on the `main` record. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
--data-raw '[
   {
       "duplicate_record_id" : "0V0000000000003",
       "main_record_id" : "0V0000000000013"
   },
   {
       "duplicate_record_id" : "0V0000000000004",
       "main_record_id" : "0V0000000000013"
   },
   {
       "duplicate_record_id" : "0V0000000000005",
       "main_record_id" : "0V0000000000010"
   }
]' \
https://myvault.veevavault.com/api/v26.2/vobjects/account__v/actions/merge
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "job_id": 863204
   }
}
```

## Response Details

On `SUCCESS`, the job has successfully started and the response includes a `job_id`. On `FAILURE`, the job failed to start. There is no partial success.
