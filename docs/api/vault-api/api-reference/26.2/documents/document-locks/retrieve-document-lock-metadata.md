<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-locks/retrieve-document-lock-metadata/ -->
<!-- title: Retrieve Document Lock Metadata -->

# Retrieve Document Lock Metadata

GET`/api/{version}/metadata/objects/documents/lock`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/lock
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "name": "lock",
    "properties": [
        {
            "name": "locked_by__v",
            "scope": "Lock",
            "type": "ObjectReference",
            "required": true,
            "systemAttribute": true,
            "editable": false,
            "setOnCreateOnly": false,
            "disabled": false,
            "objectType": "User",
            "label": "Locked By",
            "hidden": false
        },
        {
            "name": "locked_date__v",
            "scope": "Lock",
            "type": "DateTime",
            "required": true,
            "systemAttribute": true,
            "editable": false,
            "setOnCreateOnly": false,
            "disabled": false,
            "objectType": "DateTime",
            "label": "Locked Date",
            "hidden": false
        }
    ]
}
```

## Response Details

| Metadata Field | Description |
| --- | --- |
| `name` | The "name" of the field used in the API. These include `locked_by__v`, `locked_date__v`, etc. |
| `label` | The "label" of the field used in the UI. These include "Locked By", "Locked Date", etc. |
| `type` | The "type" of field. These include "ObjectReference", "DateTime", etc. |
| `scope` | The "scope" of the field. This value is "Lock" for all fields. |
| `required` | Indicates if the field is required. |
| `systemAttribute` | Boolean (true/false) field which indicates if the field is a standard (system-managed) field, i.e., not editable by the user. |
| `editable` | Boolean (true/false) field which indicates if the field can be set or changed by the user, i.e., not system-managed. |
| `setOnCreateOnly` | Boolean (true/false) field which indicates if the field can only be set during creation of a new document. |
| `objectType` | When the field `type` is "ObjectReference", this field indicates the object which is being referenced. |
