<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-query-language-vql/submitting-a-query/ -->
<!-- title: Submitting a Query -->

# Submitting a Query

Retrieve and filter Vault data using a VQL query.

POST`/api/{version}/query`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |
| `Content-Type` | `application/x-www-form-urlencoded` or `multipart/form-data` |
| `X-VaultAPI-DescribeQuery` | Set to `true` to include static field metadata in the response for the data record. If not specified, the response does not include any static field metadata. This option eliminates the need to make additional API calls to understand the shape of query response data. [Learn More](#DescribeQuery_Header). |
| `X-VaultAPI-RecordProperties` | Optional: If present, the response includes the record properties object. Possible values are `all`, `hidden`, `redacted`, and `weblink`. If omitted, the record properties object is not included in the response. [Learn more](#RecordProperties_Header). |
| `X-VaultAPI-DocumentProperties` | Optional: If present, the response includes the document properties object. The only possible value is `all`. If omitted, the document properties object is not included in the response. [Learn more](#DocumentProperties_Header). |

## Body Parameters

| Name | Description |
| --- | --- |
| `q` required | A VQL query of up to 50,000 characters, formatted as `q={query}`. For example, `q=SELECT id FROM documents`. Note that submitting the query as a query parameter instead may cause you to exceed the maximum URL length. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "X-VaultAPI-DescribeQuery: true" \
-H "Content-Type: application/x-www-form-urlencoded" \
-H "Accept: application/json" \
--data-urlencode "q=SELECT id, name__v FROM documents WHERE product__v = ‘cholecap’"
https://myvault.veevavault.com/api/v26.2/query
```

## Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "queryDescribe": {
       "object": {
           "name": "documents",
           "label": "documents",
           "label_plural": "documents"
       },
       "fields": [
           {
               "type": "id",
               "required": true,
               "name": "id"
           },
           {
               "label": "Name",
               "type": "String",
               "required": true,
               "name": "name__v",
               "max_length": 100
           }
       ]
   },
   "responseDetails": {
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 5,
       "total": 5
   },
   "data": [
       {
           "id": 72,
           "name__v": "Cholecap-2021-brochure"
       },
       {
           "id": 63,
           "name__v": "Cholecap - Multisequence"
       },
       {
           "id": 36,
           "name__v": "Cholecap Study"
       },
       {
           "id": 25,
           "name__v": "Clinical Trial Reference"
       },
       {
           "id": 24,
           "name__v": "Formulary Guidelines"
       }
   ]
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

| Name | Description |
| --- | --- |
| `pagesize` | The number of records displayed per page. This can be modified. [Learn more](/vql/clauses/pagesize). |
| `pageoffset` | The records displayed on the current page are offset by this number of records. [Learn more](/vql/references/query-performance-best-practices#Paginating_Results). |
| `size` | The total number of records displayed on the current page. |
| `total` | The total number of records found. |
| `previous_page` | The Pagination URL to navigate to the previous page of results. This is not always available. [Learn more](/vql/references/query-performance-best-practices#Paginating_Results). |
| `next_page` | The Pagination URL to navigate to the next page of results. This is not always available. [Learn more](/vql/references/query-performance-best-practices#Paginating_Results). |
| `data` | The set of field values specified in the VQL query. |

#### About the X-VaultAPI-DescribeQuery Header

When you include the `X-VaultAPI-DescribeQuery` header and set it to `true`, the query response includes query metadata, including the query `type`:

| Name | Description |
| --- | --- |
| `type` | The type of query: `select__sys`, `show_targets__sys`, `show_fields__sys`, or `show_relationships__sys` |

The response also includes the following static metadata description. These values are `null` for `SHOW TARGETS` (`show_targets__sys`) queries.

| Name | Description |
| --- | --- |
| `name` | The name of the queryable object. |
| `label` | The label of the queryable object. |
| `label_plural` | The plural label of the queryable object. |

The field metadata may include some or all of the following:

| Metadata Field | Description |
| --- | --- |
| `name` | The name of the field. |
| `label` | The UI label of the field. |
| `type` | The data type, for example, `String` or `Number` |
| `max_length` | The max length of a string field. |
| `max_value` | The max value of a number field. |
| `min_value` | The minimum value of a number field. |
| `scale` | The number of digits after a decimal point in a number field. |
| `required` | Indicates whether the field is required (`true`/`false`). |
| `unique` | Indicates whether the value must be unique (`true`/`false`). |
| `status` | Indicates whether the field is active (`active`/`inactive`). |
| `picklist` | The picklist name field value. |
| `encrypted` | Indicates whether the *Contains Protected Health Information (PHI) or Personally Identifiable Information (PHI)* setting is selected for this field (`true`/`false`). Learn more in [Vault Help](https://platform.veevavault.help/en/gr/15057#protected-info). |
| `format_mask` | The format mask expression if it exists. Learn more about format masks in [Vault Help](https://platform.veevavault.help/en/gr/15057#format-masks). |
| `function` | The function name if the VQL query applies a [function](/vql/functions-options) to this field. |
| `alias` | If `true`, the VQL query applies an [alias](/vql/clauses/as) to this field. Omitted if `false`. |

**Note:** For formula fields, `queryDescribe` should describe the field as specified in the metadata, excluding the `formula` attribute.

#### About the X-VaultAPI-RecordProperties Header

When you include the [`X-VaultAPI-RecordProperties` header](/vql/references/vql-api-headers#Record_Properties), the query response includes the `record_properties` object. The `record_properties` object describes the properties of a data record. If set to `all`, the response includes for each record:

| Name | Description |
| --- | --- |
| `id` | The record ID. |
| `field_properties` | Includes arrays of `hidden`, editable (`edit`), and `redacted` fields. To return only hidden or redacted fields, set the `X-VaultAPI-RecordProperties` header to `hidden` or `redacted`, respectively. |
| `permissions` | Includes whether this record has `read`, `edit`, `create`, and `delete` permissions. |
| `subquery_properties` | Includes an array of hidden subquery relationships for this record. |
| `field_additional_data` | Includes configuration data for `link` type formula fields. To return only this data, set the `X-VaultAPI-RecordProperties` header to `weblink`. |

For each field, the `field_additional_data` metadata includes the name of the field and the `web_link` object, which contains the following metadata:

| Metadata Field | Description |
| --- | --- |
| `label` | The text that appears as a link in the Vault UI. |
| `target` | Determines whether the link will open in a `new_window` or the `same_window`. |
| `connection` | Populates another Vault's DNS within the URL utilizing a configured `connection__sys` object record. |

#### About the X-VaultAPI-DocumentProperties Header

When you include the [`X-VaultAPI-DocumentProperties` header](/vql/references/vql-api-headers#Document_Properties), the query response includes the `document_properties` object describing the properties of a document. If set to `all`, the response includes for each document:

| Name | Description |
| --- | --- |
| `id` | The document ID. |
| `document_version` | The specific version of the document. |
| `permissions` | Includes boolean flags for all lifecycle state permissions the querying user has for this document. |
| `field_properties` | Includes arrays of the editable (`edit`) and read-only fields included in the query. |

#### About the X-VaultAPI-Facets Header

When you include the `X-VaultAPI-Facets` header with a list of facetable fields, the response includes the `facets` object containing the count of unique values for each facetable field. Determine which fields are facetable using the [Retrieve Object Metadata API](/vault-api/api-reference/26.2/vault-objects/retrieve-object-metadata). For each facetable field included in the header, the response includes:

| Name | Description |
| --- | --- |
| `label` | The label for the facetable field in the Vault UI. |
| `type` | The field’s data type. |
| `name` | The name of the facetable field. |
| `count` | The number of unique values for this field in the Vault. |
| `truncated_list` | A boolean indicating that the list is truncated because it contains more than 50 values. |

The `values` metadata contains the unique values for the facetable field in the Vault, sorted first by `result_count` and secondly by `value`.

| Metadata Field | Description |
| --- | --- |
| `value` | A value of this facetable field in the Vault. For example, `ophthalmology__c`. |
| `result_count` | The number of records with this field value in the Vault. |
