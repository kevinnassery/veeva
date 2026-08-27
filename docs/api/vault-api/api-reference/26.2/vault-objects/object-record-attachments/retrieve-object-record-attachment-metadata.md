<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/retrieve-object-record-attachment-metadata/ -->
<!-- title: Retrieve Object Record Attachment Metadata -->

# Retrieve Object Record Attachment Metadata

GET`/api/{version}/vobjects/{object_name}/{object_record_id}/attachments/{attachment_id}`

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
https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/558
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "id": 558,
            "filename__v": "Site Contact List.docx",
            "description__v": "Facilities information and contacts",
            "format__v": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "size__v": 11450,
            "md5checksum__v": "9c6f61847207898ca98431d3e9ad176d",
            "version__v": 3,
            "created_by__v": 46916,
            "created_date__v": "2015-01-07T21:42:47.772Z",
            "versions": [
                {
                    "version__v": 1,
                    "url": "https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/558/versions/1"
                },
                {
                    "version__v": 2,
                    "url": "https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/558/versions/2"
                },
                {
                    "version__v": 3,
                    "url": "https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/558/versions/3"
                }
            ]
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response lists the following metadata for the requested attachment:

| Metadata Field | Description |
| --- | --- |
| `id` | ID of the attachment. This is set by the system. |
| `external_id__v` | The attachment’s external ID if provided in a [Create Multiple Object Record Attachments](/vault-api/api-reference/26.2/vault-objects/object-record-attachments/create-multiple-object-record-attachments) request. The response excludes this attribute if the attachment has no external ID. |
| `filename__v` | File name of the attachment. |
| `format__v` | File format of the attachment. |
| `description__v` | Optional description added to the attachment. The response excludes this attribute if the attachment has no description. |
| `size__v` | File size of the attachment in bytes. |
| `md5checksum__v` | MD5 checksum value calculated for the attachment. To avoid creating identical versions, Vault assigns each version a checksum value. |
| `version__v` | Version of the attachment. Attachment versioning uses integer numbers beginning with 1 and incrementing sequentially (1, 2, 3,...). There is no concept of major or minor version numbers with attachments. |
| `created_by__v` | The ID of the *User* that created the attachment. |
| `created_date__v` | Date the attachment was created. |
| `versions` | List of links to previous versions of the attachment. Includes the `version__v` and `url` for the [Retrieve Object Record Attachment Version Metadata](/vault-api/api-reference/26.2/vault-objects/object-record-attachments/retrieve-object-record-attachment-version-metadata) endpoint to retrieve this attachment version. |
