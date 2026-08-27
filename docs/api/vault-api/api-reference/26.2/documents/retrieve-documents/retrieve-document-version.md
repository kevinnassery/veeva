<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-documents/retrieve-document-version/ -->
<!-- title: Retrieve Document Version -->

# Retrieve Document Version

Retrieve all fields and values configured on a document version.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}`

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
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/3
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "document": {
        "id": 534,
        "allow_download_embedded_viewer__v": true,
        "reviewer__v": {
            "users": [
                46916,
                45589
            ],
            "groups": [
                1359484520721
            ]
        },
        "crosslink__v": false,
        "lifecycle__v": "General Lifecycle",
        "version_created_by__v": 46916,
        "language__v": [
            "English"
        ],
        "minor_version_number__v": 3,
        "created_by__v": 46916,
        "annotations_lines__v": 0,
        "version_creation_date__v": "2015-03-13T16:24:33.539Z",
        "country__v": [],
        "md5checksum__v": "94e18bdbcf695c905a5989629e0c5204",
        "restrict_fragments_by_product__v": true,
        "annotations_notes__v": 0,
        "version_modified_date__v": "2015-03-13T16:24:54.000Z",
        "pages__v": 1,
        "major_version_number__v": 2,
        "annotations_anchors__v": 0,
        "product__v": [
            "1357662840293"
        ],
        "export_filename__v": "WD",
        "annotations_resolved__v": 0,
        "type__v": "Reference Document",
        "size__v": 11518,
        "description__v": "",
        "status__v": "Draft",
        "annotations_unresolved__v": 0,
        "document_creation_date__v": "2015-02-25T01:26:55.845Z",
        "locked__v": false,
        "format__v": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "annotations_links__v": 0,
        "document_number__v": "REF-0059",
        "annotations_all__v": 0,
        "last_modified_by__v": 46916,
        "name__v": "WonderDrug Information",
        "binder__v": false,
        "subtype__v": "Prescribing Information"
    },
    "renditions": [
        {
        "viewable_rendition__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/viewable_rendition__v",
        "veeva_distribution_package__c": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/veeva_distribution_package__c"
        }
    ],
    "versions": [
        {
            "number": "2.3",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/3"
        }
    ],
    "attachments": [
        {
            "id": 547,
            "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/attachments/547"
        },
        {
            "id": 561,
            "url": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/attachments/561"
        }
    ]
}
```

## Response Details

On `SUCCESS`, Vault returns all fields and values for the specified version of the document. The example response shows information for document `id:534` version 2.3.
