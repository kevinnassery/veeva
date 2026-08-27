<!-- source: https://general.veevavault.dev/vql/functions-options/richtext/ -->
<!-- title: RICHTEXT() -->

# RICHTEXT()

By default, VQL returns only the first 250 characters of a Rich Text field value and does not include HTML markup. In v21.1+, use `RICHTEXT()` in the `SELECT` clause to retrieve the full value of a Rich Text field, including HTML markup.

All retrieval methods return newline characters.

## Syntax

Copy to clipboard

```
SELECT RICHTEXT({field})
FROM {query target}
```

The `{field}` parameter must be the name of a Rich Text field.

## Query Examples

The following are examples of queries using `RICHTEXT()`.

### Query

The following query retrieves the full value of this field with HTML markup:

Copy to clipboard

```
SELECT name__v,
  RICHTEXT(rich_text_field__c) AS RichTextFunction
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
           "RichTextFunction": "<blockquote><p style=\"text-align: left;\">A two-hour reduction in sleep per night for one week is associated with a significant reduction in psychomotor performance.</p></blockquote><p><br></p><p>Get a good night's sleep with <b>Veepharm</b>, clinically proven to help you fall asleep faster and stay asleep longer. Ask your doctor if <b>Veepharm&nbsp;</b>is right for you.</p>"
       }
   ]
}
```
