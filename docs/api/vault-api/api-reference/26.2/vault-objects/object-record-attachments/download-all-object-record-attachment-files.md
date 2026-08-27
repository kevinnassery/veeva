<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/download-all-object-record-attachment-files/ -->
<!-- title: Download All Object Record Attachment Files -->

# Download All Object Record Attachment Files

Downloads the latest version of all attachments from the specified object record.

GET`/api/{version}/vobjects/{object_name}/{object_record_id}/attachments/file`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The object `name__v` field value (`product__v`, `country__v`, `custom_object__c`, etc.). |
| `{object_record_id}` | The object record `id` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/file
```

## Response

Copy to clipboard

```
Content-Type: application/zip;charset=UTF-8
Content-Disposition: attachment;filename="Product CholeCap - attachments.zip"
```

## Response Details

On `SUCCESS`, Vault retrieves the latest version of all attachments from the object record. The attachments are packaged in a ZIP file with the file name: `{object type label} {object record name} - attachments.zip`.

The HTTP Response Header `Content-Type` is set to `application/zip;charset=UTF-8`. The HTTP Response Header `Content-Disposition` contains a filename component which can be used when naming the local file. When downloading attachments with very small file size, the HTTP Response Header `Content-Length` is set to the size of the attachment. Note that for most attachment downloads (larger file sizes), the `Transfer-Encoding` method is set to `chunked` and the `Content-Length` is not displayed.
