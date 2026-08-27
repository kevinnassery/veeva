<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/errors/ -->
<!-- title: Errors -->

# Errors

The response of every API call includes a field called `responseStatus`. Possible values are:

* `SUCCESS` - The API request was successfully processed.
* `WARNING` - The API request was successfully processed, but with warnings.
* `FAILURE` - The API request could not be processed because of user error.
* `EXCEPTION` - The API request could not be processed because of system error.

For a `responseStatus` other than `SUCCESS`, users can inspect the `errors` field in the response. Each `error` includes the following fields:

* `type` - The specific type of error, e.g., `INVALID_DATA`, `PARAMETER_REQUIRED`, etc. See below for a full list of `types`. These values are not subject to change for a given version of the API, even when newer versions of the API are available.
* `message` - The message accompanying each error type, e.g., `Missing required parameter [{field_name}]`. When available, the error message includes the specific reason, e.g., the `{field_name}` for the error. These messages are subject to change and are not contractual parts for error handling. Developers should consider error messages for debugging and troubleshooting purposes only and should not implement application logic which relies on specific error strings or formatting.

When Vault processes an API request, it returns an HTTP response status code of 200. If Vault returns a response status code other than 200, it is likely due to connectivity problems, and we recommend contacting your network team. We recommend basing your logic on the `responseStatus` field and error types, not on the HTTP response status codes.

#### Example: Failed Authentication

Copy to clipboard

```
{
    "responseStatus": "FAILURE",
    "errors": [
        {
            "type": "NO_PASSWORD_PROVIDED",
            "message": "No password was provided for the login call."
        }
    ],
    "errorType": "AUTHENTICATION_FAILED"
}
```
