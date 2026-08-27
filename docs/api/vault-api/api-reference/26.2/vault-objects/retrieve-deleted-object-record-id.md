<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/retrieve-deleted-object-record-id/ -->
<!-- title: Retrieve Deleted Object Record ID -->

# Retrieve Deleted Object Record ID

Retrieve the IDs of object records that have been deleted from your Vault within the past 30 days. After object records are deleted from a Vault, their IDs are still available for retrieval for 30 days. After that, they cannot be retrieved. You can use the optional request parameters below to narrow the results to a specific date and time range within the past 30 days.

GET`/api/{version}/objects/deletions/vobjects/{object_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `text/csv` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value (`product__v`, `country__v`, `custom_object__c`, etc.). |

## Query Parameters

| Name | Description |
| --- | --- |
| `start_date` | Specify a date (no more than 30 days past) after which Vault will look for deleted object records. Dates must be `YYYY-MM-DDTHH:MM:SSZ` format, for example, 7AM on January 15, 2016 would use `2016-01-15T07:00:00Z` |
| `end_date` | Specify a date (no more than 30 days past) before which Vault will look for deleted object records. Dates must be `YYYY-MM-DDTHH:MM:SSZ` format, for example, 7AM on January 15, 2016 would use `2016-01-15T07:00:00Z` |
| `limit` | Paginate the results by specifying the maximum number of records per page in the response. This can be any value between `0` and `5000`. If omitted, defaults to `1000`. |
| `offset` | Paginate the results displayed per page by specifying the amount of offset from the entry returned. For example, if you are viewing the first 50 results (page 1) and want to see the next page, set this to `offset=50`. If omitted, defaults to `0`. |

Dates and times are in UTC. If the time is not specified, it will default to midnight (T00:00:00Z) on the specified date.

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/deletions/vobjects/product__v
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
            "id": "V29000000002001",
            "date_deleted": "2022-06-22T15:24:27Z"
        },
        {
            "id": "V29000000003001",
            "date_deleted": "2022-06-23T21:16:25Z"
        },
        {
            "id": "V29000000003002",
            "date_deleted": "2022-06-23T21:16:30Z"
        }
    ]
}
```
