<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/create-upsert-object-records/ -->
<!-- title: Create & Upsert Object Records -->

# Create & Upsert Object Records

Create or [upsert](#Upsert_Object_Records) Vault object records in bulk.

You can use this endpoint to create User Tasks or User (`user__sys`) records. Learn more about [User Tasks](https://platform.veevavault.help/en/gr/40757) and the [User & Person Objects](https://platform.veevavault.help/en/gr/46534) in Vault Help.

* The maximum input file size is 50 MB.
* The values in the input must be UTF-8 encoded.
* CSVs must follow the standard RFC 4180 format, with some [exceptions](/vault-api/references/csv-rfc-deviations).
* Vault removes XML characters that fall outside of the [character range](https://www.w3.org/TR/xml/#charsets) from the request body.
* The maximum batch size is 500.

You can only add [relationships on object fields](#Relationships_Object_Fields) using ID values or based on a unique field on the target object. This API does not support [object lookup fields](https://developer.veevavault.com/vql/#Object_Lookup_Fields).

If a `raw` object record encounters a [uniqueness constraint error](https://platform.veevavault.help/en/gr/28740/#defining-uniqueness-in-relationship-objects), the entire batch fails. A `raw` object is a Vault object where the `data_store` attribute is set to `raw`.

POST`/api/{version}/vobjects/{object_name}`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `text/csv` or `application/json` |
| `Accept` | `application/json` (default) or `text/csv` |
| `X-VaultAPI-MigrationMode` | If set to `true`, Vault allows you to create or update object records in a noninitial state and with minimal validation, create inactive records, and set standard and system-managed fields such as `created_by__v`. Does not bypass record triggers. Vault does not send notifications in Record Migration Mode. You must have the Record Migration permission to use this header. Learn more about [Record Migration Mode in Vault Help](https://platform.veevavault.help/en/gr/761685). |
| `X-VaultAPI-NoTriggers` | If set to `true` and Record Migration Mode is enabled, it bypasses all system, standard, custom SDK triggers, and Action Triggers. Before using this parameter, learn more about [bypassing triggers](https://platform.veevavault.help/en/gr/761685#no-triggers). |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{object_name}` | The name of the object, for example, `product__v`. |

## Body Parameters

Upload parameters as a JSON or CSV file. The following shows the required standard fields, but an Admin may set other standard or custom object fields as required in your Vault.

If an object has a field default configured, the value you use for that field overrides the default. Learn more about the [order of operations for field defaults in Vault Help](https://platform.veevavault.help/en/gr/42778/#order-of-operations-for-object-field-defaults).

| Name | Description |
| --- | --- |
| `name__v` required | This field is required unless it is set to system-managed. To find out if an object uses system-managed naming, retrieve its `name__v` field and look for the `system_managed_name` property set to `true` or `false`. Learn more about system-managed naming in [Vault Help](https://platform.veevavault.help/en/gr/30986). |
| `object_type__v` optional | To create objects of a specific object type, add this field with the `id` of the object type. Requests may include either `object_type__v` or `object_type__v.api_name__v`, but not both. |
| `object_type__v.api_name__v` optional | To create objects of a specific object type, add this field with the `name` of the object type. Requests may include either `object_type__v` or `object_type__v.api_name__v`, but not both. |
| `source_record_id` optional | To copy an existing object record, add this field with the `id` of the existing object record. Any values specified for other fields will override the copied values. To perform a deep (hierarchical) copy of a record, see the [Deep Copy](/vault-api/api-reference/26.2/vault-objects/deep-copy-object-record) endpoint. |
| `{field_name}` optional | The name of the object field for which to specify a value. Use the [Object Metadata API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata) to retrieve all fields configured on objects. You can specify a value for any field with `editable: true`. |
| `state__v` optional | Specifies the lifecycle state of the record when `X-VaultAPI-MigrationMode` is set to `true`. For example, `draft_state__c`. |
| `state_label` optional | Specifies the lifecycle state type of the record when `X-VaultAPI-MigrationMode` is set to `true`. Use the format `base:object_lifecycle:` followed by the object state type. For example, `base:object_lifecycle:initial_state_type`. When providing both a state and state type, the `state_label` value must map to the provided `state__v` value. For example, if the `state__v` value is set to `draft_state__c`, the `state_label` value must already be set to draft in the destination Vault. |

## Add Relationships on Object Fields

Many object records have relationships with other object records. For example, the object record details for the *Marketing Campaign* "CholeCap Campaign" references its parent "CholeCap" *Product* record. When creating or upserting object records, there are instances where an object field in your input file indicates an object relationship. The API supports the use of reference relationships and parent-child relationships within fields, but not lookup fields. To refer to object relationships in an object field, set the column header in the input file to be a combination of the relationship name and a unique object field, such as `name__v`. For example, `product__vr.name__v` references the name of the related *Product* record.

## Add Attachment Fields

To specify a value for an *Attachment* field, provide the file path on file staging.

The maximum allowed file size for *Attachment* fields is 100 MB.

## Upsert Object Records

Upsert is a combination of create and update. With `idParam`, you can identify an object record by any unique object field.
This allows you to use one input file to create new object records and update existing records at the same time.
If a matching record exists, Vault updates the record with the unique field values specified in the input.
If no matching object record exists, Vault creates a new record using the values in the input.

Upsert expects unique `idParam` field values in the request and providing duplicate values will result in a `FAILURE` for the entire batch.

To upsert records in a specific state or state type, use the [Migration Mode](#X-VaultAPI-MigrationMode_header) header. To set or change a record's object type, include `object_type__v` in the body of the request and use the `X-VaultAPI-MigrationMode` header. Without Migration Mode enabled, update operations for individual records that indicate `object_type__v` will fail. Records can indicate `object_type__v` if the provided value matches the existing value in Vault.

### Query String Parameters

| Name | Description |
| --- | --- |
| `idParam` | To upsert object records, add `idParam={field_name}` to the request endpoint. For example, `idParam=external_id__v`. You can use any object field which has `unique` set to `true` in the object metadata. For example, `idParam=external_id__v`. |

[Download Input File](/sample-files/bulk-create-object-records.json)

Admin may set other standard or custom object fields to required. Use the Object Metadata API to retrieve all fields configured on objects. You can add any object field with `editable: true`.

Vault does not update records and includes a `responseStatus` of `WARNING` for operations that result in saving a record without making any changes. Learn more about record changes that result in no operation ([no-ops](/vault-api/api-reference/26.2/vault-objects/update-object-records/#No_Ops)).

## Create User Object Records

To create `user__sys` records, your input file must have all required fields on `user__sys`. You can choose to create new users in pending state and defer welcome emails by setting `activation_date__sys` to a future date.

Use the [Retrieve Object Metadata](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata) endpoint on `user__sys` to retrieve a full list of fields.

This API does not support the following:

* Creating cross-domain users. To create cross-domain users, use the [Create Single User](/vault-api/api-reference/26.2/users/create-users/create-single-user) endpoint.
* Adding users to a domain without assigning them to a Vault. To add users to a domain only, use the [Create Single User](/vault-api/api-reference/26.2/users/create-users/create-single-user) endpoint.
* Adding VeevaID users. To add VeevaID users, use the [Create Single User](/vault-api/api-reference/26.2/users/create-users/create-single-user) endpoint.
* Changing user passwords.

### Body Parameters

Provide the following fields in your input file to create `user__sys` records:

| Name | Description |
| --- | --- |
| `email__sys` required | The user’s email address. For example, `ewoodhouse@email.com` An email address is required to prevent adding duplicate users in error. For example, users John and Jane Smith may both use “jsmith” as a user name. An email address ensures adding the correct user. |
| `first_name__sys` required | The user's first name. |
| `last_name__sys` required | The user's last name. |
| `username__sys` required | The user’s Vault user name (login credential). `username__sys` is a multi-part field. To set the user name, provide the entire value. For example, `ewoodhouse@veepharm.com`. |
| `language__sys` required | The user's preferred language. |
| `locale__sys` required | The user's location. |
| `timezone__sys` required | The user's time zone. |
| `license_type__sys` optional | The user’s license type. If omitted, the default value is `full__v`. If your Vault utilizes user-based licensing, assign application licensing using the fields starting with `license_` on the *User* (`user__sys`) object obtained from the [Retrieve Object Metadata](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata) endpoint. For example, `license_qualityqdocs__sys` indicates the QualityDocs application license. |
| `security_profile__sys` required | The user’s security profile. |
| `status__v` optional | The status of the user. |
| `source_person_id__v` optional | The person record to be associated with this user. This field is only available in Clinical Operations Vaults. See [Managing the Person & Organization Objects](https://clinical.veevavault.help/en/gr/31637) for more information. |
| `activation_date__sys` optional | The date the user will first be able to access Vault in `YYYY-MM-DD` format. If excluded, defaults to today’s date. |
| `send_welcome_email__sys` optional | Set to `true` to defer welcome email until user’s account activation date. Set to `false` to send no welcome email. |
| `layout_profile__sys` optional | The ID of the layout profile to assign to the user. |

[Download Input File](/sample-files/vault-create-object-records-sample-csv-input.csv)
[Download Input File](/sample-files/bulk-create-user-objects.json)

Note that when you create, add, or update `user__sys`, Vault synchronizes those changes with `users` across all Vaults to which that user is a member. This includes cross-domain Vaults.

## Request: Create Object Records

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'name__v,object_type__v.api_name__v,
Accutate,base__v
Baccutate,base__v
Caccutate,base__v
Daccutate,base__v' \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v
```

## Response: Create Object Records

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
        {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "0PR0771",
                "url": "api/v8.0/vobjects/product__v/0PR0771",
		        "event": "created__sys"
            }
        },
        {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "0PR0772",
                "url": "api/v8.0/vobjects/product__v/0PR0772",
		        "event": "created__sys"
            }
        },
        {
            "responseStatus": "SUCCESS",
            "data": {
                "id": "0PR0773",
                "url": "api/v8.0/vobjects/product__v/0PR0773",
		        "event": "created__sys"
            }
        },
        {
            "responseStatus": "FAILURE",
            "errors": [
                {
                    "type": "INVALID_DATA",
                    "message": "Error message describing why this object record was not created."
                }
            ]
        }
    ]
}
```

## Request: Upsert Object Records

Copy to clipboard

```
$ curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: text/csv" \
-H "Accept: text/csv" \
--data-raw 'id,name__v
00P00000000M001,Verntorvastatin
00P000000000C01,Kerntorvastatin
00P000000000C02,Zerntorvastatin' \
https://myvault.veevavault.com/api/v26.2/vobjects/product__v?idParam=id
```

## Response: Upsert Object Records

Copy to clipboard

```
{
   "responseStatus":"SUCCESS",
   "data":[
      {
         "responseStatus":"SUCCESS",
         "data":{
            "id":"00P00000000M001",
            "url":"/api/v26.2/vobjects/product__v/00P00000000M001",
            "event":"updated__sys",
            "id_param_value":"00P00000000M001"
         }
      },
      {
         "responseStatus":"SUCCESS",
         "data":{
            "id":"00P000000000C01",
            "url":"/api/v26.2/vobjects/product__v/00P000000000C01",
            "event":"updated__sys",
            "id_param_value":"00P000000000C01"
         }
      },
      {
         "responseStatus":"FAILURE",
         "data":{
            "id_param_value":"00P000000000C02"
         },
         "errors":[
            {
               "type":"INVALID_DATA",
               "message":"Invalid id"
            }
         ]
      }
   ]
}
```

## Response Details

Vault returns a `responseStatus` for the request:

* `SUCCESS`: This request executed with no warnings. Individual records may be failures.
* `WARNING`: When [upserting](#Upsert_Object_Records) records, this request executed with at least one warning on an individual record. Other individual records may be failures.
* `FAILURE`: This request failed to execute. For example, an invalid `sessionId`.

On `SUCCESS` or `WARNING`, Vault returns a `responseStatus` for each individual record in the same order provided in the input. The `responseStatus` for each record can be one of the following:

* `SUCCESS`: Vault successfully updated at least one field value on this record.
* `WARNING`: When [upserting](#Upsert_Object_Records) records, Vault successfully evaluated this record and reported a warning. For example, Vault returns a warning for records that process with no changes ([no-op](/vault-api/api-reference/26.2/vault-objects/update-object-records/#No_Ops)).
* `FAILURE`: This record could not be evaluated and Vault made no field value changes. For example, an invalid or duplicate record ID.

In addition to the record `id` and `url`, the response includes the following information for each record:

| Metadata Field | Description |
| --- | --- |
| `event` | Whether the record was created (`created__sys`) or updated (`updated__sys`). The response does not return an `event` for failed operations. |
| `id_param_value` | The value of the field specified by the `idParam` query parameter if provided in an upsert request. For example, if `idparam=external_id__v`, the `id_param_value` returned is the same as the record's external ID. |

In CTMS Vaults, if you do not specify a milestone record ID when creating a new *Monitoring Event* record, this request automatically creates a new *Milestone* record. However, the response does not return the `id` of the new *Milestone* record. Learn more about [automated CTMS object creation in Vault Help](https://clinical.veevavault.help/en/gr/40009).
