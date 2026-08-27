<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/users/update-users/ -->
<!-- title: Update Users -->

# Update Users

Update information for a user.

Note

Beginning in v18.1, Admins create and manage users with `user__sys` object records. Unless you are updating domain-only users, we strongly recommend using the [Update Object Records](/vault-api/api-reference/26.2/vault-objects/update-object-records) endpoint to update users.

System Admins and Vault Owners can update users in the Vaults where they have administrative access. System Admins who are also Domain Admins have an unrestricted access to users across all Vaults in the domain.

Note that some user fields are not available to update through the API. For example, you cannot update user profile pictures through the API. To find out which fields are available to update, you can [Retrieve User Metadata](/vault-api/api-reference/26.2/users/retrieve-user-metadata) and find all fields marked as `"editable": true`. If a field is missing from this response, it is not editable.
