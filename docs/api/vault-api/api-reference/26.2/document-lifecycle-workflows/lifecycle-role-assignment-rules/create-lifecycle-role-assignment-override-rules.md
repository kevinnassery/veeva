<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/lifecycle-role-assignment-rules/create-lifecycle-role-assignment-override-rules/ -->
<!-- title: Create Lifecycle Role Assignment Override Rules -->

# Create Lifecycle Role Assignment Override Rules

POST`/api/{version}/configuration/role_assignment_rule`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` or `text/csv` |

## Body Parameters

Before submitting this request, prepare a JSON or CSV input file with the following information:

| Name | Description |
| --- | --- |
| `name__v` required | The `name__v` field values of the lifecycle and role to which the override rule is being added. |
| `name__v` optional | The `name__v` field values of the allowed and default groups who will be assigned to the role when the override condition is met. |
| `id` optional | The `id` or `name__v` field values of the object records which define the override condition. |
| `user_name__v` optional | The `user_name__v` field values of the allowed and default users who will be assigned to the role when the override condition is met. |

Note the following scope and limitations:

* This request can only be used to specify the override rules (conditions, users, and groups). It cannot be used to create default rules.
* The input may include override rules for multiple lifecycles and roles.
* Each role may be configured with multiple override rules.

#### Example CSV & JSON Input Files

Create an override rule on the `editor__c` role of the `general_lifecycle__c` with the following override conditions, users, and groups:

| `lifecycle__v` | `role__v` | `product__v.name__v` | `country__v.name__v` | `allowed_users__v` | `allowed_groups__v` | `allowed_default_users__v` | `allowed_default_groups__v` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `general_lifecycle__c` | `editor__c` | CholeCap | United States | "[etta@veevapharm.com](mailto:etta@veevapharm.com),[finn@veevapharm.com](mailto:finn@veevapharm.com),[greg@veevapharm.com](mailto:greg@veevapharm.com),[hope@veevapharm.com](mailto:hope@veevapharm.com)" | "`cholecap_us_docs_group__c`,`cholecap_us_research_group__c`,`cholecap_us_compliance_group__c`,`cholecap_us_product_management_group__c`" | [etta@veevapharm.com](mailto:etta@veevapharm.com) | `cholecap_us_docs_group__c` |

#### Request Details

In this example:

* The input file format is set to JSON.
* The response format is not set and will default to JSON.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
--data-raw '[
{
    "lifecycle__v": "general_lifecycle__c",
    "role__v": "editor__c",
    "product__v.name__v": "CholeCap",
    "country__v.name__v": "United States",
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
]' \
https://myvault.veevavault.com/api/v26.2/configuration/role_assignment_rule
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS"
        }
    ]
}
```

## Response Details

For each override rule specified in the input, the response includes a `SUCCESS` or `FAILURE` message.
