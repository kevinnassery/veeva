<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/update-documents/update-document-version/ -->
<!-- title: Update Document Version -->

# Update Document Version

Update editable field values on a specific version of a document. See also [Update Single Document](/vault-api/api-reference/26.2/documents/update-documents/update-single-document).

PUT`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |
| `X-VaultAPI-MigrationMode` | When set to `true`, Vault allows you to manually set the document number. Vault does not send notifications in Document Migration Mode. All other Document Migration Mode overrides available at document creation are ignored, but do not generate an error message. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |
| `X-VaultAPI-NoTriggers` | If set to `true` and [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) is enabled, it bypasses all system, standard, and custom doctype triggers. |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{major_version}` | The document `major_version_number__v` field value. |
| `{minor_version}` | The document `minor_version_number__v` field value. |

## Body Parameters

In the body of the request, add any editable field values that you wish to update as name-value pairs. To remove existing field values, include the field name and set its value to null.

To find your Vault’s editable document fields, [Retrieve All Document Fields](/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-all-document-fields) configured on documents. Editable fields will have `editable:true`.

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "language__v=English" \
-d "product__v=1357662840171" \
-d "audience__c=consumer__c" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/versions/2/0
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "id": 534
}
```

## Response Details

On `SUCCESS`, Vault updates field values for the specified version of the document and returns the ID of the updated document.
