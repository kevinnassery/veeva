<!-- source: https://general.veevavault.dev/vql/references/language-specifications/access-localization/ -->
<!-- title: Access & Localization -->

# Access & Localization

VQL execution is influenced by the context of the authenticated user, including their language settings and their security profile within the Vault.

## User Permissions

VQL automatically enforces Vault's security model. The results returned by a query are restricted based on the permissions of the authenticated user. The results include records and fields for which the authenticated user has `Read` or `View` permission.

The *API Access* permission is required to execute VQL queries using Vault API.

Learn more about user permissions and access control [in Vault Help](https://platform.veevavault.help/en/lr/6591).

## Languages: Multilingual Label Resolution

When querying document fields in the `SELECT` and `WHERE` clauses, Vault resolves localized field labels in the following order:

* **User's language:** Matches the label in the user's language.
* **Base language**: Matches the value against the label values in the Vault's base language.
* VQL queries performed with field values in languages other than the user's language are matched against the label values in Vault's base language.
* Field values without strings in Vault's base language return results in the system language.
* This applies only to `documents` queries and document fields used in the `SELECT` and `WHERE` clauses.
