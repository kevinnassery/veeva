<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-events/retrieve-document-event-types-and-subtypes/ -->
<!-- title: Retrieve Document Event Types and Subtypes -->

# Retrieve Document Event Types and Subtypes

GET`/api/{version}/metadata/objects/documents/events`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/events
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "events": [
        {
            "name": "distribution__v",
            "label": "Distribution Event",
            "subtypes": [
                {
                    "name": "approved_email__v",
                    "label": "Approved Email",
                    "value": "https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/events/distribution__v/types/approved_email__v"
                },
                {
                    "name": "controlled_copy__v",
                    "label": "Controlled Copy",
                    "value": "https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/events/distribution__v/types/controlled_copy__v"
                },
                {
                    "name": "irep__v",
                    "label": "CRM",
                    "value": "https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/events/distribution__v/types/irep__v"
                },
                {
                    "name": "engage__v",
                    "label": "Engage",
                    "value": "https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/events/distribution__v/types/engage__v"
                },
                {
                    "name": "published_content__v",
                    "label": "Published Content",
                    "value": "https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/events/distribution__v/types/published_content__v"
                },
                {
                    "name": "clm__v",
                    "label": "CLM",
                    "value": "https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/events/distribution__v/types/clm__v"
                }
            ]
        }
    ]
}
```

## Response Details

On `SUCCESS`, Vault returns the list of events, and event types per each event (if applicable). If the user is not permitted to access the event data, the event type is omitted from the response. In this example, one document event `distribution__v` is configured in our Vault. This "Distribution Event" is configured with six document event "subtypes".
