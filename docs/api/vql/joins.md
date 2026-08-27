<!-- source: https://general.veevavault.dev/vql/joins/ -->
<!-- title: Joins & Relationships -->

# Joins & Relationships

In VQL, a join is the mechanism used to navigate relationships between objects. Use joins to either expand your results with related data or filter your records based on related object criteria.

Vault’s data model is based on objects that are related to each other through relationships. Navigating these relationships is a fundamental building block of the VQL query that allow you to gather data from different objects. The relationship syntax in VQL allows you to join data using path traversal:

* [Outer joins](/vql/joins/outer-joins): Expands results from the primary query target to add any related data if it exists. If the related data is empty, the primary record is still included.
* [Inner joins](/vql/joins/inner-joins): Filters results from the primary query target using related data. If the related data is empty, the primary record is excluded.

The relationship name identifies the pre-configured join between the two objects.

Learn more about [relationship and join limitations](/vql/joins/relationship-constraints).
