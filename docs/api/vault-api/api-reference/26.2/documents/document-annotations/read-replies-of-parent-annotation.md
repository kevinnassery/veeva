<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/read-replies-of-parent-annotation/ -->
<!-- title: Read Replies of Parent Annotation -->

# Read Replies of Parent Annotation

Given a parent annotation ID, retrieves all replies to the annotation. You must have *View Content* permission on the document version containing the specified parent annotation ID.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/annotations/{annotation_id}/replies`

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
| `{annotation_id}` required | The parent annotation ID, which can be retrieved with [Read Annotations by Document Version and Type](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-document-version-and-type). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/102/versions/0/2/annotations/40/replies
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "document_version_id__sys": "102_0_2",
            "modified_by_user__sys": "133999",
            "type__sys": "reply__sys",
            "id__sys": "41",
            "tag_names__sys": [
                "IMG"
            ],
            "state__sys": "open__sys",
            "placemark": {
                "reply_position_index__sys": 1,
                "type__sys": "reply__sys",
                "reply_parent__sys": "40"
            },
            "created_by_user__sys": "133999",
            "comment__sys": "I think this image is fine.",
            "created_date_time__sys": "2024-02-07T00:37:36.000Z",
            "modified_date_time__sys": "2024-02-07T00:37:36.000Z",
            "color__sys": "red_dark__sys"
        }
    ],
    "responseDetails": {
        "offset": 0,
        "limit": 500,
        "size": 1,
        "total": 1
    }
}
```

## Response Details

On `SUCCESS`, the response lists all fields and values for all replies to the specified annotation. For more details about annotation fields, see [Read Annotations by Document Version and Type](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-document-version-and-type).
