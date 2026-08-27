<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-page-layouts/retrieve-page-layouts/ -->
<!-- title: Retrieve Page Layouts -->

# Retrieve Page Layouts

Given an object, retrieve all page layouts associated with that object. You can use this data to [retrieve specific page layout metadata](/vault-api/api-reference/26.2/vault-objects/object-page-layouts/retrieve-page-layout-metadata).

GET`/api/{version}/metadata/vobjects/{object_name}/page_layouts`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The `name` of the object from which to retrieve page layouts. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/vobjects/product__v/page_layouts
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": [
       {
           "name": "product_detail_page_layout__c",
           "label": "Product Detail Page Layout",
           "object_type": "base__v",
           "url": "/api/v26.2/metadata/vobjects/product__v/page_layouts/product_detail_page_layout__c",
           "active": true,
           "description": "General layout for any product",
           "default_layout": true,
           "display_lifecycle_stages": false
       },
       {
           "name": "otc_product_layout__c",
           "label": "OTC Product Layout",
           "object_type": "base__v",
           "url": "/api/v26.2/metadata/vobjects/product__v/page_layouts/otc_product_layout__c",
           "active": true,
           "description": "New layout for OTC products",
           "default_layout": false,
           "display_lifecycle_stages": false
       },
       {
           "name": "generic_product_layout__c",
           "label": "Generic Product Layout",
           "object_type": "base__v",
           "url": "/api/v26.2/metadata/vobjects/product__v/page_layouts/generic_product_layout__c",
           "active": true,
           "description": "Layout for generics",
           "default_layout": false,
           "display_lifecycle_stages": false
       }
   ]
}
```

## Response Details

On `SUCCESS`, the response lists all layouts associated with the specified object. Each layout includes:

| Name | Description |
| --- | --- |
| `name` | The name of the layout. |
| `label` | The label of the layout as it appears in the Vault UI. |
| `object_type` | The object type where the layout is available. |
| `active` | The active or inactive status of the layout. |
| `description` | A description of the layout. |
| `default_layout` | If `true`, this layout is assigned to all users unless another layout is specified in their assigned Layout Profile. |
| `display_lifecycle_stages` | For objects with lifecycle stages configured, if `true`, Vault displays the Lifecycle Stages Chevron panel on all views for the object. |
