<!-- source: https://general.veevavault.dev/vql/references/query-performance-best-practices/ -->
<!-- title: Query Performance Best Practices -->

# Query Performance Best Practices

Some VQL queries can degrade Vault stability and performance, especially when you’re working with large datasets. This section provides workarounds for queries that are likely to be computationally expensive.

When testing your queries, the size of the datasets should always match the size in production.

To maintain optimum performance, Vault balances request loads by imposing [transaction limits](/vql/references/system-limits-performance/transaction-limits).

## Working with Large Datasets

Using VQL to query large datasets is likely to cause performance issues. For example:

* The number of API calls required may exceed the transaction limit.
* The query may not complete within the maximum execution time of an SDK request.

To prevent these issues when working with large datasets, we recommend using the *Scheduled Data Exports* job instead of VQL. Learn more about the [Scheduled Data Exports job in Vault Help](https://platform.veevavault.help/en/lr/70128).

## Joining Datasets

Using a relationship query to join datasets may take a long time to complete. It is often more performant to use two separate queries.

For example, you could use the following computationally expensive query to join two large datasets:

Copy to clipboard

```
SELECT id, (SELECT id, name__v FROM country__cr)
FROM product__v
WHERE country__cr.name__v = 'USA'
```

For better performance, split this example into two queries:

1. Query the primary object:

Copy to clipboard

```
SELECT id, country__c
FROM product__v
```

2. Query the secondary object to retrieve the related data:

Copy to clipboard

```
SELECT id, name__v
FROM country__v
WHERE name__v = 'USA'
```

You can then join the two sets of results outside of VQL.

## Sorting Results

Using VQL’s `ORDER BY` clause to sort records can take a long time to complete. For large datasets, we recommend sorting records directly in your database.

In v23.1+, VQL returns a warning response for queries with `ORDER BY` that take longer than 5 minutes.

## Paginating Results

Queries that use `PAGEOFFSET` to manually paginate results can be computationally expensive:

* In v23.1+, manual pagination with `PAGEOFFSET` returns a warning response. Manually paginating more than 10,000 records returns an error response.
* In earlier versions, we strongly discourage using `PAGEOFFSET` to paginate large datasets.

For better performance, use the `previous_page` and `next_page` response URLs to paginate over your results. Learn more about [paginating VQL queries](/vql/references/pagination-best-practices).

## Retrieving Result Count

VQL returns the result count with every query response, but it also returns record data and caches results to optimize pagination requests. This can negatively affect performance when all you need is the result count. To request only the total number of records, we recommend setting `PAGESIZE 0`.

For example, the following query returns the number of documents in the Vault:

Copy to clipboard

```
SELECT id
FROM documents
PAGESIZE 0
```

The response contains only the result count:

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 0,
        "pageoffset": 0,
        "size": 0,
        "total": 146301
    },
    "data": []
}
```

## Handling Duplicate Queries

Duplicate query strings executed within a short amount of time can cause performance issues. For better performance, we recommend caching frequently requested data.

In v23.1+, VQL detects and returns a warning for duplicate query strings executed within a fixed period of 5 minutes.

## Filtering Queries

Queries that are unfiltered (missing the `WHERE` clause) can take a long time to complete. You can improve query performance by adding a `WHERE` clause to decrease the number of results.

In v23.1+, VQL returns a warning response for unfiltered queries that take longer than 5 minutes.

## Using Leading Wildcard on FIND

A `FIND` search can take a long time to complete when a search term begins with the wildcard character `*`:

* In v22.3+, VQL does not support leading wildcards in `FIND` search terms.
* In earlier versions, we strongly discourage using leading wildcards in your search queries.
