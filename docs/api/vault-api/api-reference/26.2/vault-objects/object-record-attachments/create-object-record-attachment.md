<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/create-object-record-attachment/ -->
<!-- title: Create Object Record Attachment -->

# Create Object Record Attachment

Create a single object record attachment. If the attachment already exists, Vault uploads the attachment as a new version of the existing attachment. Learn more about [attachment versioning in Vault Help](https://platform.veevavault.help/en/gr/24287#version-specific).

POST`/api/{version}/vobjects/{object_name}/{object_record_id}/attachments`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `multipart/form-data` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value (`product__v`, `country__v`, `custom_object__c`, etc.). |
| `{object_record_id}` | The object record `id` field value. |

#### File Upload

To upload the file, use the multi-part attachment with the file component `"file={file_name}"`. The maximum allowed file size is 4GB.

If an attachment is added which has the same filename as an existing attachment on a given object record, the new attachment is added as a new version of the existing attachment. If an attachment is added which *is* exactly the same (same MD5 checksum value) as an existing attachment on a given object record, the new attachment is not added.

The following attribute values are determined based on the file in the request: `filename__v`, `format__v`, `size__v`.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: multipart/form-data" \
-F "file=my_attachment_file.png" \
https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data":
    [{
        "id": "558",
        "version__v": 3
    }]
}
```
