<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-documents/retrieve-document-version-text/ -->
<!-- title: Retrieve Document Version Text -->

# Retrieve Document Version Text

Retrieve the plain text of a specific document version.

GET`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/text`

## Headers

| Name | Description |
| --- | --- |
| `Accept` optional | `text/plain` (default). The format of the response will always be `text/plain` regardless of the value provided for the `Accept` header. |

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
https://myvault.veevavault.com/api/v26.2/objects/documents/201/versions/2/1/text
```

## Response

Copy to clipboard

```
HIGHLIGHTS OF PRESCRIBING INFORMATION
----------------------WARNINGS AND PRECAUTIONS-----------------------­
These highlights do not include all the information needed to use
Skeletal muscle effects (e.g., myopathy and rhabdomyolysis): Risks increase CHOLECAP safely and effectively. See full prescribing information for
when higher doses are used concomitantly with cyclosporine, fibrates, and CHOLECAP.
```

## Response Details

On `SUCCESS`, Vault returns the plain text of the source file from the document.

On `FAILURE`, the response returns an error message describing the reason for the failure. For example, if the specified document is not found, no text is found, or the document is password-protected.
