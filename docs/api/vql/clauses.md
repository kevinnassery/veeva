<!-- source: https://general.veevavault.dev/vql/clauses/ -->
<!-- title: Clauses -->

# Clauses

The basic structure of a VQL query is a `SELECT` statement with a `FROM` clause. You can filter and sort the results with additional clauses such as `WHERE` and `ORDER BY`.

You can add the following clauses to a VQL query:

| Name | Syntax | Description |
| --- | --- | --- |
| [SELECT & FROM](/vql/clauses/select-from) | `SELECT {field} FROM {query target}` | Select fields to return from a specified query target. |
| [SHOW](/vql/clauses/show) | `SHOW TARGETS|FIELDS|RELATIONSHIPS` | Retrieve the query target schema for a Vault. |
| [WHERE](/vql/clauses/where) | `WHERE {operator} {value}` | Apply search filters and narrow results. |
| [FIND](/vql/clauses/find) | `FIND ('{search phrase}')` | Search fields for specific search terms. |
| [ORDER BY](/vql/clauses/order-by) | `ORDER BY {field} ASC|DESC` | Sets the sort order of query results. |
| [MAXROWS](/vql/clauses/maxrows) | `MAXROWS {number}` | Set the maximum number of results to retrieve. |
| [SKIP](/vql/clauses/skip) | `SKIP {number}` | Set the number of results to skip. |
| [PAGESIZE](/vql/clauses/pagesize) | `PAGESIZE {number}` | Limits the number of query results per page. |
| [PAGEOFFSET](/vql/clauses/pageoffset) | `PAGEOFFSET {number}` | Display results in multiple pages. |
| [AS](/vql/clauses/as) | `AS {alias}` | Define an optional alias for a field or function. |
