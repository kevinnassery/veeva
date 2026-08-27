<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/authentication/delegated-access/ -->
<!-- title: Delegated Access -->

# Delegated Access

Vault’s delegated access feature provides a secure and audited process for you to designate another user to handle Vault responsibilities on your behalf. Vault tracks all activities performed by the delegate and logs their activities in audit trails that meet compliance standards. Learn more about [delegated access in Vault Help](https://platform.veevavault.help/en/gr/15015).

With Vault API’s delegated access endpoints, you can generate a delegated session ID for any Vaults where you have delegate access. This allows you to call Vault API on behalf of any user who granted you delegate access. For example, a user may grant delegate access to an IT professional for help troubleshooting a problem. Your organization may also utilize delegate access for shared accounts, such as a “Migration User.”

Delegation is Vault-specific: If your IT professional needs access to both your PromoMats and Submissions Vaults, you will need to grant them delegate access in both Vaults.
