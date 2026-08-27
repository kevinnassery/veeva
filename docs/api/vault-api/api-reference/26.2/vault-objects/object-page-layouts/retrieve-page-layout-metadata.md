<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-page-layouts/retrieve-page-layout-metadata/ -->
<!-- title: Retrieve Page Layout Metadata -->

# Retrieve Page Layout Metadata

Given a page layout `name`, retrieve the metadata for that specific page layout.

The page layout APIs consider the authenticated user’s permissions, so fields that are hidden from the authenticated user will not be included in the API response. For example, field-level security, object controls, and other object-level permissions are considered. Record-level permissions such as atomic security are not considered. Both active and inactive fields are included in the response.

This endpoint returns metadata without layout rules applied, instead returning layout rule configurations as metadata. If a layout rule references a token, this endpoint returns the unresolved token instead of resolving it in the response.

GET`/api/{version}/metadata/vobjects/{object_name}/page_layouts/{layout_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The `name` of the object from which to retrieve page layout metadata. |
| `{layout_name}` | The `name` of the page layout from which to retrieve metadata. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/vobjects/my_object__c/page_layouts/my_object_detail_page_layout__c
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "name": "my_object_detail_page_layout__c",
        "label": "My Object Detail Page Layout",
        "object": "my_object__c",
        "object_type": "base__v",
        "active": true,
        "description": "",
        "default_layout": true,
        "display_lifecycle_stages": false,
        "created_date": "2023-12-04T21:11:32.000Z",
        "last_modified_date": "2023-12-04T23:44:56.000Z",
        "layout_rules": [
            {
                "evaluation_order": 100,
                "status": "active__v",
                "fields_to_hide": [],
                "sections_to_hide": [
                    "my_related_objects__c"
                ],
                "controls_to_hide": [],
                "hide_layout": false,
                "hidden_pages": [],
                "displayed_as_readonly_fields": [
                    "link__sys"
                ],
                "displayed_as_required_fields": [
                    "my_related_object__c"
                ],
                "focus_on_layout": true,
                "expression": "IsBlank(my_related_object__c)"
            }
        ],
        "sections": [
            {
                "name": "details__c",
                "title": "Details",
                "type": "detail",
                "help_content": null,
                "show_in_lifecycle_states": [],
                "properties": {
                    "layout_type": "One-Column",
                    "items": [
                        {
                            "type": "field",
                            "reference": "name__v",
                            "status": "active__v"
                        },
                        {
                            "type": "field",
                            "reference": "status__v",
                            "status": "active__v"
                        },
                        {
                            "type": "field",
                            "reference": "created_date__v",
                            "status": "active__v"
                        }
                    ]
                }
            },
            {
                "name": "my_related_objects__c",
                "title": "My Related Objects",
                "type": "related_object",
                "help_content": null,
                "show_in_lifecycle_states": [],
                "properties": {
                    "relationship": "my_related_objects__cr",
                    "related_object": "my_related_object__c",
                    "prevent_record_create": false,
                    "modal_create_record": false,
                    "criteria_vql": null,
                    "columns": [
                        {
                            "reference": "name__v",
                            "width": "200",
                            "status": "active__v"
                        },
                        {
                            "reference": "my_object__c",
                            "width": "200",
                            "status": "active__v"
                        }
                    ]
                }
            }
        ]
    }
}
```

## Response Details

On `SUCCESS`, returns metadata for the specified page layout, including the `object_type`, `layout_rules`, and `sections`.
