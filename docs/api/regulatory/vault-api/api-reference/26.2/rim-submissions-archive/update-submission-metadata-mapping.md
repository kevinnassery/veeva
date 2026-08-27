<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/update-submission-metadata-mapping/ -->
<!-- title: Update Submission Metadata Mapping -->

# Update Submission Metadata Mapping

Update the mapping values of a submission.

PUT`/api/{version}/vobjects/submission__v/{submission_id}/actions/ectdmapping`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{submission_id}` | The `id` field value of the `submission__v` object record. To get this value, [use VQL to retrieve all records](/regulatory/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) on the `submission__v` object. |

Note that XML identifiers are read-only and cannot be updated via the API. If including XML identifiers in the request, the values will be ignored.

## Response

Copy to clipboard

```
[
    {
      "external_id__v": null,
      "drug_substance__v.name__v": "ethyl alcohol",
      "name__v": "1675_00S000000000802",
      "xml_id": "m2-3-s-drug-substance",
      "manufacturer__v.name__v": "Veeva Chemical"
    },
    {
      "external_id__v": null,
      "drug_substance__v.name__v": "ethyl alcohol",
      "name__v": "1677_00S000000000802",
      "xml_id": "m3-2-s-drug-substance",
      "manufacturer__v.name__v": "Veeva Chemical"
    },
    {
      "external_id__v": null,
      "nonclinical_study__v.name__v": "S001",
      "name__v": "1681_00S000000000802",
      "xml_id": "S001"
    },
    {
      "external_id__v": null,
      "clinical_study__v.name__v": "S001",
      "name__v": "1693_00S000000000802",
      "xml_id": "S001"
    }
]
```

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/submission__v/00S000000000101/actions/ectdmapping
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "name__v": "1675_00S000000000802",
            "responseStatus": "SUCCESS"
        },
        {
            "name__v": "1677_00S000000000802",
            "responseStatus": "SUCCESS"
        },
        {
            "name__v": "1681_00S000000000802",
            "responseStatus": "SUCCESS"
        },
        {
            "name__v": "1693_00S000000000802",
            "responseStatus": "SUCCESS"
        }
    ],
    "responseDetails": {
        "total": 4
    }
}
```
