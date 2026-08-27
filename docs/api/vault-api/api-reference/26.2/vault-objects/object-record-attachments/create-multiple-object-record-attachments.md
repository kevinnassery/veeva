<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/create-multiple-object-record-attachments/ -->
<!-- title: Create Multiple Object Record Attachments -->

# Create Multiple Object Record Attachments

You can create object record attachments in bulk with a JSON or CSV input file. You must first load the attachments to [file staging](/vault-api/guides/file-staging). If the attachment already exists in your Vault, Vault uploads it as a new version of the existing attachment. Learn more about [attachment versioning in Vault Help](https://platform.veevavault.help/en/gr/24287#version-specific).

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the [standard format](https://datatracker.ietf.org/doc/html/rfc4180).
* The maximum batch size is 500.

POST`/api/{version}/vobjects/{object_name}/attachments/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

Prepare a CSV or JSON input file.

| Name | Description |
| --- | --- |
| `id` required | The `id` of the object record to which to add the attachment. |
| `filename__v` required | The name for the new attachment. This name must include the file extension, for example, `MyAttachment.pdf`. If an attachment with this name already exists, it is added as a new version. Cannot exceed 218 bytes. |
| `file` required | The filepath of the attachment on file staging. |
| `description__v` optional | Description of the attachment. Maximum 1,000 characters. |
| `external_id__v` optional | The external ID value of the attachment. |

[Download Input File](/sample-files/bulk-create-object-attachments.json)

## Request

Copy to clipboard

```
curl -X POST  -H 'Authorization: {AUTH_VALUE}\
-H 'Accept: text/csv' \
-H 'Content-Type: text/csv' \
--data-raw 'id,filename__v,file
OOU000000000103,CholecapBrochure.docx,u108803/CholecapBrochure.docx
OOU000000000104,DosageInformation.docx,u108803/DosageInformation.docx' \
https://myvault.veevavault.com/api/v26.2/vobjects/veterinary_patient__c/attachments/batch
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": [
       {
           "responseStatus": "SUCCESS",
           "id": 140,
           "version": 1
       },
       {
           "responseStatus": "SUCCESS",
           "id": 141,
           "version": 1
       }
   ]
}
```
