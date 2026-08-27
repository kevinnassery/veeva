<!-- source: https://general.veevavault.dev/vql/references/language-specifications/terminology/ -->
<!-- title: Terminology -->

# Terminology

This table defines commonly used terms in the `VQL` reference.

| Convention | Description | Examples |
| --- | --- | --- |
| Clause | A clause controls the source, filtering, and presentation of retrieved data. | `FROM documents ORDER BY id ASC` |
| `SELECT` statement | The `SELECT` statement retrieves records from Vault. It must contain the `SELECT` and `FROM` clauses and may contain additional clauses. | `SELECT id FROM documents`   `SELECT id FROM documents WHERE name__v = 'USA'` |
| Expression | An expression evaluates to a single value. A logical expression evaluates to a boolean value. | `created_date__v > '2014-12-20'` |
| Logical operator | A logical operator is used in a `WHERE` or `FIND` clause to build a logical expression. | `AND` `OR` `NOT` |
| Comparison operator | A comparison operator is used in a `WHERE` clause to create a logical expression that compares two values. | `<=` `!=` `BETWEEN` `LIKE` |
| Function | A function returns a value. It either retrieves or modifies the specified field value. | `CASEINSENSITIVE(name__v)` |
| Query target | A query target is a collection of Vault data that supports `VQL` queries. The object in a `VQL` query may be a Vault object or another query target such as `documents` or `users`. | `SELECT {field} FROM {query target}`   `SELECT id FROM product__v`   `SELECT id FROM users` |
| Query target option | A query target option filters or modifies the queryable field, object, or set of results that follow it. | `LATESTVERSION name__v` |
| Vault object | A [Vault object](/vault-api/guides/understanding-metadata) is part of the application data model, such as *Product*, *Country*, or *Study*, and can be used as a query target. | `product__v` |
