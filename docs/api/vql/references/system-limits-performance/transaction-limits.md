<!-- source: https://general.veevavault.dev/vql/references/system-limits-performance/transaction-limits/ -->
<!-- title: Transaction Limits -->

# Transaction Limits

To ensure system stability and fair resource allocation, Vault enforces transaction limits on all VQL queries. These limits govern the frequency, concurrency, and duration of query requests.

| Limit Type | Details |
| --- | --- |
| **Burst Limit** | Vault limits the number of API calls each user can make. The default burst limit is 2000 calls every 5 minutes. In v21.1+, when the burst limit is reached, Vault delays all calls by 500 ms until the next 5-minute period begins. |
| **Concurrency Limit** | Vault restricts the number of concurrent queries and query page requests each user can make per Vault. The default concurrency limit is five (5) requests. When the concurrency limit is reached, VQL throttles additional query requests until existing queries have completed. |
| **Timeout Limit** | Vault query requests time out after a period of time. The default timeout limit is 30 minutes. In v23.1+, when VQL queries fail due to timeout, Vault will prevent the same query from being executed again for a period of time. The default is 24 hours. |
