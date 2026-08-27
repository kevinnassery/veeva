<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/update-documents/update-single-document/ -->
<!-- title: Update Single Document -->

# Update Single Document

Note

If you need to update more than one document, it is best practice to use the [bulk API](/vault-api/api-reference/26.2/documents/update-documents/update-multiple-documents).

Update editable field values on the latest version of a single document. To update past document versions, see [Update Document Version](/vault-api/api-reference/26.2/documents/update-documents/update-document-version). Note that this endpoint does not allow you to update the `archive__v` field. To archive a document, or to update multiple documents at once, see [Update Multiple Documents](/vault-api/api-reference/26.2/documents/update-documents/update-multiple-documents).

PUT`/api/{version}/objects/documents/{doc_id}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |
| `X-VaultAPI-MigrationMode` | When set to `true`, Vault allows you to change the document number. Vault does not send notifications in Document Migration Mode. All other Document Migration Mode overrides available at document creation are ignored, but do not generate an error message. You must have the *Document Migration* permission to use this header. Learn more about [Document Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/54028). |
| `X-VaultAPI-NoTriggers` | If set to `true` and [Document Migration Mode](https://platform.veevavault.help/en/gr/54028) is enabled, it bypasses all system, standard, and custom doctype triggers. |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Body Parameters

In the body of the request, add any editable field values that you wish to update. To find these fields, [Retrieve Document Fields](/vault-api/api-reference/26.2/documents/retrieve-document-fields/retrieve-all-document-fields) configured on documents. Editable fields will have `editable:true`. To remove existing field values, include the field name and set its value to null.

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "language__v=English" \
-d "product__v=1357662840171" \
-d "audience__vs=consumer__vs" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534
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

On `SUCCESS`, Vault updates field values for the latest version of the document and returns the ID of the updated document.
