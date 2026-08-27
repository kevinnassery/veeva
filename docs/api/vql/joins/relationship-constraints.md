<!-- source: https://general.veevavault.dev/vql/joins/relationship-constraints/ -->
<!-- title: Relationship Constraints -->

# Relationship Constraints

Relationship constraints define how VQL traverses relationships between different query targets. These rules ensure that joins remain performant and align with the underlying Vault data model.

## Relationship Limits

To maintain optimal performance, VQL enforces a maximum of 10 unique relationships per query. This count includes any combination of:

* **Subqueries** in the `SELECT` clause. For example, `(SELECT id FROM child__cr)`.
* **Lookups** (dot-notation) in the `SELECT` or `WHERE` clauses. For example, `parent__cr.name__v`.

If a query exceeds 10 unique relationships, the API returns an error.

Learn more about [VQL Query Performance Best Practices](/vql/references/query-performance-best-practices).

## Depth & Nesting Limits

* **Subquery nesting**: VQL supports only one level of subquery nesting. You cannot place a `SELECT` subquery inside another `SELECT` subquery.
* **Join depth**: A single VQL query can only traverse one relationship per subquery or lookup.
* **Filtering levels**: In v25.1+, you can achieve a third level of filtering by nesting a `WHERE` clause lookup inside a `WHERE IN` subquery.
