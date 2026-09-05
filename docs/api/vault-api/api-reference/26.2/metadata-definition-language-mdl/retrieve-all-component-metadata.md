<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/metadata-definition-language-mdl/retrieve-all-component-metadata/ -->
<!-- title: Retrieve All Component Metadata -->

# Retrieve All Component Metadata

Retrieve metadata of all component types in your Vault.

GET`/api/{version}/metadata/components`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml` |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/metadata/components
```

## Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "data": [
       {
           "url": "/api/v26.2/metadata/components/Securityprofile",
           "name": "Securityprofile",
           "class": "metadata",
           "abbreviation": "SPR",
           "active": true,
           "label": "Security Profile",
           "label_plural": "Security Profile"
       },
       {
           "url": "/api/v26.2/metadata/components/Tab",
           "name": "Tab",
           "class": "metadata",
           "abbreviation": "TAB",
           "active": true,
           "label": "Tab",
           "label_plural": "Tab",
           "vobject": "vof_tab__sys"
       }
   ]
}
```

## Response Details

On `SUCCESS`, the response may include the following for each component type in the currently authenticated Vault:

| Name | Description |
| --- | --- |
| `url` | URL to retrieve metadata for the component type. |
| `name` | The component type name as used in MDL commands. |
| `class` | The class of the component type, either `code` for component types that include SDK source code, or `metadata` for component types that do not include SDK source code. |
| `abbreviation` | The abbreviated component type name. |
| `label` | The component type label as it appears in the Vault UI. |
| `label_plural` | The plural component type label as it appears in the Vault UI. |
| `cacheable` | Indicates whether or not the component type has a cache. |
| `cache_type_class` | Indicates the caching strategy used by the component type. If `cacheable` is set to `false`, Vault ignores this value. |
| `vobject` | The associated Vault object, if applicable. |
