<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-types/retrieve-details-from-all-object-types/ -->
<!-- title: Retrieve Details from All Object Types -->

# Retrieve Details from All Object Types

Retrieve all object types and object type fields in the authenticated Vault.

GET`/api/{version}/configuration/Objecttype`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/configuration/Objecttype
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "size": 190,
        "total": 190
    },
    "data": [
        {
            "name": "base__v",
            "object": "activity__v",
            "active": true,
            "additional_type_validations": [],
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
                }
            ],
            "default_type": true,
            "label_plural": "Base Activities",
            "label": "Base Activity"
        },
        {
            "name": "user_task__v",
            "object": "activity__v",
            "active": true,
            "additional_type_validations": [],
            "type_fields": [
                {
                    "required": false,
                    "name": "due_date__v",
                    "source": "custom"
                },
                {
                    "required": false,
                    "name": "complete__v",
                    "source": "custom"
                }
            ],
            "default_type": false,
            "label_plural": "User Tasks",
            "label": "User Task"
        }
    ]
}
```

## Response Details

The response lists all object types and all fields configured on each object type. See the next response for details.
