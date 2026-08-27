<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/retrieve-documents/ -->
<!-- title: Retrieve Documents -->

# Retrieve Documents

The following rules govern document retrieval:

* Vault only returns documents to which the logged in user has access to, even if more documents exist.
* Vault only returns the latest version of each document. To return every version of a document, use the `versionscope=all` query parameter.
* Vault returns a maximum of 200 documents per page. You can lower this number using the `limit` query parameter.

#### Identifying Binders

The document pseudo-field `binder__v` indicates whether the returned document is a document or a binder.
The value of `true` means it is a binder, `false` or absence of this field means it is a document. If it is a binder, the binder sections are not listed as part of the response and must be determined using the [Retrieve Binder API](/vault-api/api-reference/26.2/binders/retrieve-binders/retrieve-binder) with the `depth=all` query parameter.

#### Identifying CrossLink Documents

A document pseudo-field `crosslink__v` indicates whether the returned document is a regular document (`false`) or a CrossLink document (`true`).
