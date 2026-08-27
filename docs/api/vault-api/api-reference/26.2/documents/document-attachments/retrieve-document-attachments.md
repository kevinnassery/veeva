<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-attachments/ -->
<!-- title: Retrieve Document Attachments -->

# Retrieve Document Attachments

GET`/api/{version}/objects/documents/{doc_id}/attachments`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "id": 566,
            "filename__v": "Site Area Map.png",
            "format__v": "image/png",
            "size__v": 109828,
            "md5checksum__v": "78b36d9602530e12051429e62558d581",
            "version__v": 2,
            "created_by__v": 46916,
            "created_date__v": "2015-01-14T00:35:01.775Z",
            "versions": [
                {
                    "version__v": 1,
                    "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/566/versions/1"
                },
                {
                    "version__v": 2,
                    "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/566/versions/2"
                }
            ]
        },
        {
            "id": 567,
            "filename__v": "Site Facilities Contacts.docx",
            "format__v": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "size__v": 11483,
            "md5checksum__v": "bddd2e18f40dd09ab4939ddd2acefeac",
            "version__v": 3,
            "created_by__v": 46916,
            "created_date__v": "2015-01-14T00:35:12.320Z",
            "versions": [
                {
                    "version__v": 1,
                    "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/567/versions/1"
                },
                {
                    "version__v": 2,
                    "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/567/versions/2"
                },
                {
                    "version__v": 3,
                    "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/567/versions/3"
                }
            ]
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response lists the following metadata for each attachment on the requested document:

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
| `versions` | List of links to previous versions of the attachment. Includes the `version__v` and `url` for the [Retrieve Document Attachment Version Metadata](/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-attachment-version-metadata) endpoint to retrieve this attachment version. |
