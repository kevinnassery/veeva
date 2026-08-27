<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/document-lifecycle-workflows/lifecycle-role-assignment-rules/ -->
<!-- title: Lifecycle Role Assignment Rules -->

# Lifecycle Role Assignment Rules

For both standard and custom roles, you can define a subset of users who are allowed in the role and define users that Vault automatically assigns to the role at document creation or when a workflow starts. You can also override the allowed users and default users settings based on standard object-type document fields like Country, Product, Study, etc.

#### Vault Help Resources

* [Lifecycles & Workflows](https://platform.veevavault.help/en/gr/52053)
* [Defining Allowed & Default Users for Roles](https://platform.veevavault.help/en/gr/6572)
* [Users & Groups](https://platform.veevavault.help/en/gr/37744)
* [Fields & Objects](https://platform.veevavault.help/en/gr/33946)

Note the following limitations:

* The API can only be used with active lifecycles and roles.
* If the input contains duplicate field values, only the first instance is processed. The remaining duplicate fields are ignored.
* The maximum number of roles that can be created or updated per request is 50,000.
* The lifecycle role default rule cannot be set when creating override rules.
* A role cannot be assigned more users or groups to default roles than allowed on the role.
* The default `owner__v` role cannot be edited.
