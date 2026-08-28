<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-binder-roles/ -->
<!-- title: Document and Binder Roles -->

# Document and Binder Roles

Documents and binders can have different roles available to them depending on their type and lifecycles. There are a set of standard roles that ship with Vault: `owner__v`, `viewer__v`, and `editor__v`. In addition, Admins can create custom roles defined per lifecycle. Learn more about roles in [Vault Help](https://platform.veevavault.help/en/gr/2662).

Through the Role APIs, you can:

* Retrieve available roles on documents and binders
* Determine who can be assigned to roles
* Retrieve default users who are assigned automatically within the Vault UI
* Retrieve who is currently assigned to a role
* Add additional users and groups to a role
* Remove users and groups from roles

All responses return user and group IDs. To determine user and group names and other data, use the [Users](/vault-api/api-reference/26.2/users) or [Groups](/vault-api/api-reference/26.2/groups) API.

For roles on object records, see [Object Roles](/vault-api/api-reference/26.2/vault-objects/object-roles).
