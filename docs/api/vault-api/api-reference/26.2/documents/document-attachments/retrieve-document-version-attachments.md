<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-version-attachments/ -->
<!-- title: Retrieve Document Version Attachments -->

# Retrieve Document Version Attachments

Retrieve attachments on a specific version of a document.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/attachments`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{major_version}` | The document `major_version_number__v` field value. |
| `{minor_version}` | The document `minor_version_number__v` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/attachments
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "id": 39,
            "filename__v": "New",
            "format__v": "application/x-tika-ooxml",
            "size__v": 55762,
            "md5checksum__v": "c5e7eaafc39af8ba42081a213a68f781",
            "version__v": 1,
            "created_by__v": 61603,
            "created_date__v": "2017-10-30T17:03:29.878Z",
            "versions": [
                {
                    "version__v": 1,
                    "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/17/versions/0/1/attachments/39/versions/1"
                }
            ]
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response lists the following metadata for each attachment on the requested document version:

| Metadata Field | Description |
| --- | --- |
| `id` | ID of the attachment. This is set by the system. |
| `external_id__v` | The attachment’s external ID if provided in a [Create Multiple Document Attachments](/vault-api/api-reference/26.2/documents/document-attachments/create-multiple-document-attachments) request. The response excludes this attribute if the attachment has no external ID. |
| `filename__v` | File name of the attachment. |
| `format__v` | File format of the attachment. |
| `description__v` | Optional description added to the attachment. The response excludes this attribute if the attachment has no description. |
| `size__v` | File size of the attachment in bytes. |
| `md5checksum__v` | MD5 checksum value calculated for the attachment. To avoid creating identical versions, Vault assigns each version a checksum value. |
| `version__v` | Version of the attachment. Attachment versioning uses integer numbers beginning with 1 and incrementing sequentially (1, 2, 3,...). There is no concept of major or minor version numbers with attachments. |
| `created_by__v` | The ID of the *User* that created the attachment. |
| `created_date__v` | Date the attachment was created. |
| `versions` | List of links to previous versions of the attachment. Includes the `version__v` and `url` for the [Retrieve Document Version Attachment Version Metadata](/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-version-attachment-version-metadata) endpoint to retrieve this attachment version. |
