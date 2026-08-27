<!-- source: https://general.veevavault.dev/vql/query-targets/workflows/ -->
<!-- title: Workflows -->

# Workflows

You can query document and object workflow instances in the following ways:

* Query for in-progress (still running) workflow instances: `active`
* Query for completed or cancelled workflow instances: `inactive`

Workflow and workflow task definitions are not queryable.

The following workflow objects are available for query on document workflows in v21.2+ and object workflows in v22.2+. You must have the *Application: Workflow: Query* or *Application: Workflow: Participate* permission to query these objects.

| Name | Description |
| --- | --- |
| `active_workflow__sys` | Each record represents a single in-progress workflow instance. |
| `inactive_workflow__sys` | Each record represents a single completed or cancelled workflow instance. |
| `active_workflow_item__sys` | Each record represents a single document or object record associated with an in-progress workflow instance. |
| `inactive_workflow_item__sys` | Each record represents a single document or object record associated with a cancelled or completed workflow instance. |
| `active_workflow_task__sys` | Each record represents a user task instance of an in-progress workflow. |
| `inactive_workflow_task__sys` | Each record represents a user task instance of a cancelled or completed workflow. |
| `active_workflow_task_item__sys` | Each record represents an item of a workflow task of an in-progress workflow instance. |
| `inactive_workflow_task_item__sys` | Each record represents an item of a workflow task of an in-progress workflow instance. |

## Workflow Objects

The `active_workflow__sys` and `inactive_workflow__sys` objects contain workflow-level information about each workflow instance. A single workflow can have multiple instances, so each record for these objects represents a unique instance of a workflow.

### Workflow Object Relationships

The `active_workflow__sys` and `inactive_workflow__sys` objects expose the following relationships:

| Name | Description |
| --- | --- |
| `owner__sysr` | An outbound reference to this workflow instance owner user (`user__sys`). |
| `{in}active_workflow_tasks_sysr` | An inbound reference to this workflow’s task instances. |
| `{in}active_workflow_task_items_sysr` | An inbound reference to this workflow’s task item instances. |

### Workflow Object Queryable Fields

The `active_workflow__sys` and `inactive_workflow__sys` objects allow queries on the following fields:

| Name | Description |
| --- | --- |
| `id` | The workflow instance ID. |
| `label__sys` | The workflow label visible to Admins in the Vault UI. |
| `name__sys` | The name of this workflow. |
| `owner__sys` | An object reference to the `user__sys` record in the workflow owner role. |
| `cardinality__sys` | Indicates how many items can be included in this workflow. |
| `type__sys` | The workflow type, which is either `document__sys` or `object__sys`. |
| `status__sys` | The workflow status, which is either `active__v`, `cancelled__v`, or `completed__v`. |
| `workflow_definition_version__sys` | The workflow configuration version. |
| `due_date__sys` | The date by which this workflow must be completed. |
| `cancelled_date__sys` | The date this workflow was cancelled. |
| `cancellation_comment__sys` | If configured, the comment added by a user when cancelling the workflow. |
| `completed_date__sys` | The date this workflow was completed. |
| `created_by__sys` | An object reference to the `user__sys` record which created this workflow instance. |
| `created_date__sys` | The date this workflow was created. |
| `modified_by__sys` | An object reference to the `user__sys` record which last modified this workflow instance. |
| `modified_date__sys` | The date this workflow was last modified. |
| `class__sys` | If this is a *Read & Understood* workflow, this value is `read_and_understood__sys`. |

## Workflow Item Objects

The `active_workflow_item__sys` and `inactive_workflow_item__sys` objects contain item-level information about each document or object record associated with a workflow.

### Workflow Item Relationships

The `active_workflow_item__sys` and `inactive_workflow_item__sys` objects expose the following relationships:

| Name | Description |
| --- | --- |
| `{in}active_workflow__sysr` | An outbound reference to the parent workflow instance. |

### Workflow Item Queryable Fields

The `active_workflow_item__sys` and `inactive_workflow_item__sys` objects allow querying the following fields:

| Name | Description |
| --- | --- |
| `id` | The workflow instance ID. |
| `workflow__sys` | An object reference to the parent `workflow__sys`. |
| `type__sys` | The type of workflow item, either `document__sys`, `document_version__sys`, or `object__sys`. |
| `document__sys` | The document ID if `type__sys` is `document__sys`. |
| `document_version__sys` | The document ID if `type__sys` is `document_version__sys`. |
| `object_name__sys` | The object record name if `type__sys` is `object__sys`. |
| `object_record_id__sys` | The object record ID if `type__sys` is `object__sys`. |

## Workflow Task Objects

The `active_workflow_task__sys` and `inactive_workflow_task__sys` objects contain task-level information about each user task associated with a workflow.

### Workflow Task Relationships

The `active_workflow_task__sys` and `inactive_workflow_task__sys` objects expose the following relationships:

| Name | Description |
| --- | --- |
| `{in}active_workflow__sysr` | An outbound reference to the parent workflow instance. |
| `owner__sysr` | An outbound reference to the workflow task instance owner user (`user__sys`). |
| `{in}active_workflow_task_items__sysr` | An inbound reference to the workflow task’s item instances. |

### Workflow Task Queryable Fields

The `active_workflow_task__sys` and `inactive_workflow_task__sys` allow querying the following fields:

