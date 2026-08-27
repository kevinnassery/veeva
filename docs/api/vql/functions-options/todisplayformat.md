<!-- source: https://general.veevavault.dev/vql/functions-options/todisplayformat/ -->
<!-- title: TODISPLAYFORMAT() -->

# TODISPLAYFORMAT()

By default, object queries return the field’s raw value even if the field configuration uses a format mask expression. VQL also pads number field values to the configured precision instead of the user-entered value. For example, an object query might return “1.20000” instead of the user-entered “1.2” that is displayed in the Vault UI.

In v23.2+, use the `TODISPLAYFORMAT()` function with `SELECT` to return the field value as formatted by the configured format mask expression.

When a field does not have a format mask expression:

* In v23.2 to v25.2, `TODISPLAYFORMAT()` returns an error.
* In v25.3, `TODISPLAYFORMAT()` returns text and number field values as they are displayed in the Vault UI. Number field values reflect what the user entered, including any trailing zeroes. Number field values are not localized.
* In v26.1+, `TODISPLAYFORMAT()` returns text, number, percent and currency field values as they are displayed in Vault UI, including localization.

The `TODISPLAYFORMAT()` function is available for all text and number fields that support format masks. Learn more about format masks in [Vault Help](https://platform.veevavault.help/en/lr/15057#Format_Masks).

As of v26.1+ `TODISPLAYFORMAT()` function is available for raw objects.

Note

The [`queryDescribe`](/vql/references/vql-api-headers#Query_Describe) object includes the `format_mask` expression if a format mask exists on the field.

## Syntax

Copy to clipboard

```
SELECT TODISPLAYFORMAT({field})
FROM {query target}
```

The `{field}` parameter must be the name of a field that supports format masks.

## Query Examples

The following are examples of queries using `TODISPLAYFORMAT()`.

### Query

The following query returns both the raw value and the formatted value of the *Phone* field on all *Person* records:

Copy to clipboard

```
SELECT id, phone__c, TODISPLAYFORMAT(phone__c) AS phone_formatted
FROM person__sys
```

### Response

Copy to clipboard

```
{
   "responseStatus": "SUCCESS",
   "responseDetails": {
       "pagesize": 1000,
       "pageoffset": 0,
       "size": 1,
       "total": 1
   },
   "data": [
       {
           "id": "V0D000000001002",
           "phone__c": "5551234567",
           "phone_formatted": "(555) 123-4567"
       }
   ]
}
```
