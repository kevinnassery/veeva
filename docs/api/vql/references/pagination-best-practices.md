<!-- source: https://general.veevavault.dev/vql/references/pagination-best-practices/ -->
<!-- title: Pagination Best Practices -->

# Pagination Best Practices

Vault limits the size of result sets to maintain system stability. Use the `next_page` and `previous_page` URLs in the response to paginate your queries.

## Paginating Results

After you submit a query, Vault API returns the first page of query results instead of all results at once. When the number of query results is greater than the page size, the response provides `next_page` and `previous_page` URLs for pagination. These URLs include information from the original query. Call these URLs with a **POST** request.

We recommend using the `next_page` and `previous_page` URLs over manual pagination with `PAGEOFFSET`. Learn more about [query performance with pagination](/vql/references/query-performance-best-practices#Paginating_Results).

### Limits

The `next_page` and `previous_page` endpoints remain active for 72 hours from either the original query or the last pagination call, whichever is more recent. After that, you must resubmit the original query. The 72 hour span is not guaranteed, as system maintenance or other release events could terminate it.

The `next_page` and `previous_page` endpoints count against the [VQL API burst limit](/vql/references/system-limits-performance/transaction-limits).

When querying workflows ([legacy](/vql/query-targets/workflows#Legacy_Workflow)), events, or users, the response does not include the `next_page` or `previous_page` URL endpoints and displays all results on one page. In these cases, submit additional queries using `PAGEOFFSET` to paginate over the result set. Learn more about [paginating results with PAGEOFFSET](/vql/clauses/pageoffset).

## Page Size Adjustment

When the response payload for a VQL query is very large, Vault decreases the page size from the default 1000 to improve performance. A large response payload can result from a VQL query with a large number of fields or with large Rich Text or Long Text field values. This adjustment affects queries with and without the `PAGESIZE` clause.

Page size adjustment is for the protection of Vault and cannot be configured.
