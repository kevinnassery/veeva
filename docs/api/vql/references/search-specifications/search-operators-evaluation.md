<!-- source: https://general.veevavault.dev/vql/references/search-specifications/search-operators-evaluation/ -->
<!-- title: Search Operators & Evaluation -->

# Search Operators & Evaluation

VQL applies specific logic when processing multiple operators within a `FIND` clause.

## Strict Matching & Using Operators with FIND

Strict matching returns precise search results and is enabled by default for simple VQL searches. A simple VQL search does not contain [operators](/vql/operators) in the `FIND` search phrase. It returns the same results as basic search in the Vault UI. Learn more about [basic search in Vault Help](https://platform.veevavault.help/en/lr/442#basic-search).

Vault does not apply strict matching if the search query is complex or if an Admin has disabled strict matching in your Vault. A complex VQL search contains at least one operator in the `FIND` search phrase. When strict matching is not applied, Vault places an implicit `OR` operator between each search term. Learn more about [strict matching in Vault Help](https://platform.veevavault.help/en/lr/61691#about-strict-matching).

A multi-scope query can have one scope that is simple and another that is complex. For example:

Copy to clipboard

```
FIND ('diabetes AND insulin OR Nyaxa' SCOPE PROPERTIES OR 'cholesterol Cholecap' SCOPE CONTENT)
```

In this case, Vault will apply strict matching to the `CONTENT` scope, but not to the `PROPERTIES` scope.

Strict matching with `FIND` always uses the latest behavior of strict matching in Vault, so changes to strict matching functionality may affect existing VQL queries. Learn more in [Vault Help](https://platform.veevavault.help/en/lr/61691#about-strict-matching).

## Order of Evaluation

In v25.1+, VQL applies an order of evaluation when the `FIND` clause contains multiple operators:

1. Operations within parentheses are evaluated first
2. `AND` operations are evaluated before `OR` operations
3. Otherwise, operators are evaluated from left to right

For example, in the following query, VQL evaluates the `OR` operation in parentheses before the `AND` operation:

`FIND ('diabetes' SCOPE PROPERTIES AND ('cholesterol' SCOPE CONTENT OR 'insulin'))`

In previous versions, VQL evaluates operators from left to right and disregards parentheses.

## Operator Exceptions

If all terms in a search string are joined by the `AND` operator, Vault requires all of the terms to match. For example, the following query would return results containing both 'diabetes' and 'insulin' but would not include results containing only one of the terms.

Copy to clipboard

```
FIND ('diabetes AND insulin')
```

Using `NOT` outside of the search string negates the entire expression with strict matching applied. For example, the following query could return results containing 'pain' and 'medication' but not 'pain medication'.

Copy to clipboard

```
FIND (NOT 'pain medication')
```
