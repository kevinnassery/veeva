<!-- source: https://general.veevavault.dev/vql/query-targets/vault-objects/ -->
<!-- title: Vault Objects -->

# Vault Objects

To retrieve all objects in your Vault, use the [Retrieve Object Collection API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-collection). To retrieve metadata for a specific object and its fields, use the [Retrieve Object Metadata API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata).

This section outlines the various types of Vault objects.

To retrieve all records for a specific object, you can use VQL. See this and other use-case examples in [Vault Object Query Examples](#Vault_Object_Query_Examples).

## Custom Vault Objects

All custom Vault objects and object fields are queryable.

The names of these objects always end in `__c`. For example, to query Custom Object, enter `custom_object__c`.

## Standard Vault Objects

All standard Vault objects and object fields are queryable. The available standard objects vary by application, such as PromoMats or Submissions.

The names of these objects always end in `__v`. For example, to query the Product object, use `product__v`.

## Vault System Objects

Vault system objects include `user__sys`, `rendition_type__sys`, `group__sys`, and others. These are available for all Vault applications and configurations.

The names of these objects always end in `__sys`. For example, to query Groups, use `group__sys`.

The following system objects are versioned:

* `user__sys`: Available in v18.1+
* `binders`: Available in v18.2+
* `group__sys`: Available in v18.3+
* `doc_role__sys`: Available in v21.1+
* Document workflows (formerly multi-document workflow): Available in v21.2+

## Vault Object Types

You can use the `object_type__v` object to query Vault object types.

Use the [Retrieve Object Metadata API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata) to get the `object_type__v` queryable fields and object relationships.

## Vault Object Query Examples

The following are examples of Vault object and object type queries.

### Query: Retrieve Active Object Records

The following query retrieves the ID and name of all active *Product* records:

Copy to clipboard

```
SELECT id, name__v
FROM product__v
WHERE status__v = 'active__v'
```

#### Response: Retrieve Active Object Records

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 29,
       "total": 29
   },
   "data": [
       {
           "id": "00P000000000301",
           "name__v": "Nyaxa"
       },
       {
           "id": "00P000000000302",
           "name__v": "Focusin"
       },
       {
           "id": "00P000000000303",
           "name__v": "Lexipalene"
       }
   ]
}
```

### Query: Retrieve All Object Types

The following query retrieves the ID, API name, and object name of all object types:

Copy to clipboard

```
SELECT id, api_name__v, object_name__v
FROM object_type__v
```

#### Response: Retrieve All Object Types

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 173,
        "total": 173
    },
    "data": [
        {
            "id": "OOT000000000101",
            "api_name__v": "base__v",
            "object_name__v": "product__v"
        },
        {
            "id": "OOT000000000102",
            "api_name__v": "base__v",
            "object_name__v": "application_role__v"
        },
        {
            "id": "OOT000000000103",
            "api_name__v": "base__v",
            "object_name__v": "doc_type_group__v"
        }
    ]
}
```
