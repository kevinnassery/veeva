<!-- source: https://general.veevavault.dev/vql/references/system-limits-performance/execution-constraints/ -->
<!-- title: Execution Constraints -->

# Execution Constraints

Execution constraints define the structural boundaries of a VQL statement. These limits prevent excessively complex queries from impacting system performance.

## Query Length

The maximum length of a VQL query string is 50,000 characters. This limit applies to the entire statement sent in the `q` parameter of a `POST` request to the `/query` endpoint.

## Functional Constraints

* **Aggregates**: VQL does not support standard SQL aggregate functions like `SUM`, `AVG`, or `COUNT` within the `SELECT` clause (except for specific specialized endpoints).
* **Subquery Nesting**: You cannot nest a subquery inside another subquery. VQL only supports one level of nesting for relationship joins.

## Raw Object Constraints

* **Search Restrictions**: The `FIND` clause is not supported for Raw Objects.
