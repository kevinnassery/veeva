<!-- source: https://general.veevavault.dev/regulatory/vault-api/guides/vault-api-veeva-submissions-archive/ -->
<!-- title: Using Vault API for Veeva RIM -->

# Using Vault API for Veeva RIM

Note

Starting in 26R3, Veeva RIM's Submissions Archive application will no longer generate binder substructures for imported or published-in-Vault submissions (via Veeva RIM's Submissions Publishing application), and instead only create the top-level binder (with a *Document Type* of *Submissions Archive* > *Structure*).

This guide outlines how to leverage Vault API to work with system-managed Veeva Submissions Archive data. Instead of sending requests to the legacy [Retrieve Submissions Archive Binder](/regulatory/vault-api/api-reference/22.3/rim-submissions-archive/retrieve-submissionsarchive-binder) endpoint, we recommend the following alternative solutions depending on the functionality required for your integrations:

* [Check a *Submission*'s import status](#Checking_Submission_Status)
* [Retrieve the structure of an imported *Submission*](#Retrieving_Submission_Archive_Structure)
* [Retrieve the structure of *Application*-level correspondences](#Retrieving_Application_Correspondence_Structure)
* [Build export workflows](#Building_Export_Workflows)
* [Retrieve binder IDs](#Retrieving_Binder_IDs)

## Checking the Submission Status

You can check the status of an imported or published *Submission* by [sending a VQL query](/regulatory/vault-api/api-reference/26.2/vault-query-language-vql/submitting-a-query) with Vault API.

### Retrieving a Submission's Import Status

The following query retrieves the record ID, name, and *Submissions Archive Status* (`archive_status__v`) of a *Submission* record:

Copy to clipboard

```
SELECT
  id, name__v, archive_status__v
FROM submission__v
WHERE
  id = '00S000000001001'
```

On `SUCCESS`, the response includes the record's *Submissions Archive Status* (`archive_status__v`). In this example, the status is `IMPORT_SUCCEEDED`. See the full [list of archive statuses](https://regulatory.veevavault.help/en/gr/28082/#archive-status).

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseDetails": {
    "pagesize": 1000,
    "pageoffset": 0,
    "size": 1,
    "total": 1
  },
  "data": [
    {
      "id": "00S000000001001",
      "name__v": "1",
      "archive_status__v": "IMPORT_SUCCEEDED"
    }
  ]
}
```

### Retrieving a Submission's Dossier Status

To check the *Dossier Status* (`submission__v.dossier_status__v`) of *Submissions* published with Veeva Submissions Publishing, send the following VQL query:

Copy to clipboard

```
SELECT
  id, name__v, dossier_status__v
FROM submission__v
WHERE
  id = '00S000000002001'
```

On `SUCCESS`, the response includes the record's *Dossier Status* (`dossier_status__v`). In this example, the status is `publishing_active__v`.

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseDetails": {
    "pagesize": 1000,
    "pageoffset": 0,
    "size": 1,
    "total": 1
  },
  "data": [
    {
      "id": "00S000000002001",
      "name__v": "1",
      "dossier_status__v": "publishing_active__v"
    }
  ]
}
```

A published *Submission* can have the following *Dossier Status* values:

* *Publishing Active* (`publishing_active__v`)
* *Publishing Inactive* (`publishing_inactive__v`)
* *Transmission Failed* (`transmission_failed__v`)
* *Transmission Successful* (`transmission_successful__v`)
* *Transmission in Queue* (`transmission_in_queue__v`)
* *Transmission in Progress* (`transmission_in_progress__v`)

## Retrieving the Submission Archive Structure

You can send a VQL query to retrieve a *Submission* record's metadata (`submission_metadata__v`), which defines its structure.

The following query retrieves the metadata of an imported *Submission*:

Copy to clipboard

```
SELECT
  id, parent__v, title__v, source_file_path__v,
  node_type__v, section_type__v,
  xlink_href__v, xlink_type__v,
  operation__v,
  referenced_document_id__v, referenced_document_major_version__v, referenced_document_minor_version__v
FROM submission_metadata__v
WHERE
  sequence_record_id__v = '00S000000001001'
```

On `SUCCESS`, the response returns the metadata of an imported or published-in-Vault *Submission*.

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseDetails": {
    "pagesize": 1000,
    "pageoffset": 0,
    "size": 5,
    "total": 5
  },
  "data": [
    {
      "id": "0SM000000002017",
      "parent__v": "0SM000000002011",
      "title__v": "submissionunit.xml",
      "source_file_path__v": "/Prioirty_Number/1/submissionunit.xml",
      "node_type__v": null,
      "section_type__v": null,
      "xlink_href__v": null,
      "xlink_type__v": null,
      "operation__v": "new",
      "referenced_document_id__v": 7,
      "referenced_document_major_version__v": 1,
      "referenced_document_minor_version__v": 0
    },
    {
      "id": "0SM000000002018",
      "parent__v": "0SM000000002011",
      "title__v": "sha256.txt",
      "source_file_path__v": "/Prioirty_Number/1/sha256.txt",
      "node_type__v": null,
      "section_type__v": null,
      "xlink_href__v": null,
      "xlink_type__v": null,
      "operation__v": "new",
      "referenced_document_id__v": 4,
      "referenced_document_major_version__v": 1,
      "referenced_document_minor_version__v": 0
    },
    {
      "id": "0SM00000001M024",
      "parent__v": "0SM000000002011",
      "title__v": "TYPE:regulatory_rd",
      "source_file_path__v": null,
      "node_type__v": null,
      "section_type__v": "CORRESPONDENCE_NODE",
      "xlink_href__v": null,
      "xlink_type__v": null,
      "operation__v": null,
      "referenced_document_id__v": null,
      "referenced_document_major_version__v": null,
      "referenced_document_minor_version__v": null
    },
    {
      "id": "0SM00000001M025",
      "parent__v": "0SM00000001M024",
      "title__v": "SUBTYPE:regulatory_rd:generalCorrespondence",
      "source_file_path__v": null,
      "node_type__v": null,
      "section_type__v": "CORRESPONDENCE_NODE",
      "xlink_href__v": null,
      "xlink_type__v": null,
      "operation__v": null,
      "referenced_document_id__v": null,
      "referenced_document_major_version__v": null,
      "referenced_document_minor_version__v": null
    },
    {
      "id": "0SM00000001M026",
      "parent__v": "0SM00000001M025",
      "title__v": "CLASSIFICATION:regulatory_rd:generalCorrespondence:meetingCorrespondence",
      "source_file_path__v": null,
      "node_type__v": null,
      "section_type__v": "CORRESPONDENCE_NODE",
      "xlink_href__v": null,
      "xlink_type__v": null,
      "operation__v": null,
      "referenced_document_id__v": null,
      "referenced_document_major_version__v": null,
      "referenced_document_minor_version__v": null
    }
  ]
}
```

The returned metadata contains the following information:

| Name | Description |
| --- | --- |
| `id` | The ID of the submission metadata (`submission_metadata__v`) record. |
| `parent__v` | The ID of the current node's parent record. A null value indicates the current node is a root node; a root node has no parent node. |
| `title__v` | The leaf title or document title for display within the Submissions Archive Viewer. |
| `source_file_path__v` | The file path of the source file upon import. Only document nodes have this field populated. |
| `node_type__v` | The type of node. Possible values include: `CORRESPONDENCE_NODE`, `STF_INDEX_XML`, `STF_LEAF`, `FORM_TYPE`. |
| `section_type__v` | The type of section. Only section nodes have this field populated. |
| `xlink_href__v` | Captures the `xlink:href` attribute from the eCTD XML. |
| `xlink_type__v` | Captures the `xlink:type` attribute from the eCTD XML. |
| `operation__v` | Captures the XML's leaf operation value. Possible values include: `new`, `replace`, `delete`, `append`, `suspend`. |
| `referenced_document_id__v` | The document ID in Vault to which the *Submission Metadata* [system-managed record](https://regulatory.veevavault.help/en/gr/450732/#system-managed-objects) refers. Only document nodes have this field populated. |
| `referenced_document_major_version__v` | The major version number of the referenced document. |
| `referenced_document_minor_version__v` | The minor version number of the referenced document. |

## Retrieving the Application Correspondence Structure

Correspondence documents consist of *Application*-level correspondence and *Submission*-level correspondence. *Application*-level correspondence documents are associated with *Applications* only, while *Submission*-level correspondence documents are associated with a specific *Submission* of a specific *Application*.

The [Retrieving the Submission Archive Structure](#Retrieving_Submission_Archive_Structure) query example retrieves all nodes of an imported *Submission* record, but it doesn't retrieve *Application*-level correspondence.

To retrieve all nodes of a *Submission* as well as *Application*-level correspondence, you can send Vault API the following query:

Copy to clipboard

```
SELECT
  id, parent__v, title__v, source_file_path__v,
  node_type__v, section_type__v,
  xlink_href__v, xlink_type__v,
  operation__v,
  referenced_document_id__v, referenced_document_major_version__v, referenced_document_minor_version__v,
  application_record_id__v, sequence_record_id__v
FROM submission_metadata__v
WHERE
  (sequence_record_id__v = '00S000000001001') OR
  (application_record_id__v = '00A000000001001' AND node_type__v = 'CORRESPONDENCE_NODE' AND sequence_record_id__v = null)
```

On `SUCCESS`, the response returns the metadata of an imported *Submission* and any *Application*-level correspondence documents. The following node example displays the metadata for an *Application*-level correspondence.

Copy to clipboard

```
{
  "id": "0SM00000001M028",
  "parent__v": "0SM00000001M023",
  "title__v": "diyrim_eko background1",
  "source_file_path__v": "regulatory_rd/generalCorrespondence/healthAuthorityAdvice/diyrim_eko background1",
  "node_type__v": "CORRESPONDENCE_NODE",
  "section_type__v": null,
  "xlink_href__v": null,
  "xlink_type__v": null,
  "operation__v": "new",
  "referenced_document_id__v": 202,
  "referenced_document_major_version__v": 0,
  "referenced_document_minor_version__v": 1,
  "application_record_id__v": "00A000000001001",
  "sequence_record_id__v": null
}
```

The node displayed above has a value for `source_file_path__v`, indicating it's a document node. The `node_type__v` of `CORRESPONDENCE_NODE` indicates this is a correspondence document. If `application_record_id__v` is populated while `sequence_record_id__v` is left null, this indicates an *Application*-level correspondence document.

## Building Export Workflows

There may be instances where your organization needs to build export workflows. Export workflows may be capable of retrieving the entire structure of a *Submission*, building its folder structure, fetching the contents of each document, and rebuilding the *Submission* package in an external system.

To expedite the export of one or more *Submissions* or *Applications*, we recommend sending requests to the [Export Single Submission](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-single-submission) or [Export Multiple Submissions](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/export-multiple-submissions) endpoints.

## Retrieving Binder IDs

Caution

We do not recommend your integration workflows rely upon the binder ID, as binders could be deprecated with future releases.

You can retrieve the binder ID of an imported *Submission* by sending a VQL query with Vault API. The following query adds a condition, `parent__v = null`, that only fetches the root node of the binder.

Copy to clipboard

```
SELECT
  id, binder_id__v
FROM submission_metadata__v
WHERE
  sequence_record_id__v = '00S000000001001' AND
  parent__v = null
```

On `SUCCESS`, the response includes the binder ID (`binder_id__v`).

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseDetails": {
    "pagesize": 1000,
    "pageoffset": 0,
    "size": 1,
    "total": 1
  },
  "data": [
    {
      "id": "0SM000000002011",
      "binder_id__v": 9
    }
  ]
}
```