| Name | Description |
| --- | --- |
| `id` | The workflow task instance ID. |
| `workflow__sys` | An object reference to the parent `workflow__sys`. |
| `label__sys` | The workflow task label visible to users in the Vault UI. |
| `name__sys` | The name of this workflow task. |
| `owner__sys` | An object reference to the `user__sys` record assigned to this task. |
| `participant_group__sys` | The participant groups assigned to this workflow task. |
| `status__sys` | The status of this workflow task. |
| `assigned_date__sys` | The date this workflow task was assigned. |
| `cancelled_date__sys` | The date this workflow task was cancelled. |
| `completed_by__sys` | An object reference to the `user__sys` record which completed this workflow task instance. |
| `created_date__sys` | The date this workflow task instance was created. |
| `due_date__sys` | The date by which this task must be completed. |
| `modified_date__sys` | The date this workflow task was last modified. |
| `iteration__sys` | The number of times this task instance has iterated. |
| `instructions__sys` | The written instructions for this workflow task. |
| `group_instructions__sys` | The written instructions for this workflow task, sent when a task is made available to multiple participants. |

## Workflow Task Item Objects

The `active_workflow_task_item__sys` and `inactive_workflow_task_item__sys` objects contain item-level information about each user task associated with a workflow.

### Workflow Task Item Relationships

The `active_workflow_task_item__sys` and `inactive_workflow_task_item__sys` objects expose the following relationships:

| Name | Description |
| --- | --- |
| `{in}active_workflow__sysr` | An outbound reference to the parent workflow instance. |
| `{in}active_workflow_task__sysr` | An outbound reference to the parent task instance. |

### Workflow Task Item Queryable Fields

The `active_workflow_task_item__sys` and `inactive_workflow_task_item__sys` allow queries on the following fields:

| Name | Description |
| --- | --- |
| `id` | The workflow task item instance ID. |
| `task__sys` | An object reference to the parent task record. |
| `task_comment__sys` | If configured, task items may require a comment. |
| `workflow__sys` | An object reference to the parent workflow record. |
| `status__sys` | The status of this workflow task item. |
| `capacity__sys` | If configured, task verdicts may require a capacity. |
| `verdict__sys` | If configured, task items may require a verdict. |
| `verdict_reason__sys` | If configured, task verdicts may require a reason. |
| `verdict_comment__sys` | If configured, task verdicts may require a comment. |
| `type__sys` | The type of workflow task item. |
| `document_id__sys` | The document ID for this task item. |
| `verdict_document_major_version_number__sys` | If this task item has a verdict, this field value is the major version of the document. |
| `verdict_document_minor_version_number__sys` | If this task item has a verdict, this field value is the minor version of the document. |
| `verdict_document_version_id__sys` | If this task item has a verdict, this field value contains the ID, major version, and minor version. |
| `object__sys` | The object record name if the workflow item is an object record. |
| `object_record_id__sys` | The object record ID if the workflow item is an object record. |

## Workflow Job Step Objects

The `active_workflow_job_step__sys` and `inactive_workflow_job_step__sys` objects return Job step data for active and inactive Job step instances. Available in v25.3+.

Learn more about [Workflow Job steps in Vault Help](https://platform.veevavault.help/en/lr/33550#job-step).

### Workflow Job Step Queryable Fields

The `active_workflow_job_step__sys` and `inactive_workflow_job_step__sys` allow queries on the following fields:

| Name | Description |
| --- | --- |
| `id` | The workflow Job step instance ID. |
| `workflow__sys` | The workflow process instance ID. |
| `job__sys` | The Job ID. |
| `name__sys` | The Job step public key. |
| `label__sys` | The Job step UI label. |
| `status__sys` | The completion status verdict public key. |
| `cancelled_date__sys` | The Job step cancellation date. |
| `completed_date__sys` | The Job step completion date. |
| `complete_by__sys` | The ID of the user who completed the Job step. |
| `modified_date__sys` | The date the Job step was last modified. |
| `iteration__sys` | The Job step iteration count. |
| `job_name__sys` | The public key of the Vault job. |

## Workflow Query Examples

The following query retrieves the due dates for all currently unassigned tasks.

Copy to clipboard

```
SELECT label__sys, due_date__sys
FROM active_workflow_task__sys
WHERE status__sys = 'available__sys'
```

The following query retrieves the documents associated with a specified active workflow:

Copy to clipboard

```
SELECT id, workflow__sys, type__sys
FROM active_workflow_item__sys
WHERE workflow__sys = 123
```

The following query retrieves the open tasks for a given user:

Copy to clipboard

```
SELECT label__sys, workflow__sys, owner__sys, due_date__sys, active_workflow__sysr.owner__sys
FROM active_workflow_task__sys
WHERE owner__sysr.username__sys = 'olivia@veepharm.com'
AND status__sys = 'active__v'
```

The following query retrieves the task details of a specified completed workflow:

Copy to clipboard

```
SELECT id, owner__sys, name__sys, iteration__sys, inactive_workflow__sysr.owner__sys, inactive_workflow__sysr.name__sys, inactive_workflow__sysr.type__sys,
  (SELECT verdict__sys, verdict_reason__sys, capacity__sys
  FROM inactive_workflow_task_items__sysr)
FROM inactive_workflow_task__sys
WHERE workflow__sys = 123
```

The following query retrieves the Job ID and Job step instance ID for active Job step instances:

Copy to clipboard

```
SELECT id, job__sys 
FROM active_workflow_job__sys
```

## Legacy Workflow

The `workflows` object allows queries on legacy workflows. Learn more about [legacy workflows in Vault Help](https://platform.veevavault.help/en/lr/2376).

Note

Note that the escape sequences available for [special characters](/vql/references/language-specifications/syntax-basics#special-characters) are not standardized for legacy workflows and may behave differently.
