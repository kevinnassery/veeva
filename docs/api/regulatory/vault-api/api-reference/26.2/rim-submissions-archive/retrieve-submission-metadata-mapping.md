<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/retrieve-submission-metadata-mapping/ -->
<!-- title: Retrieve Submission Metadata Mapping -->

# Retrieve Submission Metadata Mapping

Retrieve the metadata mapping values of an eCTD submission package.

GET`/api/{version}/vobjects/submission__v/{submission_id}/actions/ectdmapping`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `text/csv` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{submission_id}` | The `id` field value of the `submission__v` object record. To get this value, [use VQL to retrieve all records](/regulatory/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) on the `submission__v` object. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/submission__v/00S000000000101/actions/ectdmapping
```

## Response

Copy to clipboard

```
{
 "responseStatus": "SUCCESS",
    "responseDetails": {
    "total": 2
    },
    "data": [
    {
      "name__v": "1675_00S000000000802",
      "external_id__v": null,
      "drug_substance__v":"Ethyl Alcohol",
      "drug_substance__v.name__v": "",
      "xml_id": "m2-3-s-drug-substance",
      "manufacturer__v":"Veeva",
      "manufacturer__v.name__v": ""
    },
    {
      "name__v": "1681_00S000000000802",
      "external_id__v": null,
      "nonclinical_study__v":"Study001",
      "nonclinical_study__v.name__v": "",
      "xml_id": "S001"
    }
  ]
}
```

## Response Details

On `SUCCESS`, the response includes the following information for each XML metadata node which requires mapping:

| Field Name | Description |
| --- | --- |
| `name__v` | The name of the metadata mapping record in the submission metadata. |
| `external_id__v` | The external ID of the metadata mapping record. This value is only available if the mappings were created or updated externally. |
| `xml_id` | The XML ID (`leaf_id`) of the section being mapped. This is an identifier from the imported XML of the XML node. This is analogous to the `submission_metadata__v.tag_id__v`. |

Mapping Fields:

Possible mappings include: `clinical_site__v`, `clinical_study__v`, `drug_product__v`, `drug_substance__v`, `indication__v`, `manufacturer__v`, and `nonclinical_study__v`.

Mapping fields are returned as a pair of properties: a source property that has the mapping identifier from the imported XML and a second property as `[mapping].name__v` which specifies the target object record. If the second property is empty, the mapping has not been completed. See [Update Submission Metadata Mapping](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/update-submission-metadata-mapping).
