<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/add-annotation-replies/ -->
<!-- title: Add Annotation Replies -->

# Add Annotation Replies

Create up to 500 annotation replies.

POST`/api/{version}/objects/documents/annotations/replies/batch`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `text/csv` |
| `Content-Type` | `application/json` |

## Body Parameters

Prepare a JSON-formatted list of annotation reply objects. Each object must contain the `id__sys`, `document_version_id__sys`, and the annotation field(s) to be set, and a `placemark` object containing the following:

| Placemark Field | Description |
| --- | --- |
| `type__sys` required | The annotation type. This must always be `reply__sys`. |
| `reply_parent__sys` required | The ID of the parent annotation. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H 'Content-Type: application/json' \
-H 'Accept: application/json' \
-d '[
   {
       "document_version_id__sys": "1_0_1",
       "type__sys": "reply__sys",
       "comment__sys": "first reply from the api",
       "placemark": {
           "type__sys": "reply__sys",
           "reply_parent__sys": "54"
       }
   },
   {
       "document_version_id__sys": "1_0_1",
       "type__sys": "reply__sys",
       "color__sys": "green_light__sys",
       "comment__sys": "first reply from the api",
       "placemark": {
           "type__sys": "reply__sys",
           "reply_parent__sys": "55"
       }
   },
   {
       "document_version_id__sys": "1_0_1",
       "type__sys": "reply__sys",
       "comment__sys": "second reply from the api",
       "placemark": {
           "type__sys": "reply__sys",
           "reply_parent__sys": "54"
       }
   }
]'
https://myvault.veevavault.com/api/v26.2/objects/documents/annotations/replies/batch \
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
            "id__sys": "60"
        },
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "1_0_1",
            "global_version_id__sys": "123456_1_1",
            "id__sys": "62"
        },
        {
            "responseStatus": "SUCCESS",
            "document_version_id__sys": "1_0_1",
            "global_version_id__sys": "123456_1_1",
            "id__sys": "61"
        }
    ]
}
```

## Response Details

On SUCCESS, the response includes the document version ID, global version ID, and ID and version of each successfully created reply. See [Create Annotations](/vault-api/api-reference/26.2/documents/document-annotations/create-multiple-annotations) for details. Replies that were not added successfully are reported with an error message.
