<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/remove-submission/ -->
<!-- title: Remove Submission -->

# Remove Submission

Delete a previously imported submission from your Vault.

By removing a submission, you delete any sections created in the archive binder as part of the submission import. This will also remove any documents in the submission from the archive binder. This does not delete the documents from Vault, but does mean that they no longer appear in the Viewer tab and users will not be able to access them using cross-document navigation. You must re-import the submission to make it available.

DELETE`/api/{version}/vobjects/submission__v/{submission_id}/actions/import`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{submission_id}` | The `id` field value of the `submission__v` object record. To get this value, [use VQL to retrieve all records](/regulatory/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) on the `submission__v` object. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/submission__v/00S000000000101/actions/import
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "job_id": 15002,
  "url": "/api/v26.2/services/jobs/15002"
}
```
