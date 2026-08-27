<!-- source: https://general.veevavault.dev/vql/query-targets/jobs/ -->
<!-- title: Jobs -->

# Jobs

In 24.1+, you can use the `job_instance__sys` query target to query job instances.

In v23.2+, you can use the `job_history__sys` and `job_task_history__sys` query targets to query job history records and SDK job task history records in your Vault.

## Job Instances

The `job_instance__sys` query target contains job information. Each record represents a single scheduled, queued, or running job instance.

### Job Instance Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The following fields are queryable for the `job_instance__sys` object:

| Name | Description |
| --- | --- |
| `id` | The ID of the job. |
| `job_name__sys` | The name of the job. |
| `job_metadata__sys` | The name of the Job Metadata instance for SDK jobs. |
| `job_type__sys` | The job type. |
| `job_title__sys` | The title of the job. |
| `status__sys` | The status of the job. |
| `created_by__sys` | The ID of the user who created the job instance. |
| `queue_date__sys` | The DateTime when the job started in the queue. |
| `run_date__sys` | The DateTime when the job ran. |

### Job Instance Query Examples

#### Job Instance Query

Get metadata for SDK job instances:

Copy to clipboard

```
SELECT id, job_status__sys
FROM job_instance__sys
WHERE job_type__sys = 'sdk_job'
```

## Job Histories

The `job_history__sys` query target contains job history information. Each record represents a single completed job instance.

### Job History Relationships

The `job_history__sys` query target exposes the `job_task_history__sysr` relationship. This is an inbound reference to an SDK job history record’s task instances.

### Job History Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The following fields are queryable for the `job_history__sys` object:

| Name | Description |
| --- | --- |
| `id` | The ID of the job. |
| `job_name__sys` | The name of the job. |
| `job_metadata__sys` | The name of the Job Metadata instance for SDK jobs. |
| `job_type__sys` | The job type. |
| `job_title__sys` | The title of the job. |
| `status__sys` | The status of the job. |
| `schedule_date__sys` | The scheduled DateTime of the job. |
| `queue_date__sys` | The DateTime when the job started in the queue. |
| `start_date__sys` | The DateTime when the job started. |
| `finish_date__sys` | The DateTime when the job finished. |

### Job History Query Examples

#### Job History Query

Get metadata for SDK job histories:

Copy to clipboard

```
SELECT id, job_name__sys, job_type__sys, status__sys, schedule_date__sys, queue_date__sys
FROM job_history__sys
WHERE job_type__sys = 'sdk_job'
```

#### Job Task Relationship Query

Get metadata for job histories including task history:

Copy to clipboard

```
SELECT id, job_name__sys, (SELECT task_id__sys FROM job_task_history__sysr)
FROM job_history__sys
```

## Job Task Histories

The `job_task_history__sys` query target contains SDK job task history information. Each record represents a task in a completed SDK job history instance.

### Job Task History Relationships

The `job_task_history__sys` query target exposes the `job_history__sysr` relationship. This is an outbound reference to the corresponding job history record.

### Job Task History Queryable Fields

This metadata is only available via VQL query and cannot be retrieved using the standard metadata API.

The following fields are queryable for the `job_task_history__sys` object:

| Name | Description |
| --- | --- |
| `task_id__sys` | The ID of the job task. |
| `job_history__sys` | The ID of the parent job. |
| `status__sys` | The result status of the job task. |
| `queue_date__sys` | The DateTime when the job task started in the queue. |
| `start_date__sys` | The DateTime when the job task started. |
| `finish_date__sys` | The DateTime when the job task ended. |

### Job Task History Query Examples

#### Job Task History Query

Get metadata for job task histories:

Copy to clipboard

```
SELECT task_id__sys, job_history__sys, status__sys, queue_date__sys,
start_date__sys,finish_date__sys
FROM job_task_history__sys
```

#### Job History Relationship Query

Get metadata for job task histories, including the name of the corresponding job:

Copy to clipboard

```
SELECT task_id__sys, job_history__sysr.job_name__sys, status__sys, queue_date__sys, start_date__sys, finish_date__sys
FROM job_task_history__sys
```
