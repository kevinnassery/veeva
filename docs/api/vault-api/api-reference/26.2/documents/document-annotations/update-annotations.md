<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/update-annotations/ -->
<!-- title: Update Annotations -->

# Update Annotations

Update up to 500 existing annotations.

Use this request to update the coordinates and time signature of an annotation on a video document. This is equivalent to the *Move* action in the Vault document viewer UI. Learn more about [moving video annotations](https://platform.veevavault.help/en/gr/40938/#moving).

PUT`/api/{version}/objects/documents/annotations/batch`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `text/csv` |
| `Content-Type` | `application/json` |

## Body Parameters

Prepare a JSON-formatted list of annotation objects. Each object must contain the `id__sys`, `document_version_id__sys`, and the annotation field(s) to be updated. For more details about annotation fields, see [Read Annotations by Document Version and Type](/vault-api/api-reference/26.2/documents/document-annotations/read-annotations-by-document-version-and-type).

You can only update an annotation ID (`id__sys`) once per request. If you provide duplicate annotation IDs, the bulk update fails any duplicate annotations.

## Request

Copy to clipboard

```
curl -X PUT -H "Authorization: {AUTH_VALUE}" \
-H 'Content-Type: application/json' \
-H 'Accept: application/json' \
-d '[
   {
       "id__sys": "58",
       "document_version_id__sys": "1_0_1",
       "comment__sys": "Updated comment from api"
   },
   {
       "id__sys": "54",
       "document_version_id__sys": "1_0_1",
       "color__sys": "yellow_light__sys"
   }
]'
https://myvault.veevavault.com/api/v26.2/objects/documents/annotations/batch
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "1_0_1",
            "global_version_id__sys": "123456_1_1",
            "id__sys": "58"
        },
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "1_0_1",
            "global_version_id__sys": "123456_1_1",
            "id__sys": "54"
        }
    ]
}
```

## Response Details

On `SUCCESS`, the response includes the document version ID, global version ID, and ID and version of updated annotations. See [Create Annotations](/vault-api/api-reference/26.2/documents/document-annotations/create-multiple-annotations) for details. Annotations that did not update successfully are reported with an error message.
