<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-documents/retrieve-document-versions/ -->
<!-- title: Retrieve Document Versions -->

# Retrieve Document Versions

Retrieve all versions of a document.

GET`/api/{version}/objects/documents/{doc_id}/versions`

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
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "versions": [
        {
            "number": "0.1",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/0/1"
        },
        {
            "number": "0.2",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/0/2"
        },
        {
            "number": "1.0",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/1/0"
        },
        {
            "number": "1.1",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/1/1"
        },
        {
            "number": "2.0",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/0"
        },
        {
            "number": "2.1",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/1"
        },
        {
            "number": "2.2",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/2"
        },
        {
            "number": "2.3",
            "value": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/3"
        }
    ],
    "renditions":
        {
        "viewable_rendition__v": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/viewable_rendition__v",
        "veeva_distribution_package__c": "https://myvault.veevavault.com/api/v26.2/objects/documents/534/renditions/veeva_distribution_package__c"
    }
}
```

## Response Details

On `SUCCESS`, Vault returns a list of all available versions of the specified document. In the example response, document `id:534` has 8 different versions. Version 2.0 is the **latest steady state version**. Version 2.3 is the **latest version**. This document also has two different renditions: The `viewable_rendition__v` and a `veeva_distribution_package__c` rendition.
