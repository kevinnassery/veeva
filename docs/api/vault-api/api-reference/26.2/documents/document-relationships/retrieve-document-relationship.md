<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-relationships/retrieve-document-relationship/ -->
<!-- title: Retrieve Document Relationship -->

# Retrieve Document Relationship

Retrieve details of a specific document relationship.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/relationships/{relationship_id}`

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
    "responseMessage": null,
    "errorCodes": null,
    "relationships": [
        {
            "relationship": {
                "id": 200,
                "source_doc_id__v": 534,
                "relationship_type__v": "supporting_documents__c",
                "created_by__v": 46916,
                "created_date__v": "2015-03-20T20:44:56.000Z",
                "target_doc_id__v": 548
            }
        }
    ],
    "errorType": null
}
```

## Response Details

| Field Name | Description |
| --- | --- |
| `id` | Relationship ID |
| `source_doc_id__v` | The source document `id` field value. |
| `relationship_type__v` | The relationship type. |
| `target_doc_id__v` | The target document `id` field value. |
| `created_by__v` | The user `id` field value of the person who created the relationship. |
| `created_date__v` | The date and time when the relationship was created. |

Note that when Strict Security Mode is on, if the authenticated user does not have explicit role-based *View* permission to the document (listed in **Sharing Settings**), custom document relationships added at the subtype or classification level are not returned by this API. Without this permission, custom relationships must be added at the document type level to be returned with this API. Learn more about Strict Security Mode in [Vault Help](https://platform.veevavault.help/en/gr/3423).
