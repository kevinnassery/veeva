<!-- source: https://general.veevavault.dev/vql/joins/syntax-reference/ -->
<!-- title: Syntax Reference -->

# Syntax Reference

The following tables provide a reference on VQL join patterns, their goals, and the syntax used to achieve them.

## Relationships Between Vault Objects

| Join Pattern | Join Type | Goal | Syntax Template |
| --- | --- | --- | --- |
| **Parent to Child (1:M)** | Outer Join | **Expand** parent results to include related child records. | `SELECT id, (SELECT id FROM inbound_rel__cr) FROM parent_object__v` |
| **Parent to Child (1:M)** | Inner Join | **Filter** parent results to only those with related child records. | `SELECT id FROM parent_object__v WHERE id IN (SELECT id FROM inbound_rel__cr)` |
| **Child to Parent (M:1)** | Outer Join | **Expand** child results to include parent metadata. | `SELECT id, outbound_rel__cr.field__v FROM child_object__v` |
| **Child to Parent (M:1)** | Inner Join | **Filter** child results based on parent field values. | `SELECT id FROM child_object__v WHERE outbound_rel__cr.field__v = 'value'` |
| **Traversal (M:M)** | Outer Join | **Expand** Parent 1 results to include Parent 2 data via a join object. | `SELECT id, (SELECT id, outbound_to_parent2__cr.field__v FROM inbound_bridge__cr) FROM parent1__v` |
| **Traversal (M:M)** | Inner Join | **Filter** Parent 1 results based on Parent 2 values via a join object. | `SELECT id FROM parent1__v WHERE id IN (SELECT id FROM inbound_bridge__cr WHERE outbound_to_parent2__cr.field__v = 'value')` |
| **Lookup (1:1)** | Outer Join | **Expand** results to include data from a reference object. | `SELECT id, outbound_rel__cr.field__v FROM vault_object__v` |
| **Lookup (1:1)** | Inner Join | **Filter** results based on reference object's field values. | `SELECT id FROM vault_object__v WHERE outbound_rel__cr.field__v = 'value'` |

## Document Relationships Referencing a Vault Object

These joins use the specialized `document_` relationship name created automatically when the field is defined on the document.

| Join Pattern | Join Type | Goal | Syntax Template |
| --- | --- | --- | --- |
| **Document to Object (M:M)** | Outer Join | **Expand** document results to include related object metadata. | `SELECT id, (SELECT id, name__v FROM document_vault_object__vr) FROM documents` |
| **Object to Document (M:M)** | Outer Join | **Expand** object results to include related documents. | `SELECT id, (SELECT id, name__v FROM document_vault_object__vr) FROM vault_object__v` |
| **Document to Object (M:M)** | Inner Join | **Filter** documents based on related object criteria. | `SELECT id FROM documents WHERE id IN (SELECT id FROM document_vault_object__vr WHERE field__v = 'value')` |
| **Object to Document (M:M)** | Inner Join | **Filter** object results based on related document criteria. | `SELECT id FROM vault_object__v WHERE id IN (SELECT id FROM document_vault_object__vr WHERE status__v = 'Approved')` |

## Object Reference Fields Pointing to Documents

These joins use standard reference logic where the field is defined on the Vault object.

| Join Pattern | Join Type | Goal | Syntax Template |
| --- | --- | --- | --- |
| **Object to Document (M:1)** | Outer Join | **Expand** object results to include a single referenced document. | `SELECT id, doc_outbound_rel__cr.name__v FROM vault_object__v` |
| **Document to Object (1:M)** | Outer Join | **Expand** document results to include all objects referencing it. | `SELECT id, (SELECT id FROM object_inbound_rel__cr) FROM documents` |
| **Document Traversal (M:M)** | Outer Join | **Expand** document results to see a second object via a join object. | `SELECT id, (SELECT id, outbound_to_parent2__cr.name__v FROM inbound_bridge__cr) FROM documents` |

---

## Usage Notes

* **Relationship Names:** Always use the relationship name (e.g., `inbound_rel__cr`) rather than the object name. Inbound relationships use the `SELECT` subquery, while outbound relationships use dot-notation lookups (e.g., `outbound_rel__cr.field__v`).
* **Outer vs. Inner:** Use `SELECT` subqueries or lookups to **add** data (Outer Join). Use `WHERE IN` subqueries or `WHERE` lookups to **filter** the result set (Inner Join).
* **Cardinality Rule:** If the relationship points to a collection (Inbound/Many), use a subquery. If it points to a single record (Outbound/One), use a lookup.
