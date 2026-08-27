<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/update-object-record-attachment-description/ -->
<!-- title: Update Object Record Attachment Description -->

# Update Object Record Attachment Description

PUT`/api/{version}/vobjects/{object_name}/{object_record_id}/attachments/{attachment_id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value (`product__v`, `country__v`, `custom_object__c`, etc.). |
| `object_record_id}` | The object record `id` field value. |
| `{attachment_id}` | The attachment `id` field value. |

## Body Parameters

| Name | Description |
| --- | --- |
| `description__v` required | This is the only editable field. The maximum length is 1000 characters. |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "description__v=This is my description for this attachment." \
https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/571
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```
