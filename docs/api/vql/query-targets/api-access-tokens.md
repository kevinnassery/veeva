<!-- source: https://general.veevavault.dev/vql/query-targets/api-access-tokens/ -->
<!-- title: API Access Tokens -->

# API Access Tokens

You can use the `api_access_token__sys` query target to query API access tokens that exist in your Vault. Learn more about [access tokens](/vault-api/explanation/api-access-tokens/).

## Access Token Queryable Fields

The following fields are queryable for the `api_access_token__sys` object:

| Name | Description |
| --- | --- |
| `id` | The ID of the access token. |
| `name__v` | The name of the access token. |
| `user__sys` | The ID of the user assigned the access token. |
| `status__v` | The status of the access token. |
| `expiry_date__sys` | The expiration date of the access token. |
| `last_used_date__sys` | The date the access token was last used for authentication. |

## Access Token Query Examples

The following are examples of common access token queries.

### Query: Retrieve Active Access Tokens for a Specific User

The following query retrieves all active access tokens for a specific user:

Copy to clipboard

```
SELECT id, name__v, expiry_date__sys, last_used_date__sys
FROM api_access_token__sys
WHERE user__sys = '12345' AND status__v = 'active__v'
```

### Query: Retrieve a Specific Access Token by ID

The following query retrieves a specific access token by ID:

Copy to clipboard

```
SELECT id, name__v, user__sys, status__v
FROM api_access_token__sys
WHERE id = '0PI00000000C002'
```
