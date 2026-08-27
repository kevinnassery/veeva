<!-- source: https://general.veevavault.dev/vault-api/api-reference/26.2/vault-objects/merge-object-records/download-merge-records-job-log/ -->
<!-- title: Download Merge Records Job Log -->

# Download Merge Records Job Log

Given a `job_id` for a merge records job, retrieve the job history log. The same log is available for download through the Vault UI from **Admin > Operations > Job Status**.

Before submitting this request:

* You must have previously requested a record merge job which is no longer `IN_PROGRESS`.
* You must have a valid `job_id` field value returned from the record merge operation.

GET`/api/{version}/vobjects/merges/{job_id}/log`

## Headers

| Name | Description |
| --- | --- |
| `Accept` | `application/json` (default) or `application/xml`. For this request, the `Accept` header controls only the error response. On `SUCCESS`, the response is a file stream (download). |

## URI Path Parameters

| Name | Description |
| --- | --- |
| `{job_id}` | The `job_id` field value returned from the merge operation. You can start merge operations with the [Initiate Record Merge](/vault-api/api-reference/26.2/vault-objects/merge-object-records/initiate-record-merge) API request or with the [Vault Java SDK](/vault-sdk/entry-points/record-merge/). |

## Request

Copy to clipboard

```
curl -X GET -H "Authorization: {AUTH_VALUE}" \
https://myvault.veevavault.com/api/v26.2/vobjects/merges/873101/log
```

## Example Response File: Merge Record Job History Log

Copy to clipboard

```
2024-03-01T00:50:01.741Z Started processing merge records job [873101]
2024-03-01T00:50:02.116Z Merge sets [Duplicate Record:[OBE000000006005], Main Record:[OBE00000000D002];Duplicate Record:[OBE000000008004], Main Record:[OBE00000000D002];Duplicate Record:[OBE000000000201], Main Record:[OBE00000000D002]] passed validation and will be merged in job [873101]
2024-03-01T00:50:02.116Z Starting distributed work for merge records job [873101]
2024-03-01T00:50:02.632Z Began processing [INBOUND_CHILD_OBJECT] relationship configured on Object [campaign_country_join__c] field [campaign__c] for job [873101]. [0] record(s) will be processed
2024-03-01T00:50:02.640Z Finished processing [INBOUND_CHILD_OBJECT] relationship for job [873101]
2024-03-01T00:50:02.924Z Began processing [INBOUND_OBJECT] relationship configured on Object [review_meeting__c] field [related_campaign__c] for job [873101]. [0] record(s) will be processed
2024-03-01T00:50:02.932Z Finished processing [INBOUND_OBJECT] relationship for job [873101]
2024-03-01T00:50:02.957Z Began processing [INBOUND_DOCUMENT] relationship configured on Document field [related_campaigns__c] for job [873101]. [0] document(s) will be processed
2024-03-01T00:50:02.964Z Finished processing [INBOUND_DOCUMENT] relationship for job [873101]
2024-03-01T00:50:02.965Z Starting to move attachments for job [873101]
2024-03-01T00:50:03.013Z Finished moving attachments for job [873101]
2024-03-01T00:50:03.197Z Completed merge records job [873101]
2024-03-01T00:50:03.197Z Merge Records job [873101] successfully merged Merge Sets: [Duplicate Record:[OBE000000006005], Main Record:[OBE00000000D002];Duplicate Record:[OBE000000008004], Main Record:[OBE00000000D002];Duplicate Record:[OBE000000000201], Main Record:[OBE00000000D002]]
2024-03-01T00:50:03.206Z
2024-03-01T00:50:03.207Z Job Title: AsyncOperation
2024-03-01T00:50:03.207Z Job Type: ASYNC_OPERATION
2024-03-01T00:50:03.207Z Job Subtype: MERGE_RECORDS_JOB
2024-03-01T00:50:03.207Z Job Schedule Time: 2024-03-01T00:50:02.000Z
2024-03-01T00:50:03.207Z Job Queue Time: 2024-03-01T00:50:02.000Z
2024-03-01T00:50:03.207Z Job Execution Time: 2024-03-01T00:50:02.000Z
2024-03-01T00:50:03.208Z Job Finish Time: 2024-03-01T00:50:03.000Z
2024-03-01T00:50:03.208Z Job Completion Status: Success (COMPLETED_WITH_SUCCESS)
```

## Response

Copy to clipboard

```
Content-Type: application/zip;charset=UTF-8
Content-Disposition: attachment;filename="19523-873101.zip"
```

## Response Details

On `SUCCESS`, Vault downloads the job history log for the specified merge record job. The HTTP Response Header `Content-Type` is set to `application/zip`. The HTTP Response Header `Content-Disposition` contains a default filename component which you can use when naming the local file. If you choose to name this file yourself, make sure you add the `.zip` extension.
The merge record job history log contains information about the merge, such as the merge start and completion times, relationship processing start and end times, attachment processing start and end times, and more. See the **Example Response File** for details.
