<!-- source: https://general.veevavault.dev/vql/references/vql-api-headers/ -->
<!-- title: VQL API Headers -->

# VQL API Headers

Vault API supports specific HTTP headers that provide additional metadata or record properties in the VQL query response. Use these headers to retrieve detailed information about your query structure or to access record-level data such as field permissions and additional formula field attributes.

## Query Describe

When you set the `X-VaultAPI-DescribeQuery` header to `true`, the response includes the `queryDescribe` object.
This object provides metadata on your query, such as the name and label of the query target and retrieved fields.
Learn more in the [VQL API Reference](/vault-api/api-reference/26.2/vault-query-language-vql/submitting-a-query#DescribeQuery_Header).

For example, this response provides a description of a query that uses a `SELECT` statement to retrieve the `id` and `name__v` from `documents`:

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "queryDescribe": {
        "type": "select__sys",
        "object": {
            "name": "documents",
            "label": "documents",
            "label_plural": "documents"
        },
        "fields": [
            {
                "type": "id",
                "required": true,
                "name": "id"
            },
            {
                "label": "Name",
                "type": "String",
                "required": true,
                "name": "name__v",
                "max_length": 100
            }
        ]
    },
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 3,
        "total": 3
    },
    "data": [
        {
            "id": 26,
            "name__v": "Verntorvastatin Batch Manufacturing Record"
        },
        {
            "id": 6,
            "name__v": "Cholecap-Logo"
        },
        {
            "id": 5,
            "name__v": "CholeCap Visual Aid"
        }
    ]
}
```

## Record Properties

The `X-VaultAPI-RecordProperties` header retrieves record properties for a query result and returns them in the `record_properties` object. Record properties provide additional record data that is not otherwise included in the query response:

* **Field properties**:
  + **Hidden fields**: Fields that are not visible to the user for this record. A field might not be visible on a record if it is hidden from the user by Atomic Security.
  + **Redacted fields**: Fields that are redacted for this record. A field is redacted if the querying user is System and the field contains Protected Health Information (PHI) or Personally Identifiable Information (PII). Learn more in [Vault Help](https://platform.veevavault.help/en/lr/15057#protected-info).
  + **Editable fields**: Fields that are editable for this record.
* **Record permissions**: The *Edit*, *Delete*, *Create*, and *Read* permissions for this record.
* **Weblink**: Additional attributes for formula fields that use the `Hyperlink()` function. Learn more about the [Hyperlink() function in Vault Help](https://platform.veevavault.help/en/lr/52324/#hyperlink).
* **Hidden subqueries**: Hidden subquery relationships for this record. For example, `attachments__sysr` if attachments are hidden from the user by Atomic Security.

Learn more about the `X-VaultAPI-RecordProperties` header in the [VQL API Reference](/vault-api/api-reference/26.2/vault-query-language-vql/submitting-a-query#RecordProperties_Header).

For example, the following query retrieves the `id` and `hyperlink__c` formula field for the product named Cholecap:

Copy to clipboard

```
SELECT id, hyperlink__c
FROM product__v
WHERE name__v = 'Cholecap'
```

When a request for the above query uses the `X-VaultAPI-RecordProperties=all` header, the response provides the `record_properties` object containing `field_properties`, `permissions`, and `field_additional_data`:

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 1,
        "total": 1
    },
    "data": [
        {
            "id": "cholecap",
            "hyperlink__c": "https://cholecap.com"
        }
    ],
    "record_properties": [
        {
            "id": "cholecap",
            "permissions": {
               "read": true,
               "edit": true,
               "create": true,
               "delete": true
           },
           "field_properties": {
               "hidden": [],
               "redacted": [],
               "edit": []
           },

            "subquery_properties": {},
            "field_additional_data": {
                "hyperlink__c": {
                    "web_link": {
                        "label": "Cholecap Site",
                        "target": "new_window",
                        "connection": null
                    }
                }
            }
        }
    ]
}
```

## Document Properties

The `X-VaultAPI-DocumentProperties` header retrieves document properties for a query result and returns them in the `document_properties` object. This header is only supported when querying documents or binders. Document properties provide additional document data that is not otherwise included in the query response:

* **Field properties**: The following arrays only include fields in the query's `SELECT` clause:
  + **Edit**: Fields on this document that the user can modify.
  + **Read only**: Fields on this document that the user can view but not modify.
* **Permissions**: The lifecycle state permissions for this document, evaluated based on the querying user's role and the document's current lifecycle state.
* **Subquery properties**: When both `X-VaultAPI-RecordProperties` and `X-VaultAPI-DocumentProperties` headers are included in a query containing a subquery relationship:
  + **Document references (object to document)**: When querying a Vault object with a subquery on a document reference field, the corresponding `document_properties` object is returned as a sibling to the `data` array within the subquery result object.
  + **Object references (document to object)**: When querying documents with a subquery on an object reference field, the corresponding `record_properties` object is returned as a sibling to the `data` array within the subquery result object.

Learn more about the `X-VaultAPI-DocumentProperties` header in the [VQL API Reference](/vault-api/api-reference/26.2/vault-query-language-vql/submitting-a-query#DocumentProperties_Header).

The following example demonstrates a query targeting documents that includes a document-to-object subquery (`document_product__vr`):

Copy to clipboard

```
SELECT id, name__v, approved_date__c, status__v, lifecycle__v,
  (SELECT name__v, abbreviation__c FROM document_product__vr)
FROM documents
```

When a request for the above query uses the `X-VaultAPI-DocumentProperties: all` header, the response provides the `document_properties` array at the top level of the payload. Additionally, because the query contains a subquery on an object reference field and includes the `X-VaultAPI-RecordProperties: all` header, the response includes a `record_properties` object nested within the subquery result.

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "responseDetails": {
    "total": 1,
    "pagesize": 1000,
    "pageoffset": 0,
    "size": 1
  },
  "data": [
    {
      "id": 2101,
      "document_version": "2101_0_5",
      "name__v": "Cholecap Overview",
      "approved_date__c": null,
      "status__v": "Draft",
      "lifecycle__v": "Draft to Approved Lifecycle",
      "document_product__vr": {
        "responseDetails": {
          "total": 1,
          "pagesize": 250,
          "pageoffset": 0,
          "size": 1
        },
        "data": [
          {
            "id": "00P000000000301",
            "name__v": "Cholecap",
            "abbreviation__c": "CCP"
          }
        ],
        "record_properties": {
          "product__v": [
            {
              "id": "00P000000000301",
              "permissions": {
                "read": true,
                "edit": true,
                "create": false,
                "delete": false
              },
              "field_properties": {
                "hidden": [],
                "redacted": [],
                "edit": ["name__v"]
              }
            }
          ]
        }
      }
    }
  ],
  "document_properties": [
    {
      "id": 2101,
      "document_version": "2101_0_5",
      "permissions": {
        "view_content": true,
        "edit_fields": true,
        "download_source": true,
        "version": true
      },
      "field_properties": {
        "edit": ["name__v"],
        "read-only": ["approved_date__c", "status__v", "lifecycle__v"]
      }
    }
  ]
}
```
