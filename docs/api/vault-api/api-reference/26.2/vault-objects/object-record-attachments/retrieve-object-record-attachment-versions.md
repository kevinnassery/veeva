<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-record-attachments/retrieve-object-record-attachment-versions/ -->
<!-- title: Retrieve Object Record Attachment Versions -->

# Retrieve Object Record Attachment Versions

GET`/api/{version}/vobjects/{object_name}/{object_record_id}/attachments/{attachment_id}/versions`

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
https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/571/versions
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "version__v": 1,
            "url": "https://myvault.veevavault.com/api/v26.2/vobjects/site__v/1357752909483/attachments/571/versions/1"
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response lists the following metadata for each version of the requested attachment:

| Metadata Field | Description |
| --- | --- |
| `version__v` | Version of the attachment. Attachment versioning uses integer numbers beginning with 1 and incrementing sequentially (1, 2, 3,...). There is no concept of major or minor version numbers with attachments. |
| `url` | Link to the [Retrieve Object Record Attachment Version Metadata](/vault-api/api-reference/26.2/vault-objects/object-record-attachments/retrieve-object-record-attachment-version-metadata) endpoint to retrieve this attachment version. |
