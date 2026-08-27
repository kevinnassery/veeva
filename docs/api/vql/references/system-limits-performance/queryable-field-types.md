<!-- source: https://general.veevavault.dev/vql/references/system-limits-performance/queryable-field-types/ -->
<!-- title: Queryable Field Types -->

# Queryable Field Types

This section provides information on queryable field types and their limitations.

## Long Text Field Type

As of v17.1, the LongText field type allows users to enter text Strings up to 32,000 characters. While a FIND clause always searches the entire field, other queries will only return the first 250 characters of a LongText field by default. To return all of the characters, use the [`LONGTEXT()` function](/vql/functions-options/longtext/).

Note that VQL only supports SELECT clauses with LONGTEXT() function.

Copy to clipboard

```
SELECT id, LONGTEXT(long_text_field__c)
FROM object__c
LongText fields do not support wildcard (*) searching on spaces. For example, when trying to match on “Vault Query Language” in a LongText field, the following finds no results:
```

Copy to clipboard

```
SELECT id
FROM longtext_obj__c FIND('Vault*Language' SCOPE long_text_field__c)
```

## Rich Text Field Type

As of v21.1, the RichText field type allows users to enter text Strings up to 32,000 plaintext characters, with an additional 32,000 characters reserved for HTML markup. For example, **Hello** is 5 plaintext characters and 7 HTML markup characters.

Vault does not support all HTML tags and attributes in Rich Text fields. Learn more about [supported HTML for Rich Text](/vault-api/guides/understanding-metadata/#RichTextAPI).

Using `FIND` on a Rich Text field only searches the text, not the HTML markup. While a `FIND` clause does search the entire text without markup, other queries will only return the first 250 characters of a Rich Text field by default. To return all of the characters, use the [RICHTEXT() function](/vql/functions-options/richtext/).

## Formula Fields

A formula field calculates the field-value based on a formula entered during field configuration. VQL allows you to query formula fields for [custom and standard objects](https://platform.veevavault.help/en/gr/44478).

Querying a non-object formula field returns an error.
Formula fields are not searchable and are not stored, and thus cannot be used with `FIND`, `ORDER BY`, and `WHERE` clauses. Since the formulas are evaluated during runtime, if there is an error calculating the formula, null is returned for the field value.

## Lookup Fields

A lookup field contains a read-only value that is populated from a field on a parent or referenced object. VQL allows you to query lookup fields, but `ORDER BY` and `WHERE` only support searchable lookup fields. Learn more about [lookup fields in Vault Help](https://platform.veevavault.help/en/gr/34072).

## Currency Fields

With the currency field type, users can configure currency fields on a Vault object. In addition to primary currency, Vault supports a corporate currency.

When querying currency fields, Vault always includes trailing decimal places. For example, if a USD currency field value was entered by a user as $10, VQL returns $10.00 as a String. The number of trailing decimal places depends on the currency.

To retrieve corporate currency fields, you must use `{field name}_corp__sys` to retrieve the corporate currency numeric value.

For example, the following query returns a result with the numeric value of the `market_value_corp__sys` field with for a list of active products.

Copy to clipboard

```
SELECT name__v, market_value_corp__sys
FROM product__v
WHERE status__v = 'active__v'
```

## Number Fields

In VQL versions v21.2+, VQL displays number fields based on the field’s configured Decimal places. If a user enters 10.00 and the number field is configured with Decimal places of 1, VQL returns 10.0. Likewise, if Decimal places is 0, VQL returns 10. If Decimal places is 9, VQL returns 10.000000000, and so on.

Decimal places are configured by your Vault Admin, and can be different for each unique field. For example, the same document can have multiple number fields each with a different configuration for Decimal places.

### Previous Version Behavior

In previous versions of VQL, Number fields have slightly different behavior when displaying decimal places, depending both on your VQL version and the type of data you’re querying.

v20.3 - v21.1
For document queries, VQL displays number fields exactly as the user entered them. If a user enters 10.00, VQL returns 10.00.

For object record queries, VQL displays number fields based on the field’s configured Decimal places. If a user enters 10.00 and the number field is configured with Decimal places of 1, VQL returns 10.0. Likewise, if Decimal places is 0, VQL returns 10. if Decimal places is 9, VQL returns 10.000000000, and so on.

v20.1 - v20.2
VQL displays number fields exactly as the user entered them. If a user enters 10.00, VQL returns 10.00.

v19.3 and Below
VQL truncates trailing zeros on number fields. If a user enters 10.00, VQL returns 10.

## Yes/No Fields

You can use boolean (true or false) field values to filter documents and objects by a Yes/No field. Enter true for 'Yes’ and false for 'No’. For example, the following query retrieves the ID and name of all documents where the CrossLink field is set to ‘Yes’:

Copy to clipboard

```
SELECT id, name__v
FROM documents
WHERE crosslink__v = true
```

## Bitmask Fields

In v26.2+, the Bitmask field type allows for efficient filtering of object records at high volume. Bitmask fields are system-defined and can be created by Veeva only.

Bitmask fields on raw objects support the [bitwise `AND` (`&`) operator](/vql/operators/logical-operators#Bitwise_AND); no other field types can use this operator.
