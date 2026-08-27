<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-attachments/retrieve-document-attachment-version-metadata/ -->
<!-- title: Retrieve Document Attachment Version Metadata -->

# Retrieve Document Attachment Version Metadata

GET`/api/{version}/objects/documents/{doc_id}/attachments/{attachment_id}/versions/{attachment_version}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{attachment_id}` | The attachment `id` field value. |
| `{attachment_version}` | The attachment `version__v` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/565/attachments/566/versions/2
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
            "created_date__v": "2015-01-14T00:35:01.775Z"
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response lists the following metadata for the requested attachment version:

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
