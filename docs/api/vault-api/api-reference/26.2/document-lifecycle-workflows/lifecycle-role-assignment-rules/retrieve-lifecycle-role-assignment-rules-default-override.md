<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/lifecycle-role-assignment-rules/retrieve-lifecycle-role-assignment-rules-default-override/ -->
<!-- title: Retrieve Lifecycle Role Assignment Rules (Default & Override) -->

# Retrieve Lifecycle Role Assignment Rules (Default & Override)

GET`/api/{version}/configuration/role_assignment_rule`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` or CSV `text/csv` |

This endpoint alone will retrieve a list of all lifecycle role assignment rules (default & override) from all roles in all lifecycles in your Vault.

To filter the results by lifecycle or role, add one or both of the following parameters to the request endpoint:

## Query Parameters

| Name | Description |
| --- | --- |
| `lifecycle__v` | Include the name of the lifecycle from which to retrieve information. For example: `lifecycle_v=general_lifecycle__c` |
| `role__v` | Include the name of the role from which to retrieve information. For example: `role__v=editor__c` |
| `product__v` | Include the ID/name of a specific product to see product-based override rules to default users/allowed users for the lifecycle role. For example: `product__v=0PR0011001` or `product__v.name__v=CholeCap` |
| `country__v` | Include the ID/name of a specific country to see country-based override rules to default users/allowed users for the lifecycle role. For example: `country__v=0CR0022002` or `country__v.name__v=United States` |
| `study__v` | In eTMF Vaults only. Include the ID/name of a specific study to see study-based override rules to default users/allowed users for the lifecycle role. For example: `study__v=0ST0021J01` or `study__v.name__v=CholeCap Study` |
| `study_country__v` | In eTMF Vaults only. Include the ID/name of a specific study country to see study country-based override rules to default users/allowed users for the lifecycle role. For example: `study_country__v=0SC0001001` or `study_country__v.name__v=Germany` |

The response will include:

* The default role assignments
* The override role assignments when an override condition (when configured on the role) is met
* The override conditions (when configured on the role)

If you filter the results by one or more override conditions (`product__v` or `country__v`), the response will exclude the default role assignments and role assignments for the override conditions.

#### Request Details

Retrieve lifecycle role assignment rules from a specific role (`editor__c`) in a specific lifecycle (`general_lifecycle__c`):

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/configuration/role_assignment_rule?lifecycle__v=general_lifecycle__c&role__v=editor__c
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "lifecycle__v": "general_lifecycle__c",
            "role__v": "editor__c",
            "allowed_users__v": [
                "ally@veepharm.com",
                "beth@veepharm.com",
                "cruz@veepharm.com",
                "dave@veepharm.com"
            ],
            "allowed_groups__v": [
                "global_products_team__c",
                "vault_products_team__c",
                "vault_doc_management__c"
            ],
            "allowed_default_users__v": [
                "ally@veepharm.com"
            ],
            "allowed_default_groups__v": [
                "global_products_team__c"
            ]
        },
        {
            "lifecycle__v": "general_lifecycle__c",
            "role__v": "editor__c",
            "product__v.name__v": "CholeCap",
            "country__v.name__v": "United States",
            "product__v": "0PR0011001",
            "country__v": "0CR0022002",
            "allowed_users__v": [
                "etta@veepharm.com",
                "finn@veepharm.com",
                "greg@veepharm.com",
                "hope@veepharm.com"
            ],
            "allowed_groups__v": [
                "cholecap_us_docs_group__c",
                "cholecap_us_research_group__c",
                "cholecap_us_compliance_group__c",
                "cholecap_us_product_management_group__c"
            ],
            "allowed_default_users__v": [
                "etta@veepharm.com"
            ],
            "allowed_default_groups__v": [
                "cholecap_us_docs_group__c"
            ]
        }
    ]
}
```

## Response Details

In this example response, the `editor__c` role in the `general_lifecycle__c` lifecycle is configured with the following role assignment rules:

**Default Rule**

When a document is assigned this lifecycle, the following users and groups are automatically assigned to the `editor__c` role:

* `allowed_default_users__v` - The user `ally@veepharm.com` is automatically assigned to the role.
* `allowed_users__v` - The users `beth@veepharm.com`, `cruz@veepharm.com`, and `dave@veepharm.com` can be (optionally) assigned to the role at any time during the lifecycle.
* `allowed_default_groups__v` - The group `global_products_team__c` is automatically assigned to the role.
* `allowed_groups__v` - The groups `vault_products_team__c` and `vault_doc_management__c` can be (optionally) assigned to the role at any time during the lifecycle.

**Override Conditions**

This lifecycle role has been configured with two override conditions which state: If both the product "CholeCap" and country "United States" are assigned to a document, do not apply the default rule, but instead apply the override rule.

The API returns both the system-managed object record `id` and the user-defined object record `name__v` (via the `object__v.name__v` lookup) field values which define the override conditions:

* `"product__v.name__v": "CholeCap"` - The product object record name.
* `"country__v.name__v": "United States"` - The country object record name.
* `"product__v": "0PR0011001"` - The product object record ID.
* `"country__v": "0CR0022002"` - The country object record ID.

**Override Rule**

When both the product "CholeCap" and country "United States" are assigned (at any time) to a document in this lifecycle, the following (alternate) users and groups are automatically assigned to the `editor__c` role:

* `allowed_default_users__v` - The user `etta@veepharm.com` is automatically assigned to the role.
* `allowed_users__v` - The users `finn@veepharm.com`, `greg@veepharm.com`, and `hope@veepharm.com` can be (optionally) assigned to the role during its lifecycle.
* `allowed_default_groups__v` - The group `cholecap_us_docs_group__c` is automatically assigned to the role.
* `allowed_groups__v` - The groups `cholecap_us_research_group__c`, `cholecap_us_compliance_group__c`, and `cholecap_us_product_management_group__c` can be (optionally) assigned to the role during its lifecycle.

Note: If the lifecycle role has not been configured with an override rule, the response will only display the default rule.
