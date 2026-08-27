<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/download-document-template-file/ -->
<!-- title: Download Document Template File -->

# Download Document Template File

Download the file of a specific document template.

GET`/api/{version}/objects/documents/templates/{template_name}/file`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` For this request, the `Accept` header controls only the error response. On `SUCCESS`, the response is a file stream (download). |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{template_name}` | The document template `name__v` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/templates/claim_document_template__c/file
```

## Response

Copy to clipboard

```
Content-Type: application/octet-stream;charset=UTF-8
Content-Disposition: attachment;filename="claim_document_template__c.pdf"
```

## Response Details

On `SUCCESS`, Vault retrieves the document template file.

The HTTP Response Header `Content-Type` is set to `application/octet-stream`. The HTTP Response Header `Content-Disposition` contains a filename component which can be used when naming the local file.
When retrieving templates with very small file size, the HTTP Response Header `Content-Length` is set to the size of the template file. Note that for template downloads of larger file sizes, the `Transfer-Encoding` method is set to `chunked` and the `Content-Length` is not displayed.
