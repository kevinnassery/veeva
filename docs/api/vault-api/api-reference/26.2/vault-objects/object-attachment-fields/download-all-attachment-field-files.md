<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/download-all-attachment-field-files/ -->
<!-- title: Download All Attachment Field Files -->

# Download All Attachment Field Files

Download all *Attachment* field files from the specified object record.

GET`/api/{version}/vobjects/{object_name}/{object_record_id}/attachment_fields/file`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value. For example, `product__v`. |
| `{object_record_id}` | The object record id field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/00P000000000202/attachment_fields/file
```

## Response

Copy to clipboard

```
Content-Type: application/zip;charset=UTF-8
Content-Disposition: attachment;filename="Product - Cholecap - attachment fields.zip"
```

## Response Details

On `SUCCESS`, Vault retrieves the file from the specified *Attachment* field from the object record. The files are packaged in a ZIP file with the file name: `{object label} {object record name} - attachment fields.zip`. When extracted, it will include a subfolder for each *Attachment* field included in the response.

The HTTP Response Header `Content-Type` is set to `application/zip;charset=UTF-8`. The HTTP Response Header `Content-Disposition` contains a filename component which can be used when naming the local file. When downloading files with very small file size, the HTTP Response Header `Content-Length` is set to the size of the file. For most *Attachment* field downloads (larger file sizes), the `Transfer-Encoding` method is set to `chunked` and the `Content-Length` is not displayed.
