<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/retrieve-deleted-document-attachments/ -->
<!-- title: Retrieve Deleted Document Attachments -->

# Retrieve Deleted Document Attachments

Retrieve IDs of document attachments deleted within the past 30 days. Learn more about [document attachments in Vault Help](https://platform.veevavault.help/en/gr/58613).

After document attachments and attachment versions are deleted, their IDs remain available for retrieval for 30 days. After that, they cannot be retrieved.

GET`/api/{version}/objects/deletions/documents/attachments`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `start_date` | Specify a date (no more than 30 days past) after which Vault will look for deleted document attachments. Dates must be `YYYY-MM-DDTHH:MM:SSZ` format, for example, 7AM on January 15, 2016 would use `2016-01-15T07:00:00Z`. Dates and times are in UTC. If the time is not specified, it will default to midnight (T00:00:00Z) on the specified date. |
| `end_date` | Specify a date (no more than 30 days past) before which Vault will look for deleted document attachments. Dates must be `YYYY-MM-DDTHH:MM:SSZ` format, for example, 7AM on January 15, 2016 would use `2016-01-15T07:00:00Z`. Dates and times are in UTC. If the time is not specified, it will default to midnight (T00:00:00Z) on the specified date. |
| `limit` | Paginate the results by specifying the maximum number of deleted attachments to display per page in the response. This can be any value between `0` and `5000`. If omitted, defaults to `1000`. |

## Request

Copy to clipboard

```
curl --location 'https://myvault.veevavault.com/api/v26.2/objects/deletions/documents/attachments' \
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
       "total": 2,
       "size": 2,
       "limit": 1000,
       "offset": 0
   },
   "data": [
       {
           "id": 301,
           "version": "",
           "date_deleted": "2025-05-17T01:54:27Z",
           "external_id__v": null,
           "global_id__sys": "19523_148",
           "global_version_id__sys": null,
           "deletion_type": "attachment__sys"
       },
       {
           "id": 302,
           "version": "",
           "date_deleted": "2025-05-17T01:54:31Z",
           "external_id__v": null,
           "global_id__sys": "19523_148",
           "global_version_id__sys": null,
           "deletion_type": "attachment__sys"
       }
   ]
}
```

## Response Details

| Name | Description |
| --- | --- |
| `total` | The total number of deleted document attachments or attachment versions. |
| `id` | The ID of this deleted document attachment or attachment version. |
| `version` | The version of this deleted document attachment. If all versions of the attachment were deleted, this value is blank (`""`). Unlike documents, document attachments do not have minor versions. Learn more about [attachment versioning in Vault Help](https://platform.veevavault.help/en/gr/58613/#versioning). |
| `date_deleted` | The date and time this document attachment or attachment version was deleted. |
| `external_id__v` | The external ID of this deleted document attachment or attachment version. May be `null` if no external ID was set for this document attachment. |
| `global_id__sys` | The global ID of this deleted document attachment or attachment version. |
| `global_version_id__sys` | The global version ID of this deleted document attachment or attachment version. If all versions of the document were deleted, this value is `null`. |
| `deletion_type` | Describes how this document attachment or attachment version was deleted.  * `attachment__sys`: this document attachment was deleted in full, including all versions. For example, this document attachment was deleted with the Delete user action in the Vault UI, or with Vault API. * `attachment_version__sys`: this document attachment version was deleted. For example, this document attachment version was deleted with the [Delete Single Document Attachment Version](/vault-api/api-reference/26.2/documents/document-attachments/delete-single-document-attachment-version) API. |
