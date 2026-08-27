<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/update-attachment-field-file/ -->
<!-- title: Update Attachment Field File -->

# Update Attachment Field File

Update an *Attachment* field by uploading a file. If you need to update more than one *Attachment* field, it is best practice to update in bulk with [Update Object Records](/vault-api/api-reference/26.2/vault-objects/update-object-records).

POST`/api/{version}/vobjects/{object_name}/{object_record_id}/attachment_fields/{attachment_field_name}/file`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value. For example, `product__v`. |
| `{object_record_id}` | The object record `id` field value. |
| `{attachment_field_name}` | The `name` of the *Attachment* field to update. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/00P000000000202/attachment_fields/file__c/file \
--form 'file=@"Cholecap Prescribing Information.doc"'
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "00P000000000202",
                "url": "/api/v26.2/vobjects/product__v/00P000000000202"
            }
        }
    ]
}
```
