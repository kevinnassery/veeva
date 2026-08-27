<!-- source: https://general.veevavault.dev/vault-api/guides/file-staging/how-to-use-for-extracts/ -->
<!-- title: How to Use File Staging for Extracts -->

# How to Use File Staging for Extracts

When Vault exports files as part of an extract, such as the [Export Documents API](/vault-api/api-reference/26.2/documents/export-documents) or using Vault Loader's *Extract Document Renditions* action, the extracted information downloads to a CSV with references to those files on your file staging.

To retrieve extracted source files, use the [Download Item Content](/vault-api/api-reference/26.2/file-staging/download-item-content) API. This provides superior performance over other methods because:

* Calls to the File Staging API do not impact end-user-performance.
* The Download Item Content API allows you to create resumable downloads for large files, or to continue downloading a file if your session is interrupted.
* The File Staging API can execute up to 10 concurrent threads, allowing you to scale downloads to maximum performance.

To retrieve extracted files using the [Download Item Content](/vault-api/api-reference/26.2/file-staging/download-item-content) API, locate the `file` column in the CSV output from your export. This column shows the filename and location, relative to file staging's root, of each extracted file. Use this path in the [Download Item Content](/vault-api/api-reference/26.2/file-staging/download-item-content) API's `item` parameter to retrieve extracted source files.

Vault automatically deletes extracted files and folders on file staging every 72 hours by default. This auto-deletion timeframe does not apply to files that users upload to file staging.
