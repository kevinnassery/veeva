<!-- source: https://general.veevavault.dev/vql/references/language-specifications/notation-conventions/ -->
<!-- title: Notation Conventions -->

# Notation Conventions

The conventions in this table should be modified or entered as shown when creating a `VQL` query.

In this document, some elements such as clauses are presented in all caps, but they are not case sensitive in real `VQL` queries. See [Case Sensitivity](/vql/references/language-specifications/syntax-basics) for more information.

| Convention | Description | Examples |
| --- | --- | --- |
| `SELECT` | An element in all caps is a keyword such as a logical operator, query target option, or function. | `SELECT id FROM LATESTVERSION documents` |
| `documents` | An element without parentheses or brackets is a field name, object name, or value. Enter this element exactly as shown. Boolean values (`true` or `false`) and `null` must be in lowercase or you may encounter errors. | `SELECT id FROM documents WHERE name__v = 'USA'`   `SELECT id FROM documents WHERE locked__v = true` |
| `{text}` | Curly braces indicate a variable. Replace both the curly braces and variable text with a value. | `SELECT {field} FROM {query target}`   `SELECT name__v FROM product__v` |
| `'{text}'` | Single quotation marks surrounding a variable indicate a string value. Replace the curly braces and variable text with a value inside the single quotation marks. | `WHERE {field} = '{value}'`   `WHERE name__v = 'USA'` |
| `FUNCTION()` | An element in all caps with parentheses is a function. For readability, the function name may not indicate whether a parameter is required. Refer to [syntax information](/vql/functions-options) for the required parameter. | The `STATETYPE()` function   `WHERE state__v = STATETYPE('{state_type_name}')` |
| `|` | The pipe character separates alternative elements. Enter only one of these elements. | `ORDER BY id ASC|DESC` |
