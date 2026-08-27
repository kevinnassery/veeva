<!-- source: https://general.veevavault.dev/vql/query-targets/vault-component-definitions/ -->
<!-- title: Vault Component Definitions -->

# Vault Component Definitions

In v25.1+, Vault Admins can use the [Component Definition Query API](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records) to retrieve and filter the MDL definitions (`mdl_definition__v`) and JSON definitions (`json_definition__v`) of Vault components. Use a VQL query on the following query targets:

* `vault_component__v`: Retrieve MDL and JSON component definitions from Vault component records.
* `vault_package_component__v`: Retrieve MDL and JSON definitions of inbound package component steps from inbound package components. This allows you to see the changes that were executed as part of a package.

## Queryable Fields

The [Component Definition Query API](/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-component-records) allows you to query the following fields on `vault_component__v` and `vault_package_component__v`:

| Name | Description |
| --- | --- |
| `json_definition__v` | The full JSON definition for the specified component. |
| `mdl_definition__v` | The full MDL definition for the specified component. This field value is N/A for code components such as Recordtrigger. |

Use the [Retrieve Object Metadata API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata) to get other queryable fields for `vault_component__v` and `vault_package_component__v`.

Note

The response does not truncate the values of `json_definition__v` and `mdl_definition__v`, so the `LONGTEXT()` function is not required to retrieve their full values.

## Query Examples

The following are examples of component definition queries.

### Query: Retrieve Definitions for a Specific Component Type (JSON)

The following example retrieves the JSON definition for all Reporttype component records:

Copy to clipboard

```
SELECT json_definition__v
FROM vault_component__v
WHERE component_type__v = 'Reporttype'
```

#### Response: Retrieve Definitions for a Specific Component Type (JSON)

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 2,
        "total": 2
    },
    "data": [
        {
            "json_definition__v": "{\"name\":\"binder_with_document__v\",\"label\":\"Binder with Document\",\"active\":true,\"primary_object\":\"binder\",\"class\":\"Standard\",\"configuration\":\"<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\\r\\n<vrt:reportType xmlns:vrt=\\\"VaultReporttype\\\">\\r\\n  <vrt:downRelationships>\\r\\n    <vrt:downRelationship key=\\\"documents\\\" />\\r\\n  </vrt:downRelationships>\\r\\n</vrt:reportType>\\r\\n\"}"
        },
        {
            "json_definition__v": "{\"name\":\"product_with_document__c\",\"label\":\"Product with Document\",\"active\":true,\"description\":\"Product with Product (Document)\",\"primary_object\":\"product__v\",\"class\":\"Standard\",\"configuration\":\"<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\\r\\n<vrt:reportType xmlns:vrt=\\\"VaultReporttype\\\">\\r\\n  <vrt:downRelationships>\\r\\n    <vrt:downRelationship key=\\\"documents.product__v\\\" />\\r\\n  </vrt:downRelationships>\\r\\n</vrt:reportType>\\r\\n\"}"
        }
    ]
}
```

### Query: Retrieve Inbound Package Component Step Definitions (MDL)

The following example retrieves the MDL definition for configuration migration package steps:

Copy to clipboard

```
SELECT mdl_definition__v, vault_package_step__v
FROM vault_package_component__v
```

#### Response: Retrieve Inbound Package Component Step Definitions (MDL)

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 2,
        "total": 2
    },
    "data": [
        {
            "mdl_definition__v": "RECREATE Tab vault_help_content__c (\n   label('Vault Help Content'),\n   order(600),\n   parent()\n);",
            "vault_package_step__v": "0IS000000000615"
        },
        {
            "mdl_definition__v": "RECREATE Notificationtemplate baseinreview__c (\n   label('BASE-inReview'),\n   active(true),\n   description(),\n   referenced_component(),\n   subject('Notification: \"${docNameNoLink}\" is in review'),\n   notification('<b>${docName}</b> is currently in Review.  You will receive an update on the outcome of the review process.\n'),\n   email_body('<p>${notificationMessage}</p>\n\n<p>You can see all of your Notifications on your Vault home page under <a href=\"${notificationHome}\">Notifications</a>.</p>\n'),\n   entity_type('document')\n);",
            "vault_package_step__v": "0IS000000000701"
        }
    ]
}
```
