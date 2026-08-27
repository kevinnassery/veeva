<!-- source: https://general.veevavault.dev/vql/getting-started/structuring-sending-queries/ -->
<!-- title: Structuring & Sending a Query -->

# Structuring & Sending a Query

This guide provides the basic structure of a VQL query and how to submit it to retrieve document and object fields.

## Structuring a Query

VQL’s syntax is similar to SQL and provides a programmatic way of searching your Vault’s data. A basic VQL query consists of a [SELECT statement with a FROM clause](/vql/clauses/select-from):

Copy to clipboard

```
SELECT {fields}  
FROM {query target}
```

The `SELECT` clause provides the fields to retrieve from the specified query target, such as `id`. The `FROM` clause provides the [query target](/vql/query-targets), such as `documents`.

For example, to retrieve the latest version of all documents from a Vault, use this basic query:

Copy to clipboard

```
SELECT id
FROM documents
```

## Sending a Query

To send a VQL query, send a **POST** request to the `/api/{version}/query` endpoint as shown in the [Vault API Reference](/vault-api/api-reference/26.2/vault-query-language-vql). Using **POST** allows you to send a VQL statement of [up to 50,000 characters](/vql/references/system-limits-performance/execution-constraints).

### Query

The following example sends a query that retrieves the ID and name of all documents in the specified Vault:

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d 'q=select id, name__v from documents' \
"https://myvault.veevavault.com/api/v20.3/query"
```

The VQL API response includes a `data` payload with the requested fields:

### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 96,
        "total": 96
    },
    "data": [
        {
            "id": 119,
            "name__v": "CholeCap Batch Manufacturing RecordTest File 1"
        },
        {
            "id": 1,
            "name__v": "CholeCap Visual AidTest File 2"
        }
    ]
}
```
