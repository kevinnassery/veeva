<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/retrieve-attachment-field-files-export-results/ -->
<!-- title: Retrieve Attachment Field Files Export Results -->

# Retrieve Attachment Field Files Export Results

Retrieve the results of the job requested by the [Export Attachment Field Files](/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/export-attachment-field-files) endpoint.

GET`/api/{version}/vobjects/{object_name}/attachment_fields/actions/export/{job_id}/results`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The `name` of the object. |
| `{job_id}` | The job ID included in the [Export Attachment Field Files](/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/export-attachment-field-files) response. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/attachment_fields/actions/export/1069501/results
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "name": "2419535-1069501-product__v",
        "filename": "2419535-1069501-product__v.tar.gz",
        "size": 36598,
        "fileparts": 1,
        "filepart_details": [
            {
                "name": "2419535-1069501-product__v.001",
                "filename": "2419535-1069501-product__v.tar.gz.001",
                "filepart": 1,
                "size": 36598,
                "url": "/api/v26.2/vobjects/product__v/attachment_fields/files/2419535-1069501-product__v.001"
            }
        ]
    }
}
```

## Response Details

On `SUCCESS`, the response includes the following metadata:

| Name | Description |
| --- | --- |
| `name` | The name of the *Attachment* fields export file, excluding the extension. The name has the following format: `{user_id}-{job_id}-{object_name}`, where `user_id` is the ID of the user that requested the export. For example, `2419535-1069501-product__v`. |
| `filename` | The name of the export file, with the following format: `{user_id}-{job_id}-{object_name}.tar.gz`, where `user_id` is the ID of the user that requested the export. For example, `2419535-1069501-product__v.tar.gz`. |
| `size` | The size of the export file in bytes. |
| `fileparts` | The number of file parts for the export file. Vault splits files greater than 1 GB into multiple file parts. If the export file is less than 1 GB, Vault creates one file part. |
| `filepart_details` | A list of all file parts and their metadata, including the `name`. Use the `name` field to download the file part with the [Download Attachment Field Files Export](/vault-api/api-reference/26.2/vault-objects/object-attachment-fields/download-attachment-field-files-export) endpoint. |
