<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/delete-multiple-object-record-attachments/ -->
<!-- title: Delete Multiple Object Record Attachments -->

# Delete Multiple Object Record Attachments

Delete object record attachments in bulk with a JSON or CSV input file. You can only delete the latest version of an attachment.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the [standard format](https://datatracker.ietf.org/doc/html/rfc4180).
* The maximum batch size is 500.

DELETE`/api/{version}/vobjects/{object_name}/attachments/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

Note

Some HTTP clients do not support `DELETE` requests with a
body. As a workaround for these cases, you can simulate this request using the
`POST` method with the `_method=DELETE` query parameter.

Prepare a CSV or JSON input file.

| Name | Description |
| --- | --- |
| `id` conditional | The `id` of the object record to which to add the attachment. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `external_id__v` conditional | Identify attachments by their external `id`. You must also add the `idParam=external_id__v` query parameter. |
| `attachment_id` required | The `id` of the attachment being updated. |

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you’re identifying attachments in your input by external id, add `idParam=external_id__v` to the request endpoint. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H 'Accept: application/json' \
-H 'Content-Type: application/json' \
-d '[
{
"id": "V15000000000305",
"attachment_id": "141"
}
]'
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
           "id": 141
       }
   ]
}
```
