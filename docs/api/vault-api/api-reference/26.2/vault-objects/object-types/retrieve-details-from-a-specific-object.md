<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-types/retrieve-details-from-a-specific-object/ -->
<!-- title: Retrieve Details from a Specific Object -->

# Retrieve Details from a Specific Object

Retrieve all object types and object type fields configured on a given object.

GET`/api/{version}/configuration/{object_name_and_object_type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name_and_object_type}` | The object name followed by the object type in the format `Objecttype.{object_name}.{object_type}`. For example, `Objecttype.product__v.base__v`. |

## Query Parameters

| Name | Description |
| --- | --- |
| `loc` | When localized (translated) strings are available, retrieve them by setting `loc` to `true`. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/configuration/Objecttype.bicycle__c.road_bike__c?loc=true
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "data": {
       "localized_data": {
           "label_plural": {
               "en": "Road Bikes",
               "fr": "Vélos de route",
               "es": "Bicicletas de carretera"
           },
           "label": {
               "en": "Road Bike",
               "fr": "Vélo de route",
               "es": "Bicicleta de carretera"
           }
       },
       "name": "road_bike__c",
       "object": "bicycle__c",
       "active": true,
       "description": "This object type is intended for model numbers 400-650. For model numbers 650-900, use the Hybrid Bike object type.",
       "additional_type_validations": [],
       "label_plural": "Road Bikes",
       "type_fields": [
           {
               "required": false,
               "name": "id",
               "source": "standard"
           },
           {
               "required": false,
               "name": "object_type__v",
               "source": "standard"
           },
           {
               "required": false,
               "name": "global_id__sys",
               "source": "system"
           },
           {
               "required": false,
               "name": "link__sys",
               "source": "system"
           },
           {
               "required": true,
               "name": "name__v",
               "source": "standard"
           },
           {
               "required": true,
               "name": "status__v",
               "source": "standard"
           },
           {
               "required": false,
               "name": "created_by__v",
               "source": "standard"
           },
           {
               "required": false,
               "name": "created_date__v",
               "source": "standard"
           },
           {
               "required": false,
               "name": "modified_by__v",
               "source": "standard"
           },
           {
               "required": false,
               "name": "modified_date__v",
               "source": "standard"
           }
       ],
       "label": "Road Bike"
   }
}
```

## Response Details

The response lists all object types and all fields configured on each object type for the specific object.
