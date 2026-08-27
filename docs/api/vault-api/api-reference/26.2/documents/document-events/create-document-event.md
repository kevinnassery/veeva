<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-events/create-document-event/ -->
<!-- title: Create Document Event -->

# Create Document Event

POST`/api/{version}/objects/documents/{doc_id}/versions/{major_version}/{minor_version}/events`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{doc_id}` | The document `id` field value. |
| `{major_version}` | The document `major_version_number__v` field value. |
| `{minor_version}` | The document `minor_version_number__v` field value. |

## Body Parameters

| Name | Description |
| --- | --- |
| `event_type__v` required | The event type. For example, `distribution__v`. |
| `event_subtype__v` required | The event subtype. For example, `approved_email__v`. |
| `classification__v` required | The event classification. The available classifications vary based on the `event_subtype__v`. |
| `external_id__v` conditional | Set an external ID value on the document event. This parameter may be required depending on the document type, subtype, and classification. |

Additional fields may be required depending on the document event type, subtype, and classification. Use the [Retrieve Document Event Subtype Metadata](/vault-api/api-reference/26.2/documents/document-events/retrieve-document-event-subtype-metadata) endpoint to retrieve metadata for the required fields.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "event_type__v=distribution__v" \
-d "event_subtype__v=approved_email__v" \
-d "classification__v=download__v" \
-d "external_id__v=1234" \
-d "user_email__v=vern@veeva.com" \
https://myvault.veevavault.com/api/v26.2/objects/documents/72/versions/0/2/events
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS"
}
```

## Response Details

On `SUCCESS`, Vault logs the document event.
