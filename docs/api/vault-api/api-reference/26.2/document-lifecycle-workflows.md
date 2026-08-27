<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/ -->
<!-- title: Document Lifecycle and Workflows -->

# Document Lifecycle and Workflows

Document lifecycles are the sequences of states (Draft, In Review, etc.) a document goes through during its life. A lifecycle can be simple (two states requiring users to manually move between states) or very complex (multiple states with different security and workflows that automatically move the document to another state). In Vault, lifecycles simplify the implementation of business logic that traditionally required custom coding or time-consuming manual setup.

Lifecycle states are the ordered states within a lifecycle representing the stages a document transitions through as users create, review, approve, and eventually archive or replace it. A set of business rules applies to each state and defines what happens to the document in that state. Admins define these rules for each lifecycle state and Vault automatically applies them to every document that enters the state.

Learn about [Lifecycles & Workflows in Vault Help](https://platform.veevavault.help/en/gr/52053).
