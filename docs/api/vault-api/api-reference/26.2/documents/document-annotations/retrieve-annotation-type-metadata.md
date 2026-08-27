<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/retrieve-annotation-type-metadata/ -->
<!-- title: Retrieve Annotation Type Metadata -->

# Retrieve Annotation Type Metadata

Retrieves the metadata of an annotation type, including metadata and value sets for all supported fields on the annotation type. Learn more about [annotation types](/library/references/about-annotations/#Annotation_Types).

GET`/api/{version}/metadata/objects/documents/annotations/types/{annotation_type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{annotation_type}` required | The name of the annotation type. Valid annotation types include:  * `note__sys` * `line__sys` * `document_link__sys` * `permalink_link__sys` * `anchor__sys` * `reply__sys` * `external_link__sys`  The following annotation types are only valid in Medical and PromoMats Vaults:  * `suggested_link__sys` * `approved_link__sys` * `auto_link__sys` * `keyword_link__sys` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/annotations/types/note__sys' \
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "name": "note__sys",
        "allows_replies": true,
        "allowed_placemark_types": [
            "arrow__sys",
            "ellipse__sys",
            "page_level__sys",
            "rectangle__sys",
            "sticky__sys",
            "text__sys"
        ],
        "allowed_reference_types": [],
        "fields": [
            {
                "name": "created_by_delegate_user__sys",
                "type": "String",
                "system_managed": true,
                "value_set": []
            },
            {
                "name": "created_by_user__sys",
                "type": "String",
                "system_managed": true,
                "value_set": []
            },
            {
                "name": "created_date_time__sys",
                "type": "DateTime",
                "system_managed": true,
                "value_set": []
            },
            {
                "name": "document_version_id__sys",
                "type": "String",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "external_id__sys",
                "type": "String",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "id__sys",
                "type": "String",
                "system_managed": true,
                "value_set": []
            },
            {
                "name": "modified_by_user__sys",
                "type": "String",
                "system_managed": true,
                "value_set": []
            },
            {
                "name": "modified_date_time__sys",
                "type": "DateTime",
                "system_managed": true,
                "value_set": []
            },
            {
                "name": "persistent_id__sys",
                "type": "String",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "title__sys",
                "type": "String",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "color__sys",
                "type": "String",
                "system_managed": false,
                "value_set": [
                    "yellow_light__sys",
                    "green_dark__sys",
                    "green_light__sys",
                    "orange_dark__sys",
                    "orange_light__sys",
                    "pink_dark__sys",
                    "pink_light__sys",
                    "purple_dark__sys",
                    "purple_light__sys",
                    "red_dark__sys",
                    "red_light__sys",
                    "yellow_dark__sys"
                ]
            },
            {
                "name": "comment__sys",
                "type": "String",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "original_source_document_version_id__sys",
                "type": "String",
                "system_managed": true,
                "value_set": []
            },
            {
                "name": "reply_count__sys",
                "type": "Number",
                "system_managed": true,
                "value_set": []
            },
            {
                "name": "state__sys",
                "type": "String",
                "system_managed": false,
                "value_set": [
                    "open__sys",
                    "resolved__sys"
                ]
            },
            {
                "name": "tag_names__sys",
                "type": "String list",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "type__sys",
                "type": "String",
                "system_managed": false,
                "value_set": [
                    "note__sys"
                ]
            }
        ]
    }
}
```

## Response Details

On `SUCCESS`, the response includes a list of metadata information for the specified annotation type. Each response may include some or all of the following fields depending on type:

| Field | Description |
| --- | --- |
| `allows_replies` | if `true`, this annotation type allows replies. |
| `allowed_placemark_types` | A list of placemark types this annotation type allows. Learn more about [placemark types](/library/references/about-annotations/#Annotation_Placemarks). |
| `allowed_reference_types` | A list of reference types that this annotation type allows. Learn more about [reference types](/library/references/about-annotations/#Annotation_References). |
| `fields` | A list of fields configured on the annotation type. For more details about annotation fields, see [Read Annotations by Document Version and Type](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-document-version-and-type). |
