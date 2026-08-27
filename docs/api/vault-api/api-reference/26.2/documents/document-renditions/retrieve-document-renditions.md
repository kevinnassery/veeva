<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-renditions/retrieve-document-renditions/ -->
<!-- title: Retrieve Document Renditions -->

# Retrieve Document Renditions

GET`/api/{version}/objects/documents/{doc_id}/renditions`

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
https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions
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
        "viewable_rendition__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/viewable_rendition__v",
        "veeva_distribution_package__c": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/veeva_distribution_package__c"
    }
}
```

## Response Details

| Metadata Field | Description |
| --- | --- |
| `renditionTypes[n]` | List of all rendition types configured for the specified document. |
| `renditions[n]` | List of renditions available for the specified document and the endpoint URL to retrieve them. |
