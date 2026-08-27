<!-- source: https://general.veevavault.dev/vql/query-targets/vault-component-objects/ -->
<!-- title: Vault Component Objects -->

# Vault Component Objects

Vault Admins can query Vault component types. Use the [Retrieve All Component Metadata API](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-all-component-metadata) for the component type to retrieve the query target from the `vobject` field. For example, the query target for Checklisttype is `checklisttype__sys`.

Not all Vault component types are available for query. The Supported Operations matrix for MDL components shows whether the component type is queryable. Individual Vault components are not queryable.

You can also query component metadata using the `vault_component__v` query target even if the component type isn’t queryable. To retrieve MDL and JSON component definitions, use the [Vault Component Definitions](/vql/query-targets/vault-component-definitions) query targets.

Use the [Retrieve Object Metadata API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata) to get the queryable fields for a Vault component type query target or for `vault_component__v`.

## Vault Component Query Examples

The following are examples of Vault component queries.

### Query: Retrieve Queryable Component Type Metadata

The following query returns the UI name and API name of components with type Accountmessage:

Copy to clipboard

```
SELECT name__v, api_name__sys
FROM accountmessage__sys
```

#### Response: Retrieve Queryable Component Type Metadata

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
     "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 4,
        "total": 4
    },
    "data": [
        {
            "name__v": "newUser",
            "api_name__sys": "new_user__v"
        },
        {
            "name__v": "newSamlUser",
            "api_name__sys": "new_saml_user__v"
        },
        {
            "name__v": "resetPassword",
            "api_name__sys": "reset_password__v"
        },
        {
            "name__v": "emailAddressChanged",
            "api_name__sys": "email_address_changed__v"
        }
    ]
}
```

### Query: Retrieve Queryable Component Type Metadata (vault\_component\_\_v)

The following query uses the `vault_component__v` query target to retrieve the label and component name of components with type Accountmessage:

Copy to clipboard

```
SELECT label__v, component_name__v
FROM vault_component__v
WHERE component_type__v = 'Accountmessage'
```

#### Response: Retrieve Queryable Component Type Metadata (vault\_component\_\_v)

This query returns the same data as the previous example query.

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 4,
        "total": 4
    },
    "data": [
        {
            "label__v": "newUser",
            "component_name__v": "new_user__v"
        },
        {
            "label__v": "newSamlUser",
            "component_name__v": "new_saml_user__v"
        },
        {
            "label__v": "resetPassword",
            "component_name__v": "reset_password__v"
        },
        {
            "label__v": "emailAddressChanged",
            "component_name__v": "email_address_changed__v"
        }
    ]
}
```

### Query: Retrieve Non-Queryable Component Type Metadata

The following query returns the label and component name of components with the non-queryable type Notificationtemplate:

Copy to clipboard

```
SELECT label__v, component_name__v
FROM vault_component__v
WHERE component_type__v = 'Notificationtemplate'
```

#### Response: Retrieve Non-Queryable Component Type Metadata

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 4,
        "total": 4
    },
    "data": [
        {
            "label__v": "BASE-Approval-Approve",
            "component_name__v": "baseapprovalapprove__c"
        },
        {
            "label__v": "BASE-Approval-CompleteApproval",
            "component_name__v": "baseapprovalcompleteapproval__c"
        },
        {
            "label__v": "BASE-approvalWorkflowStarted",
            "component_name__v": "baseapprovalworkflowstarted__c"
        },
        {
            "label__v": "BASE-approved",
            "component_name__v": "baseapproved__c"
        }
    ]
}
```
