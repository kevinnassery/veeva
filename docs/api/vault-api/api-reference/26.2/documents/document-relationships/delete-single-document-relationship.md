<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-relationships/delete-single-document-relationship/ -->
<!-- title: Delete Single Document Relationship -->

# Delete Single Document Relationship

Note

If you need to delete a relationship on more than one document, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/document-relationships/delete-multiple-document-relationships).

Delete a relationship from a document.

You cannot create or delete standard relationship types. Examples of standard relationship types include *Based On* and *Original Source*. Learn about [document relationships in Vault Help](https://platform.veevavault.help/en/gr/21330).

DELETE`/api/{version}/objects/documents/{doc\_id}/versions/{major\_version}/{minor\_version}/relationships/{relationship\_id}`

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
| `{relationship_id}` | The relationship `id` field value. See [Retrieve Document Relationships](/vault-api/api-reference/26.2/documents/document-relationships/retrieve-document-relationships). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/0/relationships/200
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseMessage": "Document relationship successfully deleted.",
    "id": 200
}
```

## Response Details

On `SUCCESS`, Vault returns the relationship ID of the deleted relationship.
