<!-- source: https://general.veevavault.dev/vql/operators/operator-limitations/ -->
<!-- title: Operator Limitations -->

# Operator Limitations

This section provides limitations on operators when used with certain fields and objects.

## Multi-Value Picklist Fields in Raw Objects

Queries on multi-value picklists in raw objects support a maximum of five (5) AND operators.

The following operators are not supported: `>`, `<`, `>=`, `<=`.

You cannot combine `AND` and `OR` operators on the same multi-value picklist field. For example, the following expression is not valid:

Copy to clipboard

```
WHERE department__c = 'clinical_operations__c' AND department__c = 'biostatistics__c' OR department__c = 'it__c'
```

When querying more than one field, you must use parentheses to group the operations on each field. For example, the following expression is valid:

Copy to clipboard

```
WHERE department__c = 'clinical_operations__c' AND (equipment_type__c = 'mri__c' OR equipment_type__c = 'xray__c')
```

The following expression is not valid:

Copy to clipboard

```
WHERE department__c = 'clinical_operations__c' AND equipment_type__c = 'mri__c' OR equipment_type__c = 'xray__c'
```
