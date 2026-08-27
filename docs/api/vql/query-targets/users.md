<!-- source: https://general.veevavault.dev/vql/query-targets/users/ -->
<!-- title: Users -->

# Users

The `users` query target allows you to query the users in your Vault.

To retrieve user fields and field properties, use the [Retrieve User Metadata API](/vault-api/api-reference/26.2/users/retrieve-user-metadata).

When querying users across Vaults, Vault uses the private key values (`external`, `readOnly`, and `full`) for the `license_type__v` field.

## User Query Examples

The following are examples of user queries.

### Query: Retrieve Users With a Specific License Type

The following query uses the `external` private key value instead of `external__v` to retrieve the first and last names of all external users:

Copy to clipboard

```
SELECT user_first_name__v, user_last_name__v, license_type__v
FROM users
WHERE license_type__v = 'external'
```

#### Response: Retrieve Users With a Specific License Type

The response returns `external__v` instead of the private key value `external`:

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 1,
        "total": 1
    },
    "data": [
        {
            "user_first_name__v": "Abigail",
            "user_last_name__v": "Smith",
            "license_type__v": "external__v"
        }
    ]
}
```
