<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/retrieve-document-version-renditions/ -->
<!-- title: Retrieve Document Version Renditions -->

# Retrieve Document Version Renditions

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/renditions`

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
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/0/renditions
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "renditionTypes": [
        "viewable_rendition__v",
        "imported_rendition__c",
        "veeva_distribution_package__c"
    ],
    "renditions": {
        "viewable_rendition__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/0/renditions/viewable_rendition__v",
        "veeva_distribution_package__c": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/0/renditions/veeva_distribution_package__c"
    }
}
```
