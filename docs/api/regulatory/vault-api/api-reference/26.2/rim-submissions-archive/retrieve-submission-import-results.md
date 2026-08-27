<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/retrieve-submission-import-results/ -->
<!-- title: Retrieve Submission Import Results -->

# Retrieve Submission Import Results

Caution

This endpoint will be modified as of the 26R3 release on December 4th, 2026. Although this endpoint will continue to work, it will no longer return the data array containing submission binder information after the 26R3 release.

After Vault has finished processing the submission import job, use this request to retrieve the results of the completed submission binder.

Before submitting this request:

* You must be assigned permissions to use the API and permissions to view the specified `submission__v` object record.
* There must be a previously submitted and completed submission import request, i.e., the status of the import job must be no longer active.

GET`/api/{version}/vobjects/submission__v/{submission_id}/actions/import/{job_id}/results`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{submission_id}` | The `id` field value of the `submission__v` object record. To get this value, [use VQL to retrieve all records](/regulatory/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) on the `submission__v` object. |
| `{job_id}` | The `jobId` field value returned from the [Import Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/import-submission) request. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/submission__v/00S000000010001/actions/import/727301/results
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "id": 7860,
            "major_version_number__v": "1",
            "minor_version_number__v": "0"
        }
    ],
    "importMessages": {
        "validationError": [
            [
                "The XML leaf checksum does not match the file's checksum:",
                "Informational"
            ],
            {
                "validationFileData": [
                    "Title: \"Executed Batch Records - Product\", ID: \"veev_92330c06-1750-42b4-9c12-bfe13a56a517\", \"m3/32-body-data/32r-reg-info/regional-information-1.pdf\"",
                    "Title: \"Executed Batch Records - Product\", ID: \"veev_ede4b222-f2eb-4abb-85c5-d1fb50a8bdba\", \"m3/32-body-data/32r-reg-info/regional-information-1.pdf\""
                ]
            },
            [
                "The following eCTD leafs were not found. Vault created a placeholder to represent each missing leaf:",
                "Informational"
            ],
            {
                "validationFileData": [
                    "Title: \"Drug Substance Enalapril maleate-VeevaPharm - Cork\", ID: \"veev_430ac294-f799-4006-accf-6cdc8f86980e\", ",
                    "Title: \"Drug Product Enalapril capsules-Enalapril 20 mg capsules-VeevaPharm - Barcelona\", ID: \"veev_ff2c8605-3cbc-49a0-9661-6f64c5a9fae0\", ",
                    "Title: \"Drug Product Enalapril tablets-Enalapril 10 mg tablets-VeevaPharm - Barcelona\", ID: \"veev_3ace407d-a3d8-4666-8019-17604a9cd6ba\", ",
                    "Title: \"Pharmaceutical Development\", ID: \"veev_1237e088-40f4-40e5-8c9e-874f446be1bd\", ",
                    "Title: \"Description of Manufacturing Process and Process Controls\", ID: \"veev_ef371ad1-ecb5-4808-bfb9-ec0ff3d3ba26\", ",
                    "Title: \"Specification(s)\", ID: \"veev_4ec4eaca-e547-4d99-97f3-e5896506966f\", ",
                    "Title: \"Pharmaceutical Development\", ID: \"veev_5c3ddb35-a19d-4b50-ad60-5cd09c182fb5\", ",
                    "Title: \"Batch Formula\", ID: \"veev_4a64bfbe-8b01-49fa-814b-8aa2bac5b03b\", ",
                    "Title: \"Controls of Critical Steps and Intermediates\", ID: \"veev_d9a7c571-6211-43a5-a9fc-8bd682cbb8e4\", ",
                    "Title: \"Process Validation and/or Evaluation\", ID: \"veev_8b975b8d-f2b8-4d0c-b220-34e63a888558\", ",
                    "Title: \"Analytical Procedures\", ID: \"veev_fd609525-ca9c-4d99-8abc-48f794254c74\", ",
                    "Title: \"Validation of Analytical Procedures\", ID: \"veev_c77796ad-7edf-4ea8-b5cf-06f6ef0ba296\", ",
                    "Title: \"Batch Analyses\", ID: \"veev_47b5dcc4-d42a-461f-9116-76e716b47fb6\", ",
                    "Title: \"Characterisation of Impurities\", ID: \"veev_4f2d5784-8ad6-4493-93b8-76eaf6cc1495\", ",
                    "Title: \"Justification of Specification(s)\", ID: \"veev_c0da5a9b-69b6-412b-ae7d-648a1ffd9add\", ",
                    "Title: \"Facilities and Equipment - Enalapril capsules-Enalapril 20 mg capsules-VeevaPharm - Barcelona\", ID: \"veev_7453714a-1164-423b-a07d-8db0c537496e\", ",
                    "Title: \"Facilities and Equipment - Enalapril tablets-Enalapril 10 mg tablets-VeevaPharm - Barcelona\", ID: \"veev_7467ad96-da58-47e6-9556-1fddec1d96b6\", "
                ]
            },
            [
                "Files not referenced by the submission XML were found within the submission folder. These files were imported:",
                "Warning"
            ],
            {
                "validationFileData": [
                    "\"\", \"\", \"0001-workingdocuments/2-7-2-summary-of-clinical-pharmacology-studies.docx\"",
                    "\"\", \"\", \"0001-workingdocuments/2-3-p-drug-product-summary.docx\"",
                    "\"\", \"\", \"0001-workingdocuments/2-7-1-summary-of-biopharmaceutic-studies-and-associated-analytical-methods.docx\"",
                    "\"\", \"\", \"0001-workingdocuments/2-7-4-summary-of-clinical-safety.docx\"",
                    "\"\", \"\", \"0001-workingdocuments/2-7-3-summary-of-clinical-efficacy.docx\"",
                    "\"\", \"\", \"0001-workingdocuments/2-4-nonclinical-overview.docx\"",
                    "\"\", \"\", \"0001-workingdocuments/2-5-clinical-overview.docx\""
                ]
            },
            [
                "index.xml is invalid, importing with an invalid xml may affect the ability to create a rendition or display in the Viewer.",
                "Warning"
            ]
        ]
    }
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

| Field Name | Description |
| --- | --- |
| `id` | The `id` field value of the submission binder which was created by the imported files. |
| `major_version_number__v` | The major version number of the binder. |
| `minor_version_number__v` | The minor version number of the binder. |
| `importMessages` | Lists error and warning messages for the import. Learn more in [Vault Help](https://regulatory.veevavault.help/en/gr/28082/#import-warning--error-details). |

To retrieve the metadata from the newly created submission binder, send `GET` to `/api/{version}/objects/binders/{id}`.
