<!-- source: https://general.veevavault.dev/vql/references/system-limits-performance/page-size-specifications/ -->
<!-- title: Page Size Specifications -->

# Page Size Specifications

While VQL can return large datasets, results are ditributed across discrete pages. You can control the volume of data per response using `PAGESIZE`.

## Number of Records Returned

There is no limit to the total number of records returned by a query. However, the default maximum number of records displayed per page is 200 for `documents` and 1000 for objects. You can adjust this limit with the `PAGESIZE` clause.

## Limiting the Number of Records Returned

VQL provides the `PAGESIZE` clause to limit the number of results displayed per page.

For some object types, the response does not include the `next_page` and `previous_page` pagination URLs and instead displays all results on one page. Learn more about [paginating results](/vql/references/pagination-best-practices#Paginating_Results).

When performing queries with unusually large numbers of fields in the `SELECT` clause, the API may scale down the number of results per page to reduce stress on the memory limit of the system. When this happens, you may experience an unexpected number of results in your response. For example, you were expecting 1000 results per page but the system only returned 400 per page. In these cases, the system returns the same total number of results; they are simply distributed across more pages.
