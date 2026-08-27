<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/delete-object-records/ -->
<!-- title: Delete Object Records -->

# Delete Object Records

Delete Object Records in bulk. Admins can also define special deletion rules for objects, which affects how Vault behaves when you attempt to delete an object record. Learn more about [limitations on object record deletion in Vault Help](https://platform.veevavault.help/en/gr/18769#relationships_deletion).

If you need to delete a parent record along with all of its children and grandchildren, use the [Cascade Delete](/vault-api/api-reference/26.2/vault-objects/cascade-delete-object-record) endpoint.

Note that you cannot use this API to delete `user__sys` records. Use the [Update Object Records](/vault-api/api-reference/26.2/vault-objects/update-object-records) endpoint to set the `status__v` field to `inactive`.

* The maximum input file size is 1GB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* The maximum batch size is 500.

DELETE`/api/{version}/vobjects/{object_name}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/json` |
| `Accept` | `application/json` (default) or `text/csv` |
| `X-VaultAPI-MigrationMode` | If set to `true`, Vault deletes records in Record Migration Mode. Does not bypass record triggers. Vault does not send notifications in Record Migration Mode. You must have the Record Migration permission to use this header. Learn more about [Record Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/761685). |
| `X-VaultAPI-NoTriggers` | If set to `true` and Record Migration Mode is enabled, it bypasses all system, standard, custom SDK triggers, and Action Triggers. Before using this parameter, learn more about [bypassing triggers](https://platform.veevavault.help/en/gr/761685#no-triggers). |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object, for example, `product__v`. |

## Body Parameters

Upload parameters as a JSON or CSV file.

Note

Some HTTP clients do not support `DELETE` requests with a
body. As a workaround for these cases, you can simulate this request using the
`POST` method with the `_method=DELETE` query parameter.

| Name | Description |
| --- | --- |
| `id` conditional | The system-assigned object record ID to delete. Not required if providing a unique field identifier (`idParam`) such as `external_id__v`. |
| `external_id__v` conditional | Instead of `id`, you can use this user-defined document external ID. |

## Query Parameters

| Name | Description |
| --- | --- |
| `idParam` | If you're identifying objects in your input by a unique field, add `idParam={fieldname}` to the request endpoint. You can use any object field which has `unique` set to `true` in the object metadata. For example, `idParam=external_id__v`. |

Admin may set other standard or custom object fields to required. Use the Object Metadata API to retrieve all fields configured on objects. You can update any object field with `editable: true`.

## Request

Copy to clipboard

```
curl -X DELETE -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id
00P000000000607
00P00000000O048
00P00000000O078' \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "00P000000000607"
            }
        },
	 {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "00P00000000O048"
            }
        },
	 {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "00P00000000O078"
            }
        }
    ]
}
```

## Response Details

Vault returns a `responseStatus` for the request:

* `SUCCESS`: This request executed with no warnings. Individual records may be failures.
* `FAILURE`: This request failed to execute. For example, an invalid `sessionId`.

On `SUCCESS`, Vault returns a `responseStatus` and record ID for each individual record in the same order provided in the input. The `responseStatus` for each record can be one of the following:

* `SUCCESS`: Vault successfully deleted the record.
* `FAILURE`: This record could not be evaluated and Vault did not delete the object record. For example, an invalid or duplicate record ID.

In addition to the record `id` and `url`, the response includes the following information for each record:

| Metadata Field | Description |
| --- | --- |
| `id_param_value` | The value of the field specified by the `idParam` query parameter if provided in the delete request. For example, if `idparam=external_id__v`, the `id_param_value` returned is the same as the record's external ID. |
