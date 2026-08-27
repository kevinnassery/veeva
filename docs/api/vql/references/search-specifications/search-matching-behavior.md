<!-- source: https://general.veevavault.dev/vql/references/search-specifications/search-matching-behavior/ -->
<!-- title: Search Matching Behavior -->

# Search Matching Behavior

The `FIND` clause searches object and document fields and document content. When searching your Vault with a VQL query, behaviors such as stemming and tokenization usually match the search behavior in the Vault UI. Learn more in [Vault Help](https://platform.veevavault.help/en/lr/442).

## Stemming

Vault uses stemming to return results for metadata (but not content) searches that include inflections of the search term:

* The singular or plural form of a noun. For example, "virus" will match "viruses".
* The tense of a verb. For example, "modify" will match "modified".
* The comparative or superlative form of an adjective. For example, "large" will match "larger" and "largest".

Stemming is available for English, French, and German fields.

## Synonyms

When searching documents and objects using the `FIND` operator, Vault also returns documents or objects containing synonyms if a thesaurus exists in your Vault. Vault does not search for synonyms if a query contains:

* At least one `NOT` operator. For example, `FIND (NOT 'doctor' SCOPE CONTENT)` will exclude documents or objects that contain the word doctor, but not documents or objects that contain synonyms for doctor.
* At least one `AND` operator. For example, `FIND ('doctor AND physician' SCOPE CONTENT)` will find documents or objects containing the words doctor and physician, but not their synonyms.
* An exact search. For example, `FIND ('"doctor"' SCOPE CONTENT)` will match documents or objects containing the word doctor, but not its synonyms.
* A wildcard. For example, `FIND ('doctor*' SCOPE CONTENT)` will match documents or objects containing the words doctors, but not its synonyms.

## Search Term Tokenization

In v20.2+, Vault automatically tokenizes CamelCase, alphanumeric, and delimited strings when searching document and object fields. When searching content, Vault only tokenizes delimited strings. You can disable tokenization by surrounding the search phrase in double-quotes within single-quotes. For example, `FIND ('"abc123"')`. Learn more about search term tokenization in [Vault Help](https://platform.veevavault.help/en/lr/13824#searching_on_alpha-numeric_punctuated_fields).

To enable tokenization in v9.0 to v20.1, set the `tokenize` request parameter to `true`. In v20.2+, Vault ignores the `tokenize` parameter.
