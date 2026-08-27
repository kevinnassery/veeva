<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-relationships/retrieve-document-relationships/ -->
<!-- title: Retrieve Document Relationships -->

# Retrieve Document Relationships

Retrieve all relationships from a document.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/relationships`

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
https://myvault.veevavault.com/api/v26.2/objects/documents/866/versions/1/1/relationships
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
        "source_doc_id__v": 886,
        "relationship_type__v": "related_pieces__c",
        "created_date__v": "2015-12-15T21:42:01.000Z",
        "id": 214,
        "target_doc_id__v": 890,
        "created_by__v": 46916
      }
    },
    {
      "relationship": {
        "source_doc_id__v": 886,
        "relationship_type__v": "related_pieces__c",
        "created_date__v": "2015-12-15T22:06:28.000Z",
        "id": 216,
        "target_doc_id__v": 884,
        "created_by__v": 46916
      }
    },
    {
      "relationship": {
        "source_doc_id__v": 886,
        "relationship_type__v": "supporting_documents__c",
        "created_date__v": "2015-12-15T21:41:10.000Z",
        "id": 213,
        "target_doc_id__v": 885,
        "created_by__v": 46916
      }
    },
    {
      "relationship": {
        "source_doc_id__v": 886,
        "relationship_type__v": "supporting_documents__c",
        "created_date__v": "2015-12-15T22:06:21.000Z",
        "id": 215,
        "target_doc_id__v": 889,
        "created_by__v": 46916
      }
    }
  ],
  "errorType": null
}
```

## Response Details

On `SUCCESS`, Vault returns a list of all relationships configured on the document. In this example, document ID 886 v1.1 has reference relationships with four other documents in our Vault. This is the source document. Two of the referenced documents - `target_doc_id__v` 890 and 884 have the `related_pieces__c` relationship type. The other two referenced documents - `target_doc_id__v` 885 and 887 have the `supporting_documents__c` relationship type.

Note that when Strict Security Mode is on, if the authenticated user does not have explicit role-based *View* permission to the document (listed in **Sharing Settings**), custom document relationships added at the subtype or classification level are not returned by this API. Without this permission, custom relationships must be added at the document type level to be returned with this API. Learn more about Strict Security Mode in [Vault Help](https://platform.veevavault.help/en/gr/3423).
