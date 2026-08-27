<!-- source: https://general.veevavault.dev/vql/functions-options/longtext/ -->
<!-- title: LONGTEXT() -->

# LONGTEXT()

By default, VQL returns only the first 250 characters of a Long Text field value and does not include HTML markup. In v17.1+, use `LONGTEXT()` in the `SELECT` clause to retrieve the full value of a Long Text field. You can also use `LONGTEXT()` to retrieve the full value of a Rich Text field without HTML markup.

All retrieval methods return newline characters.

## Syntax

Copy to clipboard

```
SELECT LONGTEXT({field})
FROM {query target}
```

The `{field}` parameter must be the name of a Long Text or Rich Text field.

## Query Examples

The following are examples of queries using `LONGTEXT()`.

### Query

The following VQL query returns both the first 250 characters of this field and the full value without markup:

Copy to clipboard

```
SELECT name__v,
 rich_text_field__c,
 LONGTEXT(rich_text_field__c) AS LongTextOnRich
FROM campaign__c
WHERE name__v = 'Veepharm Marketing Campaign'
```

### Response

Copy to clipboard

```
{
"data": [
       {
           "name__v": "Veepharm Marketing Campaign",
           "rich_text_field__c": "A two-hour reduction in sleep per night for one week is associated with a significant reduction in psychomotor performance.\n\nGet a good night's sleep with Veepharm, clinically proven to help you fall asleep faster and stay asleep longer. Ask your",
           "LongTextOnRich": "A two-hour reduction in sleep per night for one week is associated with a significant reduction in psychomotor performance.\n\nGet a good night's sleep with Veepharm, clinically proven to help you fall asleep faster and stay asleep longer. Ask your doctor if Veepharm is right for you."
       }
   ]
}
```
