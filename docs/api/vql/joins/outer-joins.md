<!-- source: https://general.veevavault.dev/vql/joins/outer-joins/ -->
<!-- title: Expanding Related Data -->

# Expanding Related Data

An outer join returns all results from the primary query even when there is no data from the subquery. The goal is to expand result data to include data from related sources, if it exists.

In VQL, you can create left outer joins using a subquery in the `SELECT` clause.

* **Subquery**: `SELECT id, (SELECT id FROM inbound_relationship__cr)`
* **Lookup**: `SELECT outbound_relationship__cr.field__c`
