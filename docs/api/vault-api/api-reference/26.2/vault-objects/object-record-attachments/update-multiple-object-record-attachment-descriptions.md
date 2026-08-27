<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/update-multiple-object-record-attachment-descriptions/ -->
<!-- title: Update Multiple Object Record Attachment Descriptions -->

# Update Multiple Object Record Attachment Descriptions

Update object record attachments in bulk with a JSON or CSV input file. You can only update the latest version of an attachment.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the [standard format](https://datatracker.ietf.org/doc/html/rfc4180).
* The maximum batch size is 500.

PUT`/api/{version}/vobjects/{object_name}/attachments/batch`

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
| `attachment_id` required | The `id` of the attachment you are updating on the record. |
| `external_id__v` optional | Identify attachments by their external `id`. You must also add the `idParam=external_id__v` query parameter. |
| `description__v` required | Description of the attachment. 1000 characters maximum. |

[Download Input File](/sample-files/bulk-update-object-attachments.json)

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you’re identifying attachments in your input by external id, add `idParam=external_id__v` to the request endpoint. |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H 'Accept: text/csv' \
-H 'Content-Type: text/csv' \
--data-raw 'id,attachment_id,description__v
OOU000000000103,140,"Cholecap Brochure Fall 2019."
OOU000000000104,141,"Cholecap Brochure Spring 2020."' \
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
