<!-- source: https://general.veevavault.dev/vql/references/language-specifications/data-types-formats/ -->
<!-- title: Data Types & Formats -->

# Data Types & Formats

VQL defines supported data types, standardized date and time formats, and response structures for querying Vault data.

## Date & Time Formats

* `Date` and `DateTime` field values are entered and returned in `UTC` (Coordinated Universal Time), not the user’s time zone.
* The `Date` format is `YYYY-MM-DD`. For example: `'2016-01-16'`.
* The `Date` format assumes a time of midnight on the specified date (`00:00:00`).
* The `DateTime` format is `YYYY-MM-DDTHH:MM:SS.SSSZ`. For example: `'2016-01-15T07:30:00.000Z'`.
* The `DateTime` format must end with the `.000Z` `UTC` expression. The zeros may be any number.
* `Dates` and `DateTimes` must be surrounded by single quotes in the query string.

## Field Type Specifications

[Link to Explanations > Querying Specific Field Types]

| Field Type | Specification / Constraint | Return Format |
| --- | --- | --- |
| Long Text | Wildcard (`*`) searching on spaces is not supported. | String |
| Rich Text | Default return is 250 characters. Supports up to 32,000 plaintext characters. | String (with HTML) |
| Formula | Evaluated at runtime. Not searchable, cannot be used with `FIND`, `ORDER BY`, or `WHERE`. | Value or `null` |
| Lookup | `ORDER BY` and `WHERE` only supported for searchable lookups. | Read-only Value |
| Currency | Includes trailing decimal places based on currency type. | String (e.g., `"$10.00"`) |

## Response Formats

* Vault queries support both JSON and XML response formats.
* JSON (`application/json`) is the default response format.
* To request an XML response, set the `HTTP` Request Header `Accept` to `application/xml`.
