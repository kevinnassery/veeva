<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-document-version-and-type/ -->
<!-- title: Read Annotations by Document Version and Type -->

# Read Annotations by Document Version and Type

Retrieve annotations from a specific document version. You can retrieve all annotations or choose to retrieve only certain annotation types.

You must have *View Content* permission on the specified document version.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/annotations`

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

## Query Parameters

| Name | Description |
| --- | --- |
| `offset` optional | This parameter is used to paginate the results. It specifies the amount of offset from the first record returned. Vault returns 200 records per page by default. If you are viewing the first 200 results (page 1) and want to see the next page, set this to `offset=201`. |
| `limit` optional | Paginate the results by specifying the maximum number of records per page in the response. This can be any value between `1` and `500`. If omitted, defaults to `500`. Values greater than `500` are ignored. |
| `pagination_id` optional | A unique identifier used to load requests with paginated results. For example, `b688a6f4-d0c4-4f72-9eb4-ceba01136466`. |
| `annotation_types` optional | The type(s) of annotations to retrieve. For example, `note__sys,anchor__sys`. If omitted, Vault returns all annotation types except replies. Valid annotation types include:  * `note__sys` * `line__sys` * `document_link__sys` * `permalink_link__sys` * `anchor__sys` * `reply__sys` * `external_link__sys`  The following annotation types are only valid in Medical and PromoMats Vaults:  * `suggested_link__sys` * `approved_link__sys` * `auto_link__sys` * `keyword_link__sys` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/502/versions/0/1/annotations?annotation_types=document_link__sys,note__sys
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "document_version_id__sys": "502_0_1",
            "modified_by_user__sys": "133999",
            "references": [],
            "id__sys": "129",
            "placemark": {
                "y_coordinate__sys": 627.82,
                "coordinates__sys": [
                    72.024,
                    627.82,
                    108.489,
                    627.82,
                    72.024,
                    616.78,
                    108.489,
                    616.78
                ],
                "text_start_index__sys": 5,
                "text_end_index__sys": 5,
                "type__sys": "text__sys",
                "height__sys": 11.04,
                "width__sys": 36.465,
                "x_coordinate__sys": 72.024,
                "page_number__sys": 1,
                "style__sys": "text_highlight__sys"
            },
            "created_by_user__sys": "133999",
            "comment__sys": "Fix kerning",
            "created_date_time__sys": "2024-09-12T23:37:55.000Z",
            "modified_date_time__sys": "2024-09-12T23:37:55.000Z",
            "persistent_id__sys": "119899_129",
            "title__sys": "Patients",
            "type__sys": "note__sys",
            "tag_names__sys": [
                "Typography"
            ],
            "state__sys": "open__sys",
            "reply_count__sys": 0,
            "color__sys": "yellow_light__sys"
        },
        {
            "document_version_id__sys": "502_0_1",
            "modified_by_user__sys": "133999",
            "references": [
                {
                    "document_version_id__sys": "301_0_3",
                    "type__sys": "document__sys",
                    "annotation__sys": "56"
                }
            ],
            "id__sys": "143",
            "external_id__sys": "12345",
            "placemark": {
                "y_coordinate__sys": 717.82,
                "coordinates__sys": [
                    124.188,
                    717.82,
                    177.622,
                    717.82,
                    124.188,
                    706.78,
                    177.622,
                    706.78,
                    72.024,
                    695.38,
                    101.479,
                    695.38,
                    72.024,
                    684.34,
                    101.479,
                    684.34,
                    72.024,
                    672.82,
                    111.348,
                    672.82,
                    72.024,
                    661.78,
                    111.348,
                    661.78,
                    72.024,
                    650.38,
                    120.975,
                    650.38,
                    72.024,
                    639.34,
                    120.975,
                    639.34,
                    72.024,
                    627.82,
                    108.489,
                    627.82,
                    72.024,
                    616.78,
                    108.489,
                    616.78
                ],
                "text_start_index__sys": 1,
                "text_end_index__sys": 5,
                "type__sys": "text__sys",
                "height__sys": 101.04,
                "width__sys": 105.598,
                "x_coordinate__sys": 72.024,
                "page_number__sys": 1,
                "style__sys": "text_link__sys"
            },
            "created_by_user__sys": "133999",
            "comment__sys": "",
            "created_date_time__sys": "2024-09-13T23:04:25.000Z",
            "modified_date_time__sys": "2024-09-13T23:04:25.000Z",
            "persistent_id__sys": "119899_143",
            "title__sys": "Information Insulin Diabetes Indications Patients",
            "type__sys": "document_link__sys",
            "state__sys": "open__sys",
            "color__sys": "blue_dark__sys"
        }
    ],
    "responseDetails": {
        "offset": 0,
        "limit": 500,
        "size": 2,
        "total": 2
    }
}
```

## Response Details

On `SUCCESS`, the response includes a list of annotations of the specified type(s) for the document version. Each Annotation object may include some or all of the following fields depending on type:

