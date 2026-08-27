<!-- source: https://general.veevavault.dev/vql/query-targets/document-events/ -->
<!-- title: Document Events -->

# Document Events

Use the `events` object to query document events.

To retrieve document event fields and field properties, use the [Retrieve Document Event Subtype Metadata API](/vault-api/api-reference/26.2/documents/document-events/retrieve-document-event-subtype-metadata).

## Document Events Query Examples

The following are examples of document events queries.

### Query: Retrieve Document Events

The following query retrieves the document ID, event type, and event date of all document events:

Copy to clipboard

```
SELECT document_id__v, event_type__v, event_date__v
FROM events
```

#### Response: Retrieve Document Events

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 1,
       "total": 1
   },
   "data": [
        {
            "document_id__v": "123",
            "event_date__v": "2015-03-20T22:06:40.000Z",
            "event_type__v": "Distribution Event"
        }
    ]
}
```
