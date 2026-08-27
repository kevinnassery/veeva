<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/file-staging/download-item-content/ -->
<!-- title: Download Item Content -->

# Download Item Content

Retrieve the content of a specified file from file staging. Use the `Range` header to create resumable downloads for large files, or to continue downloading a file if your session is interrupted.

GET`/api/{version}/services/file_staging/items/content/{item}`

## Headers

| Name | Description |
| --- | --- |
| `Range` | Optional: Specifies a partial range of bytes to include in the download. Maximum 50 MB. Must be in the format `bytes={min}-{max}`. For example, `bytes=0-1000`. |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `item` | The absolute path to a file. This path is specific to the authenticated user. Admin users can access the root directory. All other users can only access their own user directory. |

## Request

Copy to clipboard

```
curl -L -X GET -H "Authorization: {AUTH_VALUE}" \
-H "Range: bytes=0-1000" \
https://myvault.veevavault.com/api/v26.2/services/file_staging/items/content/u10001400/Wonder Drug Survey.docx
```

## Response

Copy to clipboard

```
Content-Type: application/octet-stream;charset=UTF-8
Content-Disposition: attachment;filename="Wonder Drug Survey.docx"
Content-Range: bytes 0-1000/11737
```

## Response Details

On `SUCCESS`, Vault retrieves the content of the specified file. The HTTP Response Header `Content-Type` is set to `application/octet-stream` and the HTTP Response Header `Content-Disposition` contains a filename component which can be used when naming the local file. If a `range` header was specified in the request, the response also includes the `Content-Range` HTTP Response Header, which specifies the bytes downloaded, as well as the total for the file. In the example above, the `Content-Range` specifies a download of bytes 1-1000 of 11737 total bytes.
