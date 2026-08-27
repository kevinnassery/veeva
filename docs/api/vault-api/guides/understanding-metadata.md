<!-- source: https://general.veevavault.dev/vault-api/guides/understanding-metadata/ -->
<!-- title: Understanding Document & Object Field Metadata -->

# Understanding Document & Object Field Metadata

This guide explains how document and object fields work and how to use them when making API calls. We’ll also take a close look at some example fields and explain the semantics of their metadata attributes.

## Vault Documents & Vault Objects

In Vault, “document” refers to both the files (source file, renditions, etc.) and the set of fields. An “object” is a kind of data entity, which also has a set of fields. Individual “object records” are instances of that data entity type with values assigned to the various fields. If you think of an object as a database table, each field is a column and each object record is a table row.

Learn more about [Vault objects and documents](https://platform.veevavault.help/en/gr/22904).

## Document & Object Fields

When creating a document or an object record, there are some fields that you must specify and others that Vault itself populates. For example, you must specify a value for the Name field (`name__v`), but Vault itself generates a value for the `id` field. There are also fields that are editable and not required: you can create documents or object records without populating these.

Fields like `id` are known as “system-managed” fields and are often hidden in the UI. The `id` field is particularly important when using Vault API because you’ll use it to identify documents, object records, and other resources.

You can use Vault API to find all available fields on objects, for example:

* [Retrieve Document](/vault-api/api-reference/26.2/documents/retrieve-documents/retrieve-document)
* [Retrieve Object Records](/vault-api/api-reference/26.2/vault-objects/retrieve-object-records)
* [Retrieve Users](/vault-api/api-reference/26.2/users/retrieve-all-users)

These APIs will return blank values, but not null values. For example, when retrieving users, you may notice the last login field: `"last_login__v": "2015-02-02T16:52:21.000Z"`. However, if a user never logged in, this field would be null and would not show up in the response at all. Fields with blank values, for example `"office_phone__v": ""`, do appear in the response, showing the user has entered nothing for their office phone number.

When creating documents or object records through Vault API, the same field requirements and validation rules apply as when working through the UI.

### Configuration Differences & Field Naming

Many elements (objects, fields, rendition types, etc.) of a given Vault are unique to that Vault's configuration, meaning that the set of elements can be different between Vaults. Some standard elements, like the `name__v` and `id` fields, are common across all Vaults.

In addition to the label that users see in the Vault UI, each element has a name, sometimes known as the API name, that developers use to refer to it in API requests. For example, the *Product* object has a label value of `Product` and a name value of `product__v`.

The namespace suffix on an element name indicates whether it’s standard or custom:

* `__sys` is a system element and is available for all Vault applications and configurations. For example, `user__sys`.
* `__v` is a standard element. Some standard element have application-specific suffixes, for example `__rim`.
* `__c` is a custom element or a sample element delivered with the application. On older Vaults, some custom element have the `__vs` suffix.

### Object Prefixes

Each object is configured with a three-character prefix. When creating object records, Vault uses this prefix as the first three digits of the object record ID.

The following are examples of object labels, names, prefixes, and record IDs:

| Label | Name | Prefix | Record ID |
| --- | --- | --- | --- |
| Product | `product__v` | 00P | 00P000000007001 |
| Expenses | `expenses__c` | V3Y | V3Y000000001001 |

### Rich Text fields on Objects

As of v21.1, Rich Text fields are special text fields that allow users to apply common formatting options such as bold and italic. Rich Text fields support up to 32,000 plaintext characters, with an additional 32,000 characters reserved for HTML markup. For example, `<b>Hello</b>` is 5 plaintext characters and 7 HTML markup characters.

You can also [convert an existing long text field to a rich text field with MDL](/mdl/documentation/mdl-commands/alter#Multi_Value).

#### Supported HTML

Vault does not support all HTML tags and attributes. In the Vault UI, users can only enter HTML markup through the buttons in the Rich Text Editor. Manually entered HTML in the Vault UI is not supported. When entering values for Rich Text fields in Vault API, the Rich Text Editor is not available, so manual HTML is supported.

In addition to HTML, Vault supports all Unicode characters which can be stored with UTF-8 encoding.

[Download Supported HTML for Rich Text](https://platform.veevavault.help/assets/downloads/VeevaVaultRichTextSupportedHTML.zip)

#### Unsupported HTML

When adding or editing a Rich Text field from Vault API, Vault stores the value exactly as entered by the user. HTML validation occurs on read in the Vault UI. Reading a Rich Text value with Vault API or VQL will return the unvalidated value as entered by the user.

On read in the Vault UI, validation occurs as follows:

* Unsupported HTML tags (other than `<body>` and `<head>`) are treated as plain text. For example:
  + `<Purchase_Order>12345</Purchase_Order>` displays as plain text
  + `<strong>12345</strong>` displays as plain text
  + Do not include `<body>` or `<head>` tags. These are [treated differently](#Body_Head_Tags) than other unsupported HTML.
* Unsupported HTML properties or attributes are removed. For example:
  + `<p style="font-family:cursive">Cursive</p>` displays as `Cursive`, in a paragraph with no other styling
  + `<p title="Purchase Order">Purchase Order</p>` renders as `Purchase Order`, in a paragraph with no other styling
  + `<p purchaseOrderId="1234">Purchase Order</p>` renders as `Purchase Order`, in a paragraph with no other styling

#### Body & Head Tags

As a best practice, do not include `<body>` or `<head>` tags in Rich Text fields.

Every Rich Text value is implicitly within a `<body>` tag, even though you do not see this `<body>` tag when retrieving a Rich Text value. If an additional `<body>` tag is manually entered into a Rich Text field value, Vault will render the contents within this tag only, ignoring any other text in the field.

If included, the `<head>` tag and any information within it will be removed when rendering Rich Text fields.

## Metadata API

When using the APIs to create documents, query objects, etc., fields often serve as API parameters. Depending on the API, you may need to know the `name` of a field and if it’s queryable, editable, and/or required. All of this can be determined using the metadata APIs.

Metadata APIs define the shape of the fields on different document types, objects, or other resources. Below we’ll look at some key metadata properties to understand how Vault defines fields.

## Document Metadata API

Let’s make an API call to get the fields defined on our documents.

### Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://{server}/api/{version}/metadata/objects/documents/properties
```

### Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "properties": [
    {
      "name": "id",
      "type": "id",
      "required": true,
      "maxLength": 20,
      "minValue": 0,
      "maxValue": 9223372036854775807,
      "repeating": false,
      "systemAttribute": true,
      "editable": false,
      "setOnCreateOnly": true,
      "disabled": false,
      "hidden": true,
      "queryable": true
    },
    {
      "name": "version_id",
      "scope": "DocumentVersion",
      "type": "id",
      "required": true,
      "maxLength": 20,
      "minValue": 0,
      "maxValue": 9223372036854775807,
      "repeating": false,
      "systemAttribute": true,
      "editable": false,
      "setOnCreateOnly": true,
      "disabled": false,
      "hidden": true,
      "queryable": true
    }
  ]
}
```

The API call above returns the entire list of fields defined on documents, across all document types. Each field itself has a list of metadata attributes that define its behavior and shape. The example shows only a short excerpt. A real response might include hundreds of fields.

## Metadata of Document Fields

We’ll look at a few document fields to understand what the various metadata attributes mean.

### id

The `id` is a special document field that Vault automatically assigns to uniquely identify each document.

Copy to clipboard

```
{
      "name": "id",
      "type": "id",
      "required": true,
      "maxLength": 20,
      "minValue": 0,
      "maxValue": 9223372036854775807,
      "repeating": false,
      "systemAttribute": true,
      "editable": false,
      "setOnCreateOnly": true,
      "disabled": false,
      "hidden": true,
      "queryable": true
 }
```

* `name` specifies the name to use as the parameter name for a given API. For instance, to update a set of documents you need to specify the document ids to update under the `id` parameter of the document update API.
* `required` means that a value is always assigned for this attribute
* `minValue` and `maxValue` indicate that it’s a numeric field, although it uses a special `id` type rather than `number`
* `systemAttribute` indicates that Vault controls this field and the field values; this means that you don’t need to set the value when creating a document
* `setOnCreateOnly` indicates that the value can only be set during document creation
* `editable:false` indicates that you cannot modify the value
* `queryable` shows that the field is usable in VQL queries

### Name

Copy to clipboard

```
{
      "name": "name__v",
      "scope": "DocumentVersion",
      "type": "String",
      "required": true,
      "maxLength": 100,
      "repeating": false,
      "systemAttribute": true,
      "editable": true,
      "setOnCreateOnly": false,
      "disabled": false,
      "label": "Name",
      "section": "generalProperties",
      "sectionPosition": 0,
      "hidden": false,
      "queryable": true,
      "shared": false,
      "helpContent": "Displayed throughout application for the document, including in Library, Reporting, Notifications and Workflows.",
      "definedInType": "type",
      "definedIn": "base_document__v"
}
```

Although it doesn't need to be unique like `id`, `name__v` must also be populated for every document (`required:true`). This metadata attribute has a few interesting properties that didn’t appear on `id`.

* `scope` tells us that this field can be assigned a value for each document version, for example, the name on v0.1 could be different from the name on v1.2
* `definedIn` indicates where the attribute is defined in the document type hierarchy; `base_document__v` means that the attribute applies to every document type, subtype, and classification
* `systemAttribute:true` means that this is a built-in part of Vault like `id`, but `editable:true` means that the value itself isn’t controlled by the Vault; because the attribute is both required and editable, you will have to specify values for it when creating a document.

### Product

Copy to clipboard

```
{
      "name": "product__v",
      "scope": "DocumentVersion",
      "type": "ObjectReference",
      "required": false,
      "repeating": true,
      "systemAttribute": true,
      "editable": true,
      "setOnCreateOnly": false,
      "disabled": false,
      "objectType": "product__v",
      "label": "Product",
      "section": "productInformation",
      "sectionPosition": 1,
      "hidden": false,
      "queryable": true,
      "shared": false,
      "definedInType": "type",
      "definedIn": "base_document__v",
      "relationshipType": "reference",
      "relationshipName": "document_product__vr"
}
```

Some metadata attributes reference a specific object from the same Vault. These attributes have the property `type:ObjectReference`. In this case, the `product__v` attribute references the `product__v` object. (The attribute name and the object name will not always be identical.) The values that you can assign to this attribute are the records within the *Product* object.

Object reference attributes have special properties:

* `relationshipType` will always be `reference` when the metadata attribute is on documents
* `relationshipName` is a way of identifying the relationship between the document and the object

## Object Metadata API

Let’s make some API calls to get object metadata. First, we’ll get the list of objects defined in our Vault.

### Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://{server}/api/{version}/metadata/vobjects
```

### Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "objects": [
    {
      "url": "/api/v17.1/metadata/vobjects/product__v",
      "label": "Product",
      "name": "product__v",
      "label_plural": "Products",
      "prefix": "00P",
      "order": 2,
      "in_menu": true,
      "source": "standard",
      "status": [
        "active__v"
      ]
    },
    {
      "url": "/api/v17.1/metadata/vobjects/country__v",
      "label": "Country",
      "name": "country__v",
      "label_plural": "Countries",
      "prefix": "00C",
      "order": 4,
      "in_menu": true,
      "source": "standard",
      "status": [
        "active__v"
      ]
    }
  ]
}
```

From this response, we can see that there’s a *Product* object configured. Let’s call the metadata API for this object to see its fields. For this, we add the object name `product__v` to the request.

### Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://{server}/api/{version}/metadata/vobjects/product__v
```

### Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "object": {
     "fields": [
      {
        "help_content": null,
        "editable": false,
        "lookup_relationship_name": null,
        "label": "ID",
        "source": "standard",
        "type": "ID",
        "modified_date": "2015-10-26T18:26:53.000Z",
        "created_by": 1,
        "required": false,
        "no_copy": true,
        "name": "id",
        "list_column": false,
        "modified_by": 1,
        "created_date": "2015-10-26T18:26:53.000Z",
        "lookup_source_field": null,
        "status": [
          "active__v"
        ],
        "order": 0
      },
      {
        "help_content": null,
        "editable": true,
        "lookup_relationship_name": null,
        "start_number": null,
        "label": "Product Name",
        "source": "standard",
        "type": "String",
        "modified_date": "2015-10-26T18:26:53.000Z",
        "created_by": 1,
        "required": true,
        "no_copy": false,
        "system_managed_name": false,
        "value_format": null,
        "unique": true,
        "name": "name__v",
        "list_column": true,
        "modified_by": 1,
        "created_date": "2015-10-26T18:26:53.000Z",
        "lookup_source_field": null,
        "status": [
          "active__v"
        ],
        "max_length": 128,
        "order": 1
      },
    ]
  }
}
```

## Next Steps

Now that you understand how to read metadata attributes in your response, you’re ready to check out these tutorials:

* [Creating & Downloading Documents in Bulk](/vault-api/guides/creating-documents-bulk)
