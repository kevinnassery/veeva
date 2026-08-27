<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/delete-object-record-attachment-version/ -->
<!-- title: Delete Object Record Attachment Version -->

# Delete Object Record Attachment Version

DELETE`/api/{version}/vobjects/{object_name}/{object_record_id}/attachments/{attachment_id}/versions/{attachment_version}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value (`product__v`, `country__v`, `custom_object__c`, etc.). |
| `{object_record_id}` | The object record `id` field value. |
| `{attachment_id}` | The attachment `id` field value. |
| `{attachment_version}` | The attachment `version__v` field value. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/571/versions/1
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```
