<!-- source: https://general.veevavault.dev/vql/functions-options/attachment-field-functions/ -->
<!-- title: Attachment Field Functions -->

# Attachment Field Functions

By default, queries on *Attachment* fields return the file handle of the attached file. In v24.3+, you can retrieve additional information about *Attachment* fields, including the file name, file size, MIME type, and MD5 checksum. Learn more about [Attachment fields in Vault Help](https://platform.veevavault.help/en/lr/15057#attachment-fields).

## FILENAME()

Use `FILENAME()` with `SELECT`, `WHERE`, `ORDER BY`, and `FIND` to use the *Attachment* field’s file name instead of the file handle in the query.

Note

`FILENAME()` is not supported in queries that use more than one `SCOPE` option.

### Syntax

Copy to clipboard

```
SELECT FILENAME({field})
FROM {query target}
WHERE FILENAME({field}) {operator} {value}
FIND ('{search phrase}' SCOPE FILENAME({field}))
ORDER BY FILENAME({field})
```

The `{field}` parameter must be the name of an *Attachment* field.

## FILESIZE(), MIMETYPE(), & MD5CHECKSUM()

Use the following functions to retrieve an *Attachment* field’s file metadata:

* Use `FILESIZE()` with `SELECT` to return the file size in bytes.
* Use `MIMETYPE()` with `SELECT` to return the file’s MIME type.
* Use `MD5CHECKSUM()` with `SELECT` to return the file’s MD5 checksum.

These functions are not supported in queries on raw objects (objects where `data_store = raw`).

### Syntax

Copy to clipboard

```
SELECT FILESIZE({field}) | MIMETYYPE({field}) | MD5CHECKSUM({field})
FROM {query target}
```

The `{field}` parameter must be the name of an *Attachment* field.

## Query Examples

The following are examples of queries using the *Attachment* field functions.

### Query

The following query searches the file name of the given *Attachment* field on the *Product* object and returns the file handle, file name, file size, MIME type, and MD5 checksum:

Copy to clipboard

```
SELECT file__c, FILENAME(file__c) as FileName, FILESIZE(file__c) as FileSize, MIMETYPE(file__c) as MIMEType, MD5CHECKSUM(file__c) as MD5Checksum
FROM product__v
FIND ('Cholecap' SCOPE FileName)
```

### Response

Copy to clipboard

```
{
    "responseStatus": "SUCCESS",
    "responseDetails": {
        "find": "('Cholecap' SCOPE FILENAME(file__c))",
        "pagesize": 1000,
        "pageoffset": 0,
        "size": 1,
        "total": 1
    },
    "data": [
        {
            "file__c": "ATF-3265e4c4-bbd3-454c-a417-55d4bcbf7085",
            "FileName": "Cholecap-Logo 2.PNG",
            "FileSize": 45176,
            "MIMEType": "image/png",
            "MD5Checksum": "4bf1311688786e4eaae8174d11c82a81"
        }
    ]
}
```
