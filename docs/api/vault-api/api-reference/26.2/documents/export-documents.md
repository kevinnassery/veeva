<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/export-documents/ -->
<!-- title: Export Documents -->

# Export Documents

The Export Documents API allows you to use the document `id` field to export a set of documents to your Vault's [file staging](/vault-api/guides/file-staging). For example, you could use [VQL](/vql/getting-started/structuring-sending-queries) to query the `id` of all documents from 2016 where `type__v` = `Promotional Piece`, then pass the results into the Export Documents API. This starts an asynchronous job whose status you can check with the Retrieve Document Export Results API.

You can export the following artifacts for a given document:

* Source document
* Renditions

You can export all versions or choose to export only the latest version.

This API does not support the following:

* Fields
* Attachments
* Audit trails
* Related documents
* Signature Pages
* Overlays
* Protected renditions

To use the Export Documents API endpoints, the authenticated user's security profile and permission set must grant the following permissions:

* *File Staging: Access*
* *API: Access API*

To export renditions, the authenticated user's security profile must grant the *Document: Download Rendition* permission.

To export source files, the authenticated user's security profile must grant the *Document: Download Document* permission and be in a role on the document lifecycle state that has the *Download Source* permission.
