<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/object-page-layouts/ -->
<!-- title: Object Page Layouts -->

# Object Page Layouts

Object page layouts are defined at the object or object-type level and control the information displayed to a user on the object record detail page. Objects that include multiple object types can define a different layout for each type. Learn more about [configuring object page layouts in Vault Help](https://platform.veevavault.help/en/gr/26387).

The page layout APIs consider the authenticated user’s permissions, so fields which are hidden from the authenticated user will not be included in the API response. For example, field-level security, object controls, and other object-level permissions are considered. Record-level permissions such as atomic security are not considered. Layout rules are not applied, but instead have their configurations returned as metadata. Both active and inactive fields are included in the response.
