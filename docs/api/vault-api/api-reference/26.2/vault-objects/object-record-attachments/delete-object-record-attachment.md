<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/delete-object-record-attachment/ -->
<!-- title: Delete Object Record Attachment -->

# Delete Object Record Attachment

DELETE`/api/{version}/vobjects/{object_name}/{object_record_id}/attachments/{attachment_id}`

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

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/571
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```
