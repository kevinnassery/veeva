<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-tokens/ -->
<!-- title: Document Tokens -->

# Document Tokens

The Vault Document Tokens API allows you to generate document access tokens needed by the external viewer to view documents outside of Vault. [Learn more.](/commercial/library/guides/external-document-viewer)

POST`/api/{version}/objects/documents/tokens`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## Body Parameters

| Name | Description |
| --- | --- |
| `docIds` required | Include the `docIds` request parameter with a comma-separated string of document `id` values. This will generate tokens for each document. For example: `docIds=101,102,103,104` |
| `expiryDateOffset` optional | Include the `expiryDateOffset` request parameter set to the number of days after which the tokens will expire and the documents will no longer be available in the viewer. If not specified, the tokens will expire after 10 years by default. |
| `downloadOption` optional | Include the `downloadOption` request parameter set to `PDF`, `source`, `both`, or `none`. These allow users viewing the document to be able to download a PDF version or source version (Word, PowerPoint, etc.) of the document. If not specified, the download options default to those set on each document. |
| `channel` optional | Include the `channel` request parameter set to the website object record `id` value that corresponds to the distribution channel where the document is being made available. If no website record is specified, Vault will assume the request is for Approved Email. |
| `tokenGroup` optional | Include the `tokenGroup` request parameter to group together generated tokens for multiple documents in order to display the documents being referenced in the same viewer. This value accepts strings of alphanumeric characters (a-z, A-Z, 0-9, and single consecutive underscores) up to 255 characters in length. The token that is passed as a URL parameter to the External Viewer is the primary token and the document it references will be displayed normally. However, any additional documents that have tokens generated with the same case-sensitive `tokenGroup` string will be displayed in a sidebar of the viewer. The order of documents in the sidebar depends on the order in which the tokens are generated. If multiple tokens are generated with one request, the documents will be ordered top-to-bottom based on the order they are passed to the `docIds` parameter. For example: If passing the parameters `docIds=101,102,103,104` and `tokenGroup=group_1` with the request, the top-to-bottom order in the sidebar will be documents 101, 102, 103, 104. If a new request is then made with the parameters `docIds=105` and `tokenGroup=group_1`, document 105 will be added below document 104 in the previous list. |
| `steadyState` optional | If set to `true`, Vault generates a token for the latest steady state version of a document. If you do not have *View* permission, or if a steady-state version does not exist, Vault returns an `INVALID_STATE` error. If omitted, the default value is `false`, and Vault generates a token for the latest version, regardless of state. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "docIds=101,102,103,104" \
-d "expiryDateOffset=90" \
-d "downloadOption=PDF" \
-d "channel=00W000000000301" \
https://myvault.veevavault.com/api/v26.2/objects/documents/tokens
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "tokens": [
        {
            "document_id__v": 101,
            "token__v": "3003-cb6e5c3b-4df9-411c-abc2-6e7ae120ede7"
        }
        {
            "document_id__v": 102,
            "token__v": "3003-1174154c-ac8e-4eb9-b453-2855de273bec"
        },
        {
            "document_id__v": 103,
            "token__v": "3003-51ca652c-36d9-425f-894f-fc2f42601fa9"
        },
        {
            "document_id__v": 104,
            "errorType": "OPERATION_NOT_ALLOWED",
            "errors": [
                {
                    "type": "INVALID_DOCUMENT",
                    "message": "Document not found [104]."
                }
            ]
        }
    ]
}
```

## Response Details

In the example above, tokens are generated for the first three documents. The fourth document could not be found. This indicates either an incorrect document `id` or that the specified document is a binder.
