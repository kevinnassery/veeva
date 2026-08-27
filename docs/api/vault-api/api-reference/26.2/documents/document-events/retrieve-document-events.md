<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-events/retrieve-document-events/ -->
<!-- title: Retrieve Document Events -->

# Retrieve Document Events

GET`/api/{version}/objects/documents/{doc_id}/events`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/objects/documents/534/events
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "events": [
        {
            "name": "download__v",
            "label": "Approved Email Download",
            "properties": {
                "event_date__v": "2015-03-20T22:06:40.000Z",
                "document_id__v": 534,
                "major_version_number__v": 2,
                "minor_version_number__v": 0,
                "triggered_by__v": 46916,
                "event_type__v": "Distribution Event",
                "event_subtype__v": "Approved Email",
                "classification__v": "Download",
                "external_id__v": "1234",
                "user_email__v": "quinntaylor@myemail.com",
                "event_modified_by__v": 46916,
                "event_modified_date__v": "2015-03-20T22:06:40.000Z",
                "document_number__v": "REF-0059",
                "document_name__v": "WonderDrug Information"
            }
        }
    ]
}
```

## Response Details

On `SUCCESS`, Vault returns the list of event objects, each containing the fields as defined by the metadata for its event type. Null and/or false valued fields are omitted from the response.
