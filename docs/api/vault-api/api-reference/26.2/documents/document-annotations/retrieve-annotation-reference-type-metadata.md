<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/documents/document-annotations/retrieve-annotation-reference-type-metadata/ -->
<!-- title: Retrieve Annotation Reference Type Metadata -->

# Retrieve Annotation Reference Type Metadata

Retrieves the metadata of a specified annotation reference type. Learn more about [reference types](/library/references/about-annotations/#Annotation_References).

GET`/api/{version}/metadata/objects/documents/annotations/references/types/{reference_type}`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{reference_type}` required | The name of the reference type. For example, `permalink__sys`. Learn more about [reference types](/library/references/about-annotations/#Annotation_References). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/objects/documents/annotations/references/types/document__sys \
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": {
        "name": "document__sys",
        "fields": [
            {
                "name": "annotation__sys",
                "type": "String",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "document_version_id__sys",
                "type": "String",
                "system_managed": false,
                "value_set": []
            },
            {
                "name": "type__sys",
                "type": "String",
                "system_managed": true,
                "value_set": [
                    "document__sys"
                ]
            }
        ]
    }
}
```

## Response Details

On `SUCCESS`, the response includes a list of annotations of the specified type(s) for the document version. Each Annotation object may include some or all of the following fields depending on type:

| Field | Description |
| --- | --- |
| `annotation__sys` | Document-type references only. The ID of the referenced anchor annotation, or null for references to an entire document. |
| `document_version_id__sys` | Document-type references only. The ID and version number of the referenced document in the format `{documentId}_{majorVersion}_{minorVersion}`. For example, `138_2_1`. |
| `permalink__sys` | Permalink-type references only. The ID of the referenced permalink. |
| `url__sys` | External-type references only. The URL of the external reference. Allows up to 32,000 characters. |
