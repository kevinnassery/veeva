<!-- source: https://general.veevavault.dev/vql/references/language-specifications/syntax-basics/ -->
<!-- title: Syntax Basics -->

# Syntax Basics

To write valid VQL queries, you must adhere to specific lexical rules regarding case sensitivity and the handling of special characters. This section defines the ground rules for how the VQL parser interprets your query string.

## Case Sensitivity

The following table shows which parts of a VQL query are case sensitive.

**Note**: In v14.0+, you can use the `CASEINSENSITIVE({field})` function to bypass case sensitivity.

| Category | Specification |
| --- | --- |
| **VQL Keywords** | **Case insensitive**. You can enter `SELECT`, `FROM`, and `WHERE` in upper or lowercase. We use uppercase as a convention in this documentation. |
| **Field & Object Names** | **Case sensitive**. You must enter field and object names such as `name__v`, `documents`, and `product__v` in lower-case. This does not apply to the `id` field name on `documents` (only), which may be entered as `id` or `ID`. Older API versions include some mixed-case field names. Retrieve field names to confirm correct formatting. |
| **Field Values** | **Case sensitive**. By default, all field values are case sensitive. This applies to all field type values and picklist values. For example, using the filter `name__v = 'cholecap'` (where `name__v` is a `String` field type) returns no results if the field value is Cholecap. |

## Special Characters

Several escape sequences for special characters are supported on all document fields, object fields, and other VQL endpoints.

| Name | Escape Sequence | Behavior When Unescaped |
| --- | --- | --- |
| Backslash () | `\\` | Returns error unless used in escape sequence |
| Single quote (') | `\'` or `''` (two single quotes) | Creates query string |
| Double quote (") | `\"` | Creates exact match query in `FIND` clause and literal " elsewhere |
| Percent sign (%) | `\%` | Acts as wildcard in `LIKE` clause and literal % elsewhere |
| Asterisk (\*) | `\*` | Acts as wildcard in `FIND` clause and literal \* elsewhere |
| Line feed | `\n` | Literal n |
| Tab | `\t` | Literal t |
| Carriage return | `\r` | Literal r |

Prior to v21.3, escape characters were not standardized and may behave differently.

## Vault Tokens

You can include Vault tokens in queries made using API v22.2+. Vault resolves tokens in the query response. Vault API does not support Custom tokens.

Tokens must be formatted as `${Vault.my_token__c}`.

Vault does not resolve tokens when they are wrapped in single quotes.
