<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/groups/retrieve-group-metadata/ -->
<!-- title: Retrieve Group Metadata -->

# Retrieve Group Metadata

GET`/api/{version}/metadata/objects/groups`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/groups
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "properties": [
    {
      "name": "id",
      "type": "id",
      "length": 20,
      "editable": false,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": false
    },
    {
      "name": "label__v",
      "type": "String",
      "length": 255,
      "editable": true,
      "queryable": true,
      "required": true,
      "multivalue": false,
      "onCreateEditable": true
    },
    {
      "name": "allow_delegation_among_members__v",
      "type": "Boolean",
      "length": 1,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
     },
    {
      "name": "group_description__v",
      "type": "String",
      "length": 200,
      "editable": true,
      "queryable": true,
      "required": false,
      "multivalue": false,
      "onCreateEditable": true
    }
  ]
}
```
