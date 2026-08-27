<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/download-object-record-attachment-file/ -->
<!-- title: Download Object Record Attachment File -->

# Download Object Record Attachment File

Downloads the latest version of the specified attachment from the object record.

GET`/api/{version}/vobjects/{object_name}/{object_record_id}/attachments/{attachment_id}/file`

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
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/571/file
```

## Response

Copy to clipboard

```
Content-Type: application/pdf;charset=UTF-8
Content-Disposition: attachment;filename="file.pdf"
```

## Response Details

The HTTP Response Header `Content-Type` is set to the MIME type of the file. For example, if the attachment is a PNG image, the `Content-Type` is image/png. If we cannot detect the MIME file type, `Content-Type` is set to `application/octet-stream`. The HTTP Response Header `Content-Disposition` contains a filename component which can be used when naming the local file. When downloading attachments with very small file size, the HTTP Response Header `Content-Length` is set to the size of the attachment. Note that for most attachments (larger file sizes), the `Transfer-Encoding` method is set to `chunked` and the `Content-Length` is not displayed.
