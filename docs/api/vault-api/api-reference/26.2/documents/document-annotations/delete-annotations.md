<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/delete-annotations/ -->
<!-- title: Delete Annotations -->

# Delete Annotations

Delete multiple annotations. The authenticated user must have the appropriate permissions to delete annotations. Learn more about permissions required to [delete annotations](https://platform.veevavault.help/en/gr/9777/#deleting-annotations) and [delete brought forward annotations](https://platform.veevavault.help/en/gr/18648/#permissions) in Vault Help.

DELETE`/api/{version}/objects/documents/annotations/batch`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/json` |
| `Accept` | `application/json` (default), `text/csv`, or `application/xml` |

## Body Parameters

Note

Some HTTP clients do not support `DELETE` requests with a
body. As a workaround for these cases, you can simulate this request using the
`POST` method and using the `_method=DELETE` query parameter.

Upload parameters as a JSON or CSV file. You can delete up to 500 annotations per batch.

| Name | Description |
| --- | --- |
| `id__sys` required | The ID of the annotation to delete. |
| `document_version_id__sys` required | The ID and version number of the document where the annotation appears in the format `{documentId}_{majorVersion}_{minorVersion}`. For example, `138_2_1`. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
--data-binary @"C:\Vault\Documents\delete_annotations.csv" \
https://myvault.veevavault.com/api/v26.2/objects/documents/annotations/batch
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": [
       {
           "responseStatus": "SUCCESS",
           "document_version_id__sys": "1_0_1",
           "id__sys": "58",
           "global_version_id__sys": "119899_1_1"
       }
   ]
}
```
