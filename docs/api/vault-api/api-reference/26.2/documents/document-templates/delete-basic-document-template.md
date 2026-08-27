<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-templates/delete-basic-document-template/ -->
<!-- title: Delete Basic Document Template -->

# Delete Basic Document Template

Delete a basic document template from your Vault. You cannot delete controlled document templates. Learn more about [controlled template deletion in Vault Help](https://platform.veevavault.help/en/gr/46018#deleting-controlled-document-templates).

DELETE`/api/{version}/objects/documents/templates/{template_name}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{template_name}` | The document template `name__v` field value. |

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/templates/promo_ad_web_document_template__c
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```
