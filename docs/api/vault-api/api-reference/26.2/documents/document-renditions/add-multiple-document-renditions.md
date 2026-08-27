<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/add-multiple-document-renditions/ -->
<!-- title: Add Multiple Document Renditions -->

# Add Multiple Document Renditions

Add document renditions in bulk. You must first load the renditions to [file staging](/vault-api/guides/file-staging).

* If the `largeSizeAsset` query parameter is not set to `true`, you must include the `X-VaultAPI-MigrationMode` header.
* The maximum CSV input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

POST`/api/{version}/objects/documents/renditions/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` |
| `Accept` | `application/json` (default) or `text/csv` |
| `X-VaultAPI-MigrationMode` | Must be set to `true` when importing any rendition type other than `large_size_asset__v`. Vault does not send notifications in Document Migration Mode. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |

## Body Parameters

| Name | Description |
| --- | --- |
| `file` required | The filepath of the rendition on file staging. |
| `id` conditional | The system-assigned document ID of the document to add renditions to. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `external_id__v` conditional | Instead of `id`, you can use this user-defined document external ID. |
| `rendition_type__v` required | Document rendition type to assign to the new rendition. Only one rendition of each type may exist on each document. |
| `major_version_number__v` required | Major version number to assign to the new document rendition. |
| `minor_version_number__v` required | Minor version number to assign to the new document rendition. |

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you're identifying documents in your input by a unique field, add `idParam={fieldname}` to the request endpoint. You can use any object field which has `unique` set to `true` in the object metadata, with the exception of picklists. For example, `idParam=external_id__v`. |
| `largeSizeAsset` | If set to `true`, indicates that the renditions to add are of the Large Size Asset (`large_size_asset__v`) rendition type. Vault applies [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) limitations to renditions created with the request, but *Document Migration* permission is not required and your Vault need not be in Migration Mode to use the parameter. Note that the request results in an error if the CSV contains any rendition type other than `large_size_asset__v`. |

[Download Input File](/sample-files/vault-add-document-renditions-sample-csv-input.csv)

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-binary @"filename" \
https://myvault.veevavault.com/api/v26.2/objects/documents/renditions/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 771,
            "external_id__v": "ALT-DOC-0771",
            "major_version_number__v": 0,
            "minor_version_number__v": 2,
            "rendition_type__c": "imported_rendition__c"
        },
        {
            "responseStatus": "SUCCESS",
            "id": 772,
            "external_id__v": "CHO-DOC-0772",
            "major_version_number__v": 0,
            "minor_version_number__v": 2,
            "rendition_type__c": "imported_rendition__c"
        },
        {
            "responseStatus": "SUCCESS",
            "id": 773,
            "external_id__v": "GLU-DOC-0773",
            "major_version_number__v": 1,
            "minor_version_number__v": 0,
            "rendition_type__c": "imported_rendition__c"
        },
        {
            "responseStatus": "FAILURE",
            "errors": [
                {
                    "type": "INVALID_DATA",
                    "message": "Error message describing why this document rendition was not added."
                }
            ]
        }
    ]
}
```
