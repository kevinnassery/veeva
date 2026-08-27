<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/retrieve-deleted-object-record-attachments/ -->
<!-- title: Retrieve Deleted Object Record Attachments -->

# Retrieve Deleted Object Record Attachments

Retrieve IDs of object attachments deleted within the past 30 days. Learn more about [object record attachments in Vault Help](https://platform.veevavault.help/en/gr/58613).

After object record attachments and attachment versions are deleted, their IDs remain available for retrieval for 30 days. After that, they cannot be retrieved.

This API cannot retrieve attachments in [attachment fields](https://platform.veevavault.help/en/gr/15057).

GET`/api/{version}/objects/deletions/vobjects/{object_name}/attachments`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` or `text/csv` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object from which to retrieve deleted attachments. |

## Query Parameters

| Name | Description |
| --- | --- |
| `start_date` | Specify a date (no more than 30 days past) after which Vault will look for deleted object record attachments. Dates must be `YYYY-MM-DDTHH:MM:SSZ` format, for example, 7AM on January 15, 2016 would use `2016-01-15T07:00:00Z`. Dates and times are in UTC. If the time is not specified, it will default to midnight (T00:00:00Z) on the specified date. |
| `end_date` | SSpecify a date (no more than 30 days past) before which Vault will look for deleted object record attachments. Dates must be `YYYY-MM-DDTHH:MM:SSZ` format, for example, 7AM on January 15, 2016 would use `2016-01-15T07:00:00Z`. Dates and times are in UTC. If the time is not specified, it will default to midnight (T00:00:00Z) on the specified date. |
| `limit` | Paginate the results by specifying the maximum number of deleted attachments to display per page in the response. This can be any value between `0` and `5000`. If omitted, defaults to `1000`. |

## Request

Copy to clipboard

```
curl --location 'https://myvault.veevavault.com/api/v26.2/objects/deletions/vobjects/campaign__c/attachments' \
--header 'Accept: application/json' \
--header 'Authorization: {AUTH_VALUE}' \
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseMessage": "OK",
   "responseDetails": {
       "total": 1,
       "size": 1,
       "limit": 1000,
       "offset": 0
   },
   "data": [
       {
           "id": 1501,
           "version": "",
           "date_deleted": "2025-05-17T02:26:49Z",
           "external_id__v": null,
           "record_id": "OBE00000000H001",
           "deletion_type": "attachment__sys"
       }
   ]
}
```

## Response Details

| Name | Description |
| --- | --- |
| `total` | The total number of deleted object record attachments or attachment versions. |
| `id` | The ID of this deleted object record attachment or attachment version. |
| `version` | The version of this deleted object record attachment. If all versions of the attachment were deleted, this value is blank (`""`). |
| `date_deleted` | The date and time this object record attachment or attachment version was deleted. |
| `external_id__v` | The external ID of this deleted object record attachment or attachment version. May be `null` if no external ID was set for this attachment. |
| `global_id__sys` | The global ID of this deleted object record attachment or attachment version. |
| `global_version_id__sys` | The global version ID of this deleted object record or version. If all versions of the document were deleted, this value is `null`. |
| `deletion_type` | Describes how this object record attachment or attachment version was deleted.  * this object record attachment was deleted in full, including all versions. For example, this document attachment was deleted with the Delete user action in the Vault UI, or with Vault API. * `attachment_version__sys`: this object record attachment version was deleted. For example, this attachment version was deleted with the [Delete Single Object Record Attachment Version](/vault-api/api-reference/26.2/vault-objects/object-record-attachments/delete-object-record-attachment-version) API. |
