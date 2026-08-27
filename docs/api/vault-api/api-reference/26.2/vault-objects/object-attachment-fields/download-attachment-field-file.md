<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/download-attachment-field-file/ -->
<!-- title: Download Attachment Field File -->

# Download Attachment Field File

Download the specified *Attachment* field file from an object record.

GET`/api/{version}/vobjects/{object_name}/{object_record_id}/attachment_fields/{attachment_field_name}/file`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value. For example, `product__v`. |
| `{object_record_id}` | The object record `id` field value. |
| `{attachment_field_name}` | The name of the *Attachment* field from which to retrieve the file. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/00P000000000202/attachment_fields/file__c/file
```

## Response

Copy to clipboard

```
Content-Type: application/pdf;charset=UTF-8
Content-Disposition: attachment;filename="file.pdf"
```

## Response Details

On `SUCCESS`, Vault retrieves the file from the specified *Attachment* field from the object record. The file name is the same as the *Attachment* field file name.

The HTTP Response Header `Content-Type` is set to the MIME type of the file. For example, if the file is a PNG image, the `Content-Type` is `image/png`. If we cannot detect the MIME file type, `Content-Type` is set to `application/octet-stream`. The HTTP Response Header `Content-Disposition` contains a filename component which can be used when naming the local file. When downloading files with very small file size, the HTTP Response Header `Content-Length` is set to the size of the file. For most *Attachment* fields (larger file sizes), the `Transfer-Encoding` method is set to `chunked` and the `Content-Length` is not displayed.
