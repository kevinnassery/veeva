<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/determine-if-attachments-are-enabled-on-an-object/ -->
<!-- title: Determine if Attachments are Enabled on an Object -->

# Determine if Attachments are Enabled on an Object

GET`/api/{version}/metadata/vobjects/{object_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value (`product__v`, `country__v`, `custom_object__c`, etc.). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/vobjects/site__v
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "object": {
        "created_date": "2014-02-03T20:12:29.000Z",
        "created_by": 1,
        "allow_attachments": true,
        "auditable": true,
        "modified_date": "2015-01-06T22:34:15.000Z",
        "status": [
            "active__v"
        ],
        "urls": {
            "field": "/api/v26.2/metadata/vobjects/site__v/fields/{NAME}",
            "record": "/api/v26.2/vobjects/site__v/{id}",
            "attachments": "/api/v26.2/vobjects/site__v/{id}/attachments",
            "list": "/api/v26.2/vobjects/site__v",
            "metadata": "/api/v26.2/metadata/vobjects/site__v"
        },
        "label_plural": "Study Sites",
        "role_overrides": false,
        "label": "Study Site",
        "in_menu": true,
        "help_content": null,
        "source": "standard",
        "order": null,
        "modified_by": 46916,
        "description": null,
        "name": "site__v"
    }
}
```

## Response Details

If attachments are enabled on the requested object, the response shows `“allow_attachments”: true`, and the list of `urls` includes `attachments`.
