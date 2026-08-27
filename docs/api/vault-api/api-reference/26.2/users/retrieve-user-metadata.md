<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/retrieve-user-metadata/ -->
<!-- title: Retrieve User Metadata -->

# Retrieve User Metadata

Note

This endpoint retrieves user metadata at the domain level. Beginning in v18.1, Admins create and manage users with `user__sys` object records. We strongly recommend using the [Retrieve Object Metadata](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata) endpoint to retrieve `user__sys` metadata.

GET`/api/{version}/metadata/objects/users`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/users
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "properties": [
    {
      "name": "user_name__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "user_first_name__v",
      "type": "String",
      "length": 100,
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "user_last_name__v",
      "type": "String",
      "length": 100,
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "alias__v",
      "type": "String",
      "length": 40,
      "editable": true,
      "queryable": false,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "user_email__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "user_timezone__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true,
      "values": [
        {
          "value": "Pacific/Niue",
          "label": "(GMT-11:00) Niue Time (Pacific/Niue)"
        },
        {
          "value": "Pacific/Pago_Pago",
          "label": "(GMT-11:00) Samoa Standard Time (Pacific/Pago_Pago)"
        },
      ]
    },
    {
      "name": "user_locale__v",
      "type": "String",
      "length": 10,
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true,
      "values": [
        {
          "value": "pt_BR",
          "label": "Brazil"
        },
        {
          "value": "es_ES",
          "label": "Spain"
        },
      ]
    },
    {
      "name": "user_title__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "office_phone__v",
      "type": "String",
      "length": 20,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "fax__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "mobile_phone__v",
      "type": "String",
      "length": 20,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "site__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "is_domain_admin__v",
      "type": "Boolean",
      "length": 1,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "active__v",
      "type": "Boolean",
      "length": 1,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "domain_active__v",
      "type": "Boolean",
      "length": 1,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "security_policy_id__v",
      "type": "ObjectReference",
      "length": 20,
      "object": "securitypolicies",
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "user_needs_to_change_password__v",
      "type": "Boolean",
      "length": 1,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "id",
      "type": "id",
      "length": 20,
      "object": "users",
      "editable": false,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "created_date__v",
      "type": "Calendar",
      "length": 0,
      "editable": false,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "created_by__v",
      "type": "ObjectReference",
      "length": 20,
      "object": "users",
      "editable": false,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "modified_date__v",
      "type": "Calendar",
      "length": 0,
      "editable": false,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "modified_by__v",
      "type": "ObjectReference",
      "length": 20,
      "object": "users",
      "editable": false,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "domain_id__v",
      "type": "ObjectReference",
      "length": 20,
      "object": "domains",
      "editable": false,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "vault_id__v",
      "type": "ObjectReference",
      "length": 20,
      "object": "vaults",
      "editable": false,
      "queryable": true,
      "required": true,
      "multivalue": true,
      "onCreateEditable": false
    },
    {
      "name": "federated_id__v",
      "type": "String",
      "length": 100,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "salesforce_user_name__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "last_login__v",
      "type": "Calendar",
      "length": 0,
      "editable": false,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "medidata_uuid__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "user_language__v",
      "type": "String",
      "length": 10,
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true,
      "values": [
        {
          "value": "en",
          "label": "English"
        },
        {
          "value": "ja",
          "label": "Japanese"
        },
      ]
    },
    {
      "name": "company__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "group_id__v",
      "type": "ObjectReference",
      "length": 20,
      "object": "groups",
      "editable": false,
      "queryable": false,
      "required": false,
      "multivalue": true,
      "onCreateEditable": false
    },
    {
      "name": "security_profile__v",
      "type": "ObjectReference",
      "length": 40,
      "object": "Securityprofile",
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true,
      "values": [
        {
          "value": "business_admin__v",
          "label": "Business Administrator"
        },
        {
          "value": "document_user__v",
          "label": "Document User"
        },
        {
          "value": "external_user__v",
          "label": "External User"
        },
        {
          "value": "read_only_user__v",
          "label": "Read-Only User"
        },
        {
          "value": "system_admin__v",
          "label": "System Administrator"
        },
        {
          "value": "vault_owner__v",
          "label": "Vault Owner"
        },
        {
          "value": "view_based_user__v",
          "label": "View-Based User"
        }
      ]
    },
    {
      "name": "license_type__v",
      "type": "Picklist",
      "length": 40,
      "picklist": "license_type__v",
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    }
  ]
}
```

## Response Details

This response includes a full list of fields for users. Some field `values` are abridged to shorten this example response.
