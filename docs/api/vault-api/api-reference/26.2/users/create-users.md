<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/create-users/ -->
<!-- title: Create Users -->

# Create Users

Note

Beginning in v18.1, Admins create and manage users with `user__sys` object records. Unless you are adding cross-domain or VeevaID users or adding users to a domain without assigning Vault membership, we strongly recommend using the [Create Object Records](/vault-api/api-reference/26.2/vault-objects/create-upsert-object-records) endpoint to create new users.

Create new user accounts or add existing users as cross-domain users. Learn more about [cross-domain users](https://platform.veevavault.help/en/gr/38996) in Vault Help. Note that users only receive welcome emails if they are assigned to a Vault. For example, a new domain user who does not have any assigned Vaults will not receive a welcome email.

**Suppressing Welcome Emails**: When creating new users, you can prevent Vault from sending welcome emails to a user by setting the `user_needs_to_change_password__v` setting to `false`. This does not work for users with SSO security profiles, but you can work around this limitation by creating the users with a basic security profile and updating them to the SSO security profile with an update action.
