<!-- source: https://general.veevavault.dev/vql/joins/inner-joins/ -->
<!-- title: Filtering Related Data -->

# Filtering Related Data

The goal of an inner join in VQL is to filter out results when a related record does not exist. In VQL, you can create inner joins in the `WHERE` clause, either with a subquery using the `IN` operator or using a lookup. If a primary record has at least one related record that matches the join criteria, VQL includes it in the result set.

* **Subquery**: `WHERE id IN (SELECT id FROM inbound_relationship__cr)`
* **Lookup**: `WHERE outbound_relationship__cr.field__c = 'value'`
