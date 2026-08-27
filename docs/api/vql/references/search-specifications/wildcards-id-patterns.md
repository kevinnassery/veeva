<!-- source: https://general.veevavault.dev/vql/references/search-specifications/wildcards-id-patterns/ -->
<!-- title: Wildcards & ID Patterns -->

# Wildcards & ID Patterns

VQL supports specific characters and patterns to facilitate partial matches and the identification of formatted strings like document numbers.

## Wildcards

When searching documents and objects using the `FIND` clause, use the wildcard character `*` to find partial matches.

You can place the wildcard character in any part of the search term except at the beginning. In v22.3+, VQL does not support leading wildcards. In earlier versions, we strongly discourage adding wildcards at the beginning of search terms due to negative effects on performance and relevance.

In v24.2+, there is a maximum of two (2) wildcards per search term and ten (10) search terms with wildcards for the entire search string.

For example:

* `FIND ('bio*')` returns `documents` or objects with words beginning with 'bio', such as biology or biodiversity.
* `FIND ('o*ology')` returns `documents` or objects with words starting with 'o' and ending with 'ology', such as oncology or ophthalmology.
* `FIND ('o*olog*')` returns `documents` or objects with words starting with 'o' and ending with 'olog' plus a suffix, such as oncological or ophthalmology.
* `FIND ('*ology')` returns an error response in v22.3+ because leading wildcards are not supported.
* `FIND ('p*o*olog*')` returns an error response in v24.2+ because there is a maximum of two (2) wildcards per search term.

For more query examples, see [FIND](/vql/clauses/find).

### Automatic Wildcarding

Vault automatically adds a wildcard to the end of single search terms that do not match the [ID pattern](#The_ID_Pattern). In `SCOPE CONTENT` queries, VQL also adds a wildcard to the end of the last search term.

VQL does not add a wildcard character to search terms consisting of only one character.

## The ID Pattern

Vault applies special handling to single search terms that either have punctuation in the middle of the term or are a combination of characters and digits. The ID pattern describes the purpose of the special handling but does not comprehensively describe all the searches that qualify. For example, a search for '10mg' is clearly not an ID but matches the ID pattern and receives the ID pattern handling.

For searches that fit the ID pattern, all tokens of the ID must match to be included in search results. Vault applies additional handling to document numbers to ensure the desired document is the first search result. For example, a search for `VV-123-456` would return `VV-123-456` and `VV-456-123`, but special handling ensures that `VV-123-456` appears first in the search results. Additionally, `documents` that only include `VV` are not included.
