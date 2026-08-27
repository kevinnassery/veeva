<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/roll-up-fields/ -->
<!-- title: Roll-up Fields -->

# Roll-up Fields

You can configure up to 25 Roll-up fields on a parent object to calculate the minimum, maximum, count, or sum of source field values on related child records. [Learn more about Roll-up field calculation in Vault Help](https://platform.veevavault.help/en/gr/15057/#roll-up-fields).

Use the following endpoints to start a full recalculation of all Roll-up fields on a specific object or to check the status of a recalculation. This may be helpful in the following scenarios:

* When you create a new Roll-up field, Vault does not automatically calculate a value for existing parent records.
* When you upload a large number of records using Record Migration Mode, Vault bypasses automatic roll-up calculations.

When performing a full recalculation, Vault evaluates all Roll-up fields on an object asynchronously.

Note

Record triggers on parent records do not fire when Roll-up fields are updated.
