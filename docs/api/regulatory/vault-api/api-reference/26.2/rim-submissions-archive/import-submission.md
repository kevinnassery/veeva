<!-- source: https://general.veevavault.dev/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/import-submission/ -->
<!-- title: Import Submission -->

# Import Submission

Import a submission into your Vault.

Before submitting this request:

* You must be assigned permissions to use the API and have permissions to view and edit the specified `submission__v` object record.
* You must create the corresponding object records for the **Submission** and **Application** objects in your Vault.
* You must create and upload a valid submission import file or folder to [file staging](/regulatory/vault-api/guides/file-staging). The submission to import must be in a [specific location and format](#File_Location_Structure).

#### Submission Import File Location & Structure

The submission import file must be located in one of the following places, and must be in a specific folder structure.

##### At the Root

If your submission import is located at the file staging root, it must follow the following structure:

`/SubmissionsArchive/{application_folder}/{submission_file_or_folder}`

* `{application_folder}`: This required folder can have any name you wish.
* `{submission_file_or_folder}`: If this is a file containing your submission, it must be a `.zip` or `.tar.gz`. If this is a folder, it must contain your submission to import. This required folder can have any name you wish.

For example, `/SubmissionsArchive/nda654321/0001.zip`.

##### Within a User Folder

In some cases, your [Vault user permissions](/regulatory/vault-api/guides/file-staging) may prevent you from uploading directly to the file staging root. In these cases, you must upload to your user folder using the following structure:

`/u[ID]/Submissions Archive Import/{application_folder}/{submission_folder}`

* `{application_folder}`: This required folder can have any name you wish.
* `{submission_folder}`: The folder containing your submission to import. This required folder can have any name you wish. Vault does not support importing `.zip` or `.tar.gz` files from user folders.

For example, `/u5678/Submissions Archive Import/nda123456/0013`.

## Endpoint

POST`/api/{version}/vobjects/submission__v/{submission_id}/actions/import`

## Headers

| Name | Description |
| --- | --- |
| `Content-Type` | `application/x-www-form-urlencoded` |
| `Accept` | `application/json` (default) or `application/xml` |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{submission_id}` | The `id` field value of the `submission__v` object record. To get this value, [use VQL to retrieve all records](/regulatory/vault-api/api-reference/26.2/vault-objects/retrieve-object-records) on the `submission__v` object. |

## Body Parameters

| Name | Description |
| --- | --- |
| `file` required | Use the `file` parameter to specify the location of the submission folder or ZIP file previously uploaded to [file staging](/regulatory/vault-api/guides/file-staging). In the request, add the `file` parameter to your input and enter the path to the submission folder relative to the file staging root, for example, `/SubmissionsArchive/nda123456/0000`, or to the path to your user file staging folder, for example, `/u5678/Submissions Archive Import/nda123456/0000`. Vault does not support importing `.zip` or `.tar.gz` files from user folders. |
| `dossier_format_record_id` conditional | The ID of the *Controlled Vocabulary* record with the *Dossier Format* type. This parameter is required if the *Automatically populate records based on Imported Submission XML* setting is enabled in your Vault's [application settings](https://regulatory.veevavault.help/en/gr/53688#submissions-archive-features). |
| `actual_submission_date` optional | The actual submission date (`actual_submission_date__rim`) on the target *Submission* (`submission__v`) object record in the format `YYYY-MM-DD`. The value cannot be a date in the future. |

## Request

Copy to clipboard

```
curl -X POST -H "Authorization: {AUTH_VALUE}" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "file=/nda123456/0000" \
-d "dossier_format_record_id=A0V000000002J06" \
-d "actual_submission_date=2024-07-12" \
https://myvault.veevavault.com/api/v26.2/vobjects/submission__v/00S000000000101/actions/import
```

## Response

Copy to clipboard

```
{
  "responseStatus": "SUCCESS",
  "warnings": [
    {
      "type": "APPLICATION_MISMATCH",
      "message": "Application folder name does not match the Application record name."
    },
    {
      "type": "SUBMISSION_MISMATCH",
      "message": "Submission folder name does not match the Submission record name."
    }
  ],
  "job_id": 1301,
  "url": "/api/v26.2/services/jobs/1301"
}
```

## Response Details

On `SUCCESS`, the response includes the following information:

* `job_id` - The Job ID value is used to retrieve the [status](/regulatory/vault-api/api-reference/26.2/jobs/retrieve-job-status) and results of the binder export request.
* `url` - The URL to retrieve the current status of the import request.

You may also receive one or more `warnings`. The `warnings` shown above indicate that the folders being imported do not match the object records in our Vault. To fix this warning, we can change the folder name or object record name. However, warnings are not fatal and you may choose to take no action.

Before submitting this request, we created a `submission__v` object record and `application__v` object record in our Vault. We also created submissions ZIP file containing a "Submission" folder and "Application" folder. This was loaded to file staging awaiting import. Ideally, we would have named and structured the folders to match that of the submission that was sent to the health authority and which we are now archiving. However, this is not critical to the import process.

When the submission import completes, you’ll receive an email and a Vault notification. If attachments are enabled on the *Submission* object, Vault also adds the import results as an attachment on the *Submission* record. Learn more in [Vault Help](https://regulatory.veevavault.help/en/gr/28082#import-results).

Use [Retrieve Submission Import Results](/regulatory/vault-api/api-reference/26.2/rim-submissions-archive/retrieve-submission-import-results) to retrieve the results of the completed submission via Vault API.
