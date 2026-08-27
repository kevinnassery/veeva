<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-roles/ -->
<!-- title: Object Roles -->

# Object Roles

Object records can have different roles available to them depending on their type and lifecycles. There are a set of standard roles that ship with Vault: `owner__v`, `viewer__v`, and `editor__v`. In addition, Admins can create custom roles defined per lifecycle. Not all object records will have users and groups assigned to roles. Learn more about roles on object records in [Vault Help](https://platform.veevavault.help/en/gr/36440).

Through the object record role APIs, you can:

* Retrieve available roles on object records
* Retrieve who is currently assigned to a role
* Add additional users and groups to a role
* Remove users and groups from roles

Note that all user and group information is returned as IDs, so you need to use the Retrieve User or Retrieve Group API to determine the name.

For roles on documents or binders, see [Document & Binder Roles](/vault-api/api-reference/26.2/document-binder-roles).
