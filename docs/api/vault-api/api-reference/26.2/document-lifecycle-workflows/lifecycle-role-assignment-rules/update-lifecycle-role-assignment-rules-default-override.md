<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/lifecycle-role-assignment-rules/update-lifecycle-role-assignment-rules-default-override/ -->
<!-- title: Update Lifecycle Role Assignment Rules (Default & Override) -->

# Update Lifecycle Role Assignment Rules (Default & Override)

Before submitting this request, prepare a JSON or CSV input file. See the [Create Lifecycle Role Assignment Override Rules](/vault-api/api-reference/26.2/document-lifecycle-workflows/lifecycle-role-assignment-rules/create-lifecycle-role-assignment-override-rules) request for details.

PUT`/api/{version}/configuration/role_assignment_rule`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` or `text/csv` |

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
--data-raw '[
{
    "lifecycle__v": "general_lifecycle__c",
    "role__v": "editor__c",
    "product__v.name__v": "CholeCap",
    "country__v.name__v": "United States",
    "allowed_users__v": [
        "etta@veepharm.com",
        "finn@veepharm.com"
    ]
}
]' \
https://myvault.veevavault.com/api/v26.2/configuration/role_assignment_rule
```

## Response Details

For each default or override rule specified in the input, the response includes a `SUCCESS` or `FAILURE` message.
