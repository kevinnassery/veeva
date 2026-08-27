<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-common-document-fields/ -->
<!-- title: Retrieve Common Document Fields -->

# Retrieve Common Document Fields

Retrieve all document fields and field properties which are common to (shared by) a specified set of documents. This allows you to determine which document fields are eligible for bulk update.

Learn about [Shared Fields](https://platform.veevavault.help/en/gr/4884) in Vault Help.

POST`/api/{version}/metadata/objects/documents/properties/find_common`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

| Name | Description |
| --- | --- |
| `docIds` required | Input a comma-separated list of document `id` field values. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "docIds=101,102,103" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/properties/find_common
```

## Response

Copy to clipboard

```
{
      "name": "submission_date__c",
      "scope": "DocumentVersion",
      "type": "Date",
      "required": false,
      "repeating": false,
      "systemAttribute": false,
      "editable": true,
      "setOnCreateOnly": false,
      "disabled": false,
      "label": "Submission Date",
      "section": "submissionDetails",
      "sectionPosition": 3,
      "hidden": false,
      "queryable": true,
      "shared": true,
      "usedIn": [
        {
          "key": "promotional_piece__c",
          "type": "type"
        },
        {
          "key": "compliance_package__v",
          "type": "type"
        },
        {
          "key": "claim__c",
          "type": "type"
        }
      ]
    }
    {
      "name": "withdrawal_effective_date__c",
      "scope": "DocumentVersion",
      "type": "Date",
      "required": false,
      "repeating": false,
      "systemAttribute": false,
      "editable": true,
      "setOnCreateOnly": false,
      "disabled": false,
      "label": "Withdrawal Effective Date",
      "section": "pieceDetails",
      "sectionPosition": 17,
      "hidden": false,
      "queryable": true,
      "shared": false,
      "definedInType": "type",
      "definedIn": "promotional_piece__c"
    }
```

## Response Details

The response includes all fields shared by the three documents (`docIds=101,102,103`).

Vault allows you to reuse fields across multiple document types by creating shared fields, which exist outside the context of a document type. You can create shared fields or convert existing fields into shared fields in the Vault Admin application. If a shared field is only used in one document type, you can also convert it to a non-shared field. All document fields, except for `noCopy`, include the Boolean `shared` document field. A value of `true` indicates which the field is shared and the following additional fields are included:

Note the following field metadata:

| Metadata Field | Description |
| --- | --- |
| `shared` | When true, this field is a shared field. |
| `usedIn` (`key`) | When `shared` is `true`, this lists the document types/subtypes/classifications which share the field. |
| `usedIn` (`type`) | When `shared` is `true`, this indicates if the shared field is defined at the document type, subtype, or classification level. |
| `noCopy` | When `true`, field values are not copied when using the **Make a Copy** action. |
