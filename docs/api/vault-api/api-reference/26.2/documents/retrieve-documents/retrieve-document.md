<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-documents/retrieve-document/ -->
<!-- title: Retrieve Document -->

# Retrieve Document

Retrieve all metadata from a document.

GET`/api/{version}/objects/documents/{doc_id}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/450
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "document": {
        "id": 450,
        "binder__v": false,
        "allow_download_embedded_viewer__v": true,
        "reviewer__v": {
            "users": [
                25519,
                25516
            ],
            "groups": [
                1358979070034
            ]
        },
        "viewer__v": {
            "users": [
                25519,
                25516,
                25597
            ],
            "groups": [
                1358979070034
            ]
        },
        "distribution_contacts__v": {
            "users": [],
            "groups": []
        },
        "consumer__v": {
            "users": [],
            "groups": []
        },
        "approver__v": {
            "users": [
                25516
            ],
            "groups": []
        },
        "editor__v": {
            "users": [
                25519,
                25516
            ],
            "groups": []
        },
        "owner__v": {
            "users": [
                46916
            ],
            "groups": []
        },
        "coordinator__v": {
            "users": [],
            "groups": []
        },
        "crosslink__v": false,
        "lifecycle__v": "General Lifecycle",
        "version_created_by__v": 46916,
        "language__v": [
            "English"
        ],
        "minor_version_number__v": 1,
        "created_by__v": 46916,
        "annotations_lines__v": 0,
        "version_creation_date__v": "2015-03-12T16:24:33.539Z",
        "country__v": [],
        "md5checksum__v": "94e18bdbcf695c905a5968429e0c5204",
        "restrict_fragments_by_product__v": true,
        "annotations_notes__v": 0,
        "version_modified_date__v": "2015-03-12T16:24:54.000Z",
        "pages__v": 1,
        "major_version_number__v": 1,
        "annotations_anchors__v": 0,
        "product__v": [
            "1357662840293"
        ],
        "export_filename__v": "451Chole",
        "annotations_resolved__v": 0,
        "type__v": "Reference Document",
        "size__v": 11599,
        "description__v": "This is my document.",
        "status__v": "Draft",
        "annotations_unresolved__v": 0,
        "document_creation_date__v": "2015-02-25T01:26:55.845Z",
        "locked__v": false,
        "format__v": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "annotations_links__v": 0,
        "document_number__v": "REF-0201",
        "annotations_all__v": 0,
        "last_modified_by__v": 46916,
        "name__v": "CholeCap Information",
        "subtype__v": "Prescribing Information"
    },
    "renditions":
        {
        "viewable_rendition__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/450/renditions/viewable_rendition__v",
        "veeva_distribution_package__c": "https://myvault.veevavault.com/api/v26.2/objects/documents/450/renditions/veeva_distribution_package__c"
    },
    "versions": [
        {
            "number": "0.1",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/450/versions/0/1"
        },
        {
            "number": "1.0",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/450/versions/1/0"
        },
        {
            "number": "1.1",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/450/versions/1/1"
        }
    ],
    "attachments": [
        {
            "id": 547,
            "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/450/attachments/547"
        }
    ]
}
```

## Response Details

The boolean field `binder__v` indicates whether the returned document is a regular document (`true`) or a binder (`false`). The absence of this field means it is a document. Binder node structures are not listed as part of the response; they must be determined through the Binder API.

The boolean field `crosslink__v` indicates whether the returned document is a regular document (`true`) or a CrossLink document (`false`).