| Annotation Field | Description |
| --- | --- |
| `document_version_id__sys` | The ID and version number of the document where the annotation appears in the format `{documentId}_{majorVersion}_{minorVersion}`. For example, `138_2_1`. |
| `modified_by_user__sys` | The ID of the user who last modified the annotation. If no last modified information exists, this defaults to the value of `created_by_user__sys`. |
| `id__sys` | The annotation ID. |
| `placemark` | A list of fields whose values define where on a document an annotation appears. See [below](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-id) for details. |
| `references` | A list of annotation references. See [below](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-id) for details. |
| `created_by_user__sys` | The ID of the user who created the annotation. |
| `created_by_delegate_user__sys` | The ID of the delegate user who created the annotation, if applicable. |
| `comment__sys` | The annotation comment text. Allows up to 32,000 characters. Not all annotation types allow comments. |
| `created_date_time__sys` | The date and time when the annotation was created. |
| `modified_date_time__sys` | The date and time when the annotation was last modified. If no last modified information exists, this defaults to the value of `created_date_time__sys`. |
| `persistent_id__sys` | The persistent ID. This ID remains the same across all document versions when brought forward. Some older annotations may not have a persistent ID. You can generate one by updating or bringing forward the annotation. |
| `external_id__sys` | The external ID. This field is optional and can be any non-empty string with a maximum of 250 characters. If no value is set, the field is excluded from the response. |
| `linked_object__sys` | The name of the primary linked object for the annotation. Not all annotation types support linked objects. |
| `linked_records__sys` | The ID(s) of the object record or records the annotation is linked to. Not all annotation types support linked records. |
| `title__sys` | The title of the annotation. Allows up to 1,500 characters. For annotations with text placemarks, this must be set to the selected text. |
| `type__sys` | The name of the annotation type. For example, `note__sys`. |
| `state__sys` | The name of the state of the annotation, either `open__sys` or `resolved__sys`. Not all annotation types support states. |
| `reply_count__sys` | For annotation types that support replies, the number of replies to this annotation. |
| `color__sys` | The name of the annotation color. Some annotation types allow users to select from a variety of colors, while others are always the same color. |
| `tag_names__sys` | A list of the names of each tag associated with each annotation. Not all annotation types support tags. |
| `anchor_name__sys` | Anchor annotations only: The name of the anchor. Allows up to 140 characters. |
| `match_text_variation__sys` | PromoMats Vaults with Suggested Links enabled only: The ID of the `matched_text_variation__sys` object record linked to the `annotation_keywords__sys` record associated with the annotation. |
| `offset` | The `offset` value specified in the request. |
| `limit` | The `limit` value specified in the request. |
| `size` | The number of records displayed on the current page. |
| `total` | The total number of annotations found. |
| `next_page` | The pagination URL to navigate to the next page of results. Only included if the number of results exceeds the number defined by a request’s limit. |
| `previous_page` | The pagination URL to navigate to the previous page of results. Only included if the request included an offset, or after navigating to the next\_page URL. |

#### Placemarks

A placemark defines where on a document or video an annotation appears. For example, a text selection, a page number, or the coordinates of an area selection.

Placemark coordinates on non-video documents are listed in the style of PDF quad points and are measured in pixels from the bottom-left of the page at 72 DPI. There will be 8\*n coordinates, where n is the number of rectangles that make up the placemark.
Annotation placemarks include the following fields:

| Placemark Field | Description |
| --- | --- |
| `coordinates__sys` | A list of all coordinates for the placemark. Text placemarks must set the `title__sys` field to the selected text in addition to specifying coordinates. |
| `y_coordinate__sys` | The Y coordinate of the position of the top-left of the selection, measured in pixels at 72 DPI. |
| `video_y_coordinate__sys` | The Y coordinate of the position of the top-left of the selection on a video. Measured in pixels from the top-left of the video player at 940 x 573 resolution, inclusive of the letterbox or pillarbox. |
| `x_coordinate__sys` | The X coordinate of the position of the top-left of the selection, measured in pixels at 72 DPI. |
| `video_x_coordinate__sys` | The X coordinate of the position of the top-left of the selection on a video. Measured in pixels from top-left of the video player at 940 x 573 resolution, inclusive of the letterbox or pillarbox. |
| `text_start_index__sys` | Annotations placed on text selections only. The index of the first selected word on a page. |
| `text_end_index__sys` | Annotations placed on text selections only. The index of the last selected word on a page. |
| `type__sys` | The placemark type. For example, `text__sys`. |
| `height__sys` | The height of the selection, measured in pixels at 72 DPI. |
| `video_height__sys` | The height of the selection on a video. Measured in pixels from the top-left of the video player at 940 x 573 resolution, inclusive of the letterbox or pillarbox. |
| `width__sys` | The width of the selection, measured in pixels at 72 DPI. |
| `video_width__sys` | The width of the selection on a video. Measured in pixels from the top-left of the video player at 940 x 573 resolution, inclusive of the letterbox or pillarbox. |
| `page_number__sys` | The document page number where the annotation appears. Page numbers start at 1. |
| `video_time_signature__sys` | The time signature of a video annotation in seconds (`MM:SS` or `HH:MM:SS` format, depending on the video's duration). May be `null` if the annotation is unplaced. |
| `style__sys` | The style of the placemark. For example, `sticky_icon__sys`. |
| `reply_parent__sys` | Reply-type annotations only. The ID of the parent annotation. |
| `reply_position_index__sys` | The position of a reply in a series of replies to a parent annotation. Positions start at 1. |

#### References

A reference is a way for an annotation to refer to an external entity. This can be a document, an anchor annotation on a document, an external URL, or a permalink.

Annotation references include the following fields:

| Reference Field | Description |
| --- | --- |
| `document_version_id__sys` | Document-type references only. The ID and version number of the referenced document in the format `{documentId}_{majorVersion}_{minorVersion}`. For example, `138_2_1.` |
| `permalink__sys` | Permalink-type references only. The ID of the referenced permalink. |
| `url__sys` | External-type references only. The URL of the external reference. Allows up to 32,000 characters. |
| `type__sys` | The reference type:`document__sys`, `external__sys`, or `permalink__sys`. |
| `annotation__sys` | Document-type references only. The ID of the referenced anchor annotation, or null for references to an entire document. |
