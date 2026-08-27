<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/create-multiple-annotations/ -->
<!-- title: Create Multiple Annotations -->

# Create Multiple Annotations

Create up to 500 annotations. This endpoint does not support creating line (`line__sys`) nor reply (`reply__sys`) annotations. To create reply (`reply__sys`) annotations, use [Add Annotation Replies](/vault-api/api-reference/26.2/documents/document-annotations/add-annotation-replies).

POST`/api/{version}/objects/documents/annotations/batch`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `text/csv` |
| `Content-Type` | `application/json` |

## Body Parameters

Prepare a JSON-formatted list of annotation objects, each containing a list of annotation properties and their values. To retrieve more details about annotation fields, use [Retrieve Annotation Type Metadata](/vault-api/api-reference/26.2/documents/document-annotations/retrieve-annotation-type-metadata) or see the required and optional fields for each annotation type below this table. When setting annotation properties, exclude any that are system-managed (`system_managed=true`).

The following fields are required or optional for each annotation object and for all annotation types:

| Field | Description |
| --- | --- |
| `type__sys` required | The name of the annotation type. Some annotation types may not be available depending on your Vault's configuration. Valid document annotation types include:    * `note__sys` * `document_link__sys` * `permalink_link__sys` * `external_link__sys` * `anchor__sys`   The following annotation types are valid for video documents:    * `note__sys` * `document_link__sys` * `keyword_link__sys` |
| `document_version_id__sys` required | The ID and version number of the document to create the annotation for, in the format `{documentId}_{majorVersion}_{minorVersion}`. For example, `138_2_1`. |
| `placemark` required | A JSON array with the field information for a specified placemark type, indicating where and how an annotation appears on a document. Use [Retrieve Annotation Type Metadata](/vault-api/api-reference/26.2/documents/document-annotations/retrieve-annotation-type-metadata) to retrieve a full list of `allowed_placemark_types` based on the annotation type. Then, use [Retrieve Annotation Placemark Type Metadata](/vault-api/api-reference/26.2/documents/document-annotations/retrieve-annotation-placemark-type-metadata) to retrieve metadata for a specified annotation placemark type. Learn more about [annotation placemark metadata](/library/references/about-annotations/#Annotation_Placemarks). |
| `external_id__sys` optional | The external ID. Maximum of 250 characters. |
| `persistent_id__sys` optional | The persistent ID. This ID remains the same across all document versions when brought forward. |
| `comment__sys` optional | The annotation comment text. Allows up to 32,000 characters. Anchor (`anchor__sys`) annotations do not support adding comments. |
| `prevent_bring_forward__sys` optional | Boolean value indicating whether or not users can bring forward annotations from previous document versions to the latest version of the document. If omitted, defaults to `false`, meaning users cannot bring forward this annotation. |
| `state__sys` optional | The name of the state of the annotation, either `open__sys` or `resolved__sys` (only valid for note annotations). If omitted, defaults to `open__sys`. |

## Note Annotations

In addition to the fields required for all annotation types, the following fields are optional for each note (`note__sys`) annotation object:

| Field | Description |
| --- | --- |
| `color__sys` optional | The name of the annotation color. If omitted, defaults to the assigned note color of the user's document lifecycle role. Learn more about [note colors in Vault Help](https://platform.veevavault.help/en/gr/2662/#color). If there is no assigned note color, defaults to `yellow_light__sys`.  Accepts the following values:    * `yellow_light__sys` * `green_dark__sys` * `green_light__sys` * `orange_dark__sys` * `orange_light__sys` * `pink_dark__sys` * `pink_light__sys` * `purple_dark__sys` * `purple_light__sys` * `red_dark__sys` * `red_light__sys` * `yellow_dark__sys` |
| `title__sys` optional | The title of the annotation. Maximum 1,500 characters. |

## Link Annotations

Link annotations include document links (`document_link__sys`) and permalinks (`permalink_link__sys`).

In addition to the fields required for all annotation types, the following fields are required or optional for each document link or permalink annotation object:

| Field | Description |
| --- | --- |
| `references` required | A JSON array of annotation references referring to an external entity. Learn more about [annotation references](/library/references/about-annotations/#Annotation_References) and [annotation reference metadata](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-id). |
| `color__sys` optional | The name of the annotation color. Link annotations only accept the value `blue_dark__sys`. If omitted, defaults to `blue_dark__sys`. |
| `title__sys` optional | The title of the annotation. Maximum 1,500 characters. |

Link annotations always have a color of `blue_dark__sys`, which cannot be changed.

## External Link Annotations

In addition to the fields required for all annotation types, the following field is optional for each external link (`external_link__sys`) annotation object:

| Field | Description |
| --- | --- |
| `color__sys` optional | The name of the annotation color. External link annotations only accept the value `blue_dark__sys`. If omitted, defaults to `blue_dark__sys`. |

External link annotations always have a color of `blue_dark__sys`, which cannot be changed.

## Anchor Annotations

In addition to the fields required for all annotation types, the following fields are required or optional for each anchor (`anchor__sys`) annotation object:

| Field | Description |
| --- | --- |
| `anchor_name__sys` required | The name of the anchor. Maximum 140 characters. |
| `color__sys` optional | The name of the annotation color. Anchor annotations only accept the value `gray_light__sys`. If omitted, defaults to `gray_light__sys`. |

Anchor annotations always have a color of `gray_light__sys`, which cannot be changed.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H 'Content-Type: application/json' \
-H 'Accept: application/json' \
-d '[
    {
        "document_version_id__sys": "12_1_0",        
        "placemark": {
            "text_start_index__sys": 11,
            "text_end_index__sys": 14,
            "type__sys": "text__sys",
            "page_number__sys": 1,
            "style__sys": "text_insert__sys"
        },
        "comment__sys": "Insert before this text",        
        "type__sys": "note__sys",
        "state__sys": "open__sys",
        "color__sys": "orange_dark__sys"
    },
    {
       "type__sys": "note__sys",
       "document_version_id__sys": "1001_0_1",
       "external_id__sys": "12345",
       "color__sys": "orange_dark__sys",
       "comment__sys": "hello world",
       "placemark": {
           "type__sys": "sticky__sys",
           "page_number__sys": 1,
           "x_coordinate__sys": 50.5,
           "y_coordinate__sys": 25.5
       }
    },
    {
        "document_version_id__sys": "12_1_0",
        "references": [
            {
                "type__sys": "external__sys",
                "url__sys": "https://www.veeva.com"
            }
        ],
        "placemark": {
            "text_start_index__sys": 17,
            "text_end_index__sys": 18,
            "type__sys": "text__sys",            
            "page_number__sys": 1,
            "style__sys": "text_link__sys"
        },
        "comment__sys": "Link to company website.",
        "type__sys": "external_link__sys",
        "state__sys": "open__sys",
        "color__sys": "blue_dark__sys"
    },
    {
        "type__sys": "anchor__sys",
        "document_version_id__sys": "12_1_0",
        "anchor_name__sys": "The logo",
        "placemark": {
                "type__sys": "rectangle__sys",
                "height__sys": 21.55,
                "width__sys": 157.74,
                "x_coordinate__sys": 82.75,
                "y_coordinate__sys": 744.59,
                "page_number__sys": 1,
                "style__sys": "rectangle_solid__sys"
        }
    },
    {
      "type__sys": "document_link__sys",
      "document_version_id__sys": "12_1_0",
      "placemark": {
        "type__sys": "text__sys",
        "page_number__sys": 1,
        "text_start_index__sys": 10,
        "text_end_index__sys": 15
      },
      "references": [
        {
          "type__sys": "document__sys",
          "document_version_id__sys": "11_1_0",
          "annotation__sys": "46"
        }
      ]
    }
]'
https://myvault.veevavault.com/api/v26.2/objects/documents/annotations/batch \
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "12_1_0",
            "global_version_id__sys": "119899_1001_36",
            "id__sys": "141"
        },
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "1001_0_1",
            "global_version_id__sys": "119899_1001_38",
            "id__sys": "142"
        },
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "12_1_0",
            "global_version_id__sys": "119899_1001_36",
            "id__sys": "143"
        },
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "12_1_0",
            "global_version_id__sys": "119899_1001_36",
            "id__sys": "144"
        },
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "12_1_0",
            "global_version_id__sys": "119899_1001_36",
            "id__sys": "145"
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response includes a `responseStatus` indicating whether each annotation object in the request body was successfully created. For successfully created annotations, the response also includes the following:

| Field | Description |
| --- | --- |
| `document_version_id__sys` | The ID and version number of the document where the annotation appears in the format `{documentId}_{majorVersion}_{minorVersion}`. For example, `138_2_1`. |
| `global_version_id__sys` | The Vault ID, document ID, and document version ID in the format `{vaultId}_{documentId}_{docVersionId}`. For example, `123456_2_1`. |
| `id` | The annotation ID. |
