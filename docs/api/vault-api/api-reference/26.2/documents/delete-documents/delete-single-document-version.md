<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/delete-documents/delete-single-document-version/ -->
<!-- title: Delete Single Document Version -->

# Delete Single Document Version

Note

If you need to delete more than one document version, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/delete-documents/delete-multiple-document-versions).

Delete a specific version of a document, including the version's source file and viewable rendition. Other versions of the document remain unchanged. See also [Delete Single Document](/vault-api/api-reference/26.2/documents/delete-documents/delete-single-document).

DELETE`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `text/csv` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{major_version}` | The document `major_version_number__v` field value. |
| `{minor_version}` | The document `minor_version_number__v` field value. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/0/2
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "id": 534
}
```
