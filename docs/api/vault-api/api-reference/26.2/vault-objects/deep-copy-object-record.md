<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/deep-copy-object-record/ -->
<!-- title: Deep Copy Object Record -->

# Deep Copy Object Record

Deep Copy copies an object record, including all of the record’s related child
and grandchild records. Each deep (hierarchical) copy can copy a maximum of
10,000 related records at a time.

See [Copying Object Records](https://platform.veevavault.help/en/gr/32218) for details on required access permissions.

Note

You can perform a regular copy of an object record using the [Create & Upsert Object Records](/vault-api/api-reference/26.2/vault-objects/create-upsert-object-records) endpoint with the `source_record_id` field.

POST`/api/{version}/vobjects/{object_name}/{object_record_ID}/actions/deepcopy`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/json` or `text/csv` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the parent object to copy. For example, `product__v`. |
| `{object_record_ID}` | The ID of the specific object record to copy. |

#### Body

In the request body, you can include field names to override field values in
the source record. For example, including `external_id__v` removes the
field value in the copy while leaving the source record unchanged.

If the input is formatted as CSV, only a single data line is accepted. If the
input is formatted as JSON, only one in the list is accepted.

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/json" \
--data-raw '[
    {
        "name__v":"Copied record 1",
        "external_id__v":""
    }
]' \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v/00P000000000202/actions/deepcopy
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "job_id": 26001,
  "url": "/api/v26.2/services/jobs/26001"
}
```
