<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/groups/retrieve-auto-managed-groups/ -->
<!-- title: Retrieve Auto Managed Groups -->

# Retrieve Auto Managed Groups

Retrieve all Auto Managed groups. Learn more about [Auto Managed groups](https://platform.veevavault.help/en/gr/3200#auto-managed) in Vault Help.

GET`/api/{version}/objects/groups/auto`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Query Parameters

| Name | Description |
| --- | --- |
| `limit` | Paginate the results by specifying the maximum number of records per page in the response. This can be any value between `1` and `1000`. If omitted, defaults to `1000`. |
| `offset` | Paginate the results displayed per page by specifying the amount of offset from the entry returned. For example, if you are viewing the first 50 results (page 1) and want to see the next page, set this to `offset=51`. If omitted, defaults to `0`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/groups/auto
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "group": {
                "members__v": [],
                "active__v": true,
                "security_profiles__v": [],
                "name__v": "msg1394917493801__c",
                "modified_by__v": 1,
                "editable__v": false,
                "allow_delegation_among_members__v": false,
                "modified_date__v": "2019-06-25T19:17:01.000Z",
                "group_description__v": "Periodic Review-Consumer (Auto Managed Group)",
                "system_group__v": false,
                "label__v": "Periodic Review-Consumer",
                "created_date__v": "2019-06-25T19:02:18.000Z",
                "type__v": "Auto Managed Group",
                "id": 1394917493801,
                "created_by__v": 1
            }
        },
        {
            "group": {
                "members__v": [
                    1003079
                ],
                "active__v": true,
                "security_profiles__v": [],
                "name__v": "msg1394917494202__c",
                "modified_by__v": 1003079,
                "editable__v": false,
                "allow_delegation_among_members__v": false,
                "modified_date__v": "2021-10-04T20:43:30.000Z",
                "group_description__v": "Periodic Review-Editor (Auto Managed Group)",
                "system_group__v": false,
                "label__v": "Periodic Review-Editor",
                "created_date__v": "2021-10-04T20:43:30.000Z",
                "type__v": "Auto Managed Group",
                "id": 1394917494202,
                "created_by__v": 1003079
            }
        },
        {
            "group": {
                "members__v": [
                    1003079
                ],
                "active__v": true,
                "security_profiles__v": [],
                "name__v": "msg1394917494201__c",
                "modified_by__v": 1003079,
                "editable__v": false,
                "allow_delegation_among_members__v": false,
                "modified_date__v": "2021-10-04T20:42:35.000Z",
                "group_description__v": "Periodic Review-Viewer (Auto Managed Group)",
                "system_group__v": false,
                "label__v": "Periodic Review-Technical Writer",
                "created_date__v": "2021-10-04T20:42:36.000Z",
                "type__v": "Auto Managed Group",
                "id": 1394917494201,
                "created_by__v": 1003079
            }
        }
    ],
    "responseDetails": {
        "offset": 0,
        "limit": 1000,
        "size": 3,
        "total": 3
    }
}
```
