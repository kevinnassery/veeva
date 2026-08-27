<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-document-types/retrieve-all-document-types/ -->
<!-- title: Retrieve All Document Types -->

# Retrieve All Document Types

Retrieve all document types. These are the top-level of the document hierarchy (Type > Subtype > Classification).

GET`/api/{version}/metadata/objects/documents/types`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/types
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "types": [
        {
            "label": "Base Document",
            "value": "https://etmf-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/base_document__v"
        },
        {
            "label": "Centralized Testing",
            "value": "https://etmf-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/centralized_testing__c"
        },
        {
            "label": "Central Trial Documents",
            "value": "https://etmf-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/central_trial_documents__c"
        },
        {
            "label": "Country Master File",
            "value": "https://etmf-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/country_master_file__v"
        },
        {
            "label": "Data Management",
            "value": "https://etmf-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/data_management__c"
        },
        {
            "label": "Final CRF",
            "value": "https://etmf-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/final_crf__v"
        },
        {
            "label": "IP and Trial Supplies",
            "value": "https://etmf-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/types/ip_and_trial_supplies__c"
        },
    ],
    "lock": "https://etmf-veevapharm.veevavault.com/api/v26.2/metadata/objects/documents/lock"
}
```

## Response Details

The response lists all document types configured in the Vault. These vary by Vault application and configuration.

* Standard types end in `__v`.
* Some Vaults include sample types `__c`.
* Admins can configure custom types `__c`.

The response includes the following information:

| Metadata Field | Description |
| --- | --- |
| `types` | List of all standard and custom document types in your Vault. These are the top-level of the document hierarchy (Type > Subtype > Classification). |
| `label` | Label of each document type as seen in the API and UI. |
| `value` | URL to retrieve the metadata associated with each document type. |
| `lock` | URL to retrieve the document lock metadata (document check-out). |

The `label` is displayed in the UI. These can be applied to documents and binders.
