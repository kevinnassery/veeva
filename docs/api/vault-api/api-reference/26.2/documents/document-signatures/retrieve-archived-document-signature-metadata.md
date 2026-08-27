<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-signatures/retrieve-archived-document-signature-metadata/ -->
<!-- title: Retrieve Archived Document Signature Metadata -->

# Retrieve Archived Document Signature Metadata

Retrieve all metadata for signatures on archived documents. Learn more about [signature pages in Vault Help](https://platform.veevavault.help/en/gr/40560).

GET`/api/{version}/metadata/query/archived_documents/relationships/document_signature__sysr`

Note

Document archive is not available in all Vaults. [Learn more in Vault Help.](https://platform.veevavault.help/en/gr/34126)

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/query/archived_documents/relationships/document_signature__sysr
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "properties": {
    "name": "document_signature__sysr",
    "fields": [
      {
        "name": "id",
        "type": "id"
      },
      {
        "name": "signature_user__sys",
        "type": "id"
      },
      {
        "name": "signed_document__sys",
        "type": "id"
      },
      {
        "name": "signed_document_major_version__sys",
        "type": "Number"
      },
      {
        "name": "signed_document_minor_version__sys",
        "type": "Number"
      },
      {
        "name": "signature_time__sys",
        "type": "DateTime"
      },
      {
        "name": "manifest_signature__sys",
        "type": "Boolean"
      },
      {
        "name": "task__sys",
        "type": "String"
      },
      {
        "name": "task_label__sys",
        "type": "String"
      },
      {
        "name": "workflow_label__sys",
        "type": "String"
      },
      {
        "name": "workflow_name__sys",
        "type": "String"
      },
      {
        "name": "signature_meaning__sys",
        "type": "String"
      },
      {
        "name": "verdict_name__sys",
        "type": "String"
      },
      {
        "name": "verdict__sys",
        "type": "String"
      },
      {
        "name": "delegate_user__sys",
        "type": "id"
      },
      {
        "name": "task_description__sys",
        "type": "String"
      },
      {
        "name": "workflow__sys",
        "type": "id"
      },
      {
        "name": "signature_name__sys",
        "type": "String"
      },
      {
        "name": "signature_title__sys",
        "type": "String"
      },
      {
        "name": "delegate_title__sys",
        "type": "String"
      },
      {
        "name": "delegate_name__sys",
        "type": "String"
      }
    ]
  }
}
```

## Response Details

On `SUCCESS`, Vault returns all metadata for archived document signatures.
