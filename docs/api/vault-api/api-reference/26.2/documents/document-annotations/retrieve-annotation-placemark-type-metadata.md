<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/retrieve-annotation-placemark-type-metadata/ -->
<!-- title: Retrieve Annotation Placemark Type Metadata -->

# Retrieve Annotation Placemark Type Metadata

Retrieves the metadata of a specified annotation placemark type. Learn more about [placemark types](/library/references/about-annotations/#Annotation_Placemarks).

GET`/api/{version}/metadata/objects/documents/annotations/placemarks/types/{placemark_type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{placemark_type}` required | The name of the placemark type. For example, `sticky__sys`. Learn more about [placemark types](/library/references/about-annotations/#Annotation_Placemarks). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/annotations/placemarks/types/arrow__sys \
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "name": "arrow__sys",
        "fields": [
            {
                "name": "coordinates__sys",
                "type": "Number list",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "height__sys",
                "type": "Number",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "width__sys",
                "type": "Number",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "x_coordinate__sys",
                "type": "Number",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "y_coordinate__sys",
                "type": "Number",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "page_number__sys",
                "type": "Number",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "style__sys",
                "type": "String",
                "system_managed": false,
                "value_set": [
                    "arrow_down_left__sys",
                    "arrow_down_right__sys",
                    "arrow_left_down__sys",
                    "arrow_left_up__sys",
                    "arrow_right_down__sys",
                    "arrow_right_up__sys",
                    "arrow_up_left__sys",
                    "arrow_up_right__sys"
                ]
            },
            {
                "name": "type__sys",
                "type": "String",
                "system_managed": false,
                "value_set": [
                    "arrow__sys"
                ]
            }
        ]
    }
}
```

## Response Details

On `SUCCESS`, the response includes a list of metadata information for the specified placemark type. Each response may include some or all of the following fields depending on type:

| Field | Description |
| --- | --- |
| `coordinates__sys` | A list of all coordinates for the placemark. |
| `height__sys` | The height of the selection, measured in pixels at 72 DPI. |
| `video_height__sys` | The height of the selection on a video. Measured in pixels from the top-left of the video player at 940 x 573 resolution, inclusive of the letterbox or pillarbox. |
| `width__sys` | The width of the selection, measured in pixels at 72 DPI. |
| `video_width__sys` | The width of the selection on a video. Measured in pixels from the top-left of the video player at 940 x 573 resolution, inclusive of the letterbox or pillarbox. |
| `x_coordinate__sys` | The X coordinate of the position of the top-left of the selection, measured in pixels at 72 DPI. |
| `video_x_coordinate__sys` | The X coordinate of the position of the top-left of the selection on a video. Measured in pixels from top-left of the video player at 940 x 573 resolution, inclusive of the letterbox or pillarbox. |
| `y_coordinate__sys` | The Y coordinate of the position of the top-left of the selection, measured in pixels at 72 DPI. |
| `video_y_coordinate__sys` | The Y coordinate of the position of the top-left of the selection on a video. Measured in pixels from the top-left of the video player at 940 x 573 resolution, inclusive of the letterbox or pillarbox. |
| `page_number__sys` | The document page number where the annotation appears. Page numbers start at 1. |
| `video_time_signature__sys` | The time signature of a video annotation in seconds (`MM:SS` or `HH:MM:SS` format, depending on the video's duration). May be `null` if the annotation is unplaced. |
| `style__sys` | The style of the placemark. For example, `sticky_icon__sys`. |
| `reply_parent__sys` | Reply-type annotations only. The ID of the parent annotation. |
| `reply_position_index__sys` | The position of a reply in a series of replies to a parent annotation. Positions start at 1. |
| `text_start_index__sys` | Annotations placed on text selections only. The index of the first selected word on a page. |
| `text_end_index__sys` | Annotations placed on text selections only. The index of the last selected word on a page. |
