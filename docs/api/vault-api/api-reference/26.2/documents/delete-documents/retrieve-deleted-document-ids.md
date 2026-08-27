<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/delete-documents/retrieve-deleted-document-ids/ -->
<!-- title: Retrieve Deleted Document IDs -->

# Retrieve Deleted Document IDs

Retrieve IDs of documents deleted within the past 30 days.

After documents and document versions are deleted, their IDs remain available for retrieval for 30 days. After that, they cannot be retrieved. This request supports optional parameters to narrow the results to a specific date and time range within the past 30 days.

To completely restore a document deleted within the last 30 days, contact Veeva support.

GET`/api/{version}/objects/deletions/documents`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` or `text/csv` |

## Query Parameters

You can modify the request by using one or both of the following parameters:

| Name | Description |
| --- | --- |
| `start_date` | Specify a date (no more than 30 days past) after which Vault will look for deleted documents. Dates must be `YYYY-MM-DDTHH:MM:SSZ` format, for example, 7AM on January 15, 2016 would use `2016-01-15T07:00:00Z` |
| `end_date` | Specify a date (no more than 30 days past) before which Vault will look for deleted documents. Dates must be `YYYY-MM-DDTHH:MM:SSZ` format, for example, 7AM on January 15, 2016 would use `2016-01-15T07:00:00Z` |

Dates and times are in UTC. If the time is not specified, it will default to midnight (T00:00:00Z) on the specified date.

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/deletions/documents
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseMessage": "OK",
   "responseDetails": {
       "total": 3,
       "size": 3,
       "limit": 1000,
       "offset": 0
   },
   "data": [
       {
           "id": 23,
           "major_version_number__v": 0,
           "minor_version_number__v": 1,
           "date_deleted": "2021-02-26T23:46:49Z",
           "global_id__sys": "10000760_23",
           "global_version_id__sys": "10000760_23_39",
           "external_id__v": null,
           "deletion_type": "version_change__sys"
       },
       {
           "id": 7,
           "major_version_number__v": 0,
           "minor_version_number__v": 16,
           "date_deleted": "2021-02-26T23:55:22Z",
           "global_id__sys": "10000760_7",
           "global_version_id__sys": "10000760_7_22",
           "external_id__v": null,
           "deletion_type": "document_version__sys"
       },
       {
           "id": 10,
           "major_version_number__v": "",
           "minor_version_number__v": "",
           "date_deleted": "2021-02-26T23:55:45Z",
           "global_id__sys": "10000760_10",
           "global_version_id__sys": null,
           "external_id__v": null,
           "deletion_type": "document__sys"
       }
   ]
}
```

## Response Details

| Name | Description |
| --- | --- |
| `total` | The total number of deleted documents and document versions. |
| `id` | The ID of the deleted document or version. If the same document has multiple deleted versions, the same ID may appear twice. |
| `major_version_number__v` | The major version of the deleted version. If all versions of the document were deleted (for example, using the *Delete* user action in the Vault UI), this value is blank (`""`). |
| `minor_version_number__v` | The minor version of the deleted version. If all versions of the document were deleted (for example, using the *Delete* user action in the Vault UI), this value is blank (`""`). |
| `date_deleted` | The date and time this document or version was deleted. |
| `global_id__sys` | The global ID of the deleted document or version. |
| `global_version_id__sys` | The global version ID of the deleted document or version. If all versions of the document were deleted (for example, using the *Delete* user action in the Vault UI), this value is `null`. |
| `external_id__v` | The external ID of the deleted document or version. May be `null` if no external ID was set for this document. |
| `deletion_type` | Describes how this document or version was deleted.  * `document__sys`: this document was deleted in full, including all versions. For example, this document was deleted with the *Delete* user action in the Vault UI. * `document_version__sys`: this document version was deleted. For example, this document version was deleted with [Delete Single Document Version](/vault-api/api-reference/26.2/documents/delete-documents/delete-single-document-version) API. * `version_change__sys`: this document version no longer exists, as it became a new major version through the *Set new major version* entry action. |
