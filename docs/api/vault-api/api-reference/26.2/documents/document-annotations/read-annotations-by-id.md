<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-id/ -->
<!-- title: Read Annotations by ID -->

# Read Annotations by ID

Retrieve a specific annotation by the annotation ID. You must have *View Content* permission on the document version containing the specified ID.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/annotations/{annotation_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` required | The document `id` field value. |
| `{major_version}` required | The document `major_version_number__v` field value. |
| `{minor_version}` required | The document `minor_version_number__v` field value. |
| `{annotation_id}` required | The annotation ID, which can be retrieved with [Read Annotations by Document Version and Type](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-document-version-and-type). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/301/versions/0/4/annotations/134
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "document_version_id__sys": "301_0_4",
            "modified_by_user__sys": "133999",
            "references": [],
            "id__sys": "134",
            "external_id__sys": "12345",
            "placemark": {
                "type__sys": "sticky__sys",
                "y_coordinate__sys": 25.5,
                "x_coordinate__sys": 50.5,
                "page_number__sys": 1,
                "style__sys": "sticky_icon__sys"
            },
            "created_by_user__sys": "133999",
            "comment__sys": "Remove this.",
            "created_date_time__sys": "2024-09-13T21:57:00.000Z",
            "modified_date_time__sys": "2024-09-13T21:57:00.000Z",
            "persistent_id__sys": "119899_134",
            "title__sys": "",
            "type__sys": "note__sys",
            "state__sys": "open__sys",
            "reply_count__sys": 0,
            "color__sys": "orange_dark__sys"
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response includes all fields and values for the specified annotation. For more details about annotation fields, see [Read Annotations by Document Version and Type](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-document-version-and-type).
