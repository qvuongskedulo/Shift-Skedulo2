// Provides trigger handling and other methods for working with Tasks.
public class ShiftTasks {
	public class TaskException extends Exception {}

	static final Set<String> STATUSES_FOR_ABANDON = new Set<String>{
		ShiftConstants.TASK_STATUS_NOT_STARTED,
		ShiftConstants.TASK_STATUS_IN_PROGRESS
	};

	static final Set<String> STATUSES_FOR_CLAIM = new Set<String>{
		ShiftConstants.TASK_STATUS_NOT_STARTED
		// possibly add 'Deferred', 'Waiting on someone else' if we end up
		// using those
	};

	static final Set<String> STATUSES_FOR_COMPLETE = new Set<String>{
		ShiftConstants.TASK_STATUS_IN_PROGRESS
	};

	static void setVisible(List<Task> tasks) {
		for (Task task : tasks) {
			task.IsVisibleInSelfService = true;
		}
	}

	public static Task createTask(sObject obj, String subject, String team, Date activityDate, Id owner, String workflowIdentifier) {
		// TODO: Remove Hold_Until__c assignment when we can migrate it to a formula field. See T1486
		return new Task(
			WhatId = obj.Id,
			Subject = subject,
			Team__c = team,
			OwnerId = owner,
			ActivityDate = activityDate,
			Hold_Until__c = activityDate,
			Workflow_Identifier__c = workflowIdentifier
		);
	}

	public static Task createTask(sObject obj, String subject, String team, Date activityDate, Id owner) {
		return createTask(obj, subject, team, activityDate, owner, null);
	}

	public static Task createTask(sObject obj, String subject, String team) {
		return createTask(obj, subject, team, Date.today(), ShiftUsers.unownedUserID());
	}

	public static Task createTask(sObject obj, String subject, String team, Id owner) {
		return createTask(obj, subject, team, Date.today(), owner);
	}

	public static Task createTask(sObject obj, String subject, String team, Date activityDate) {
		return createTask(obj, subject, team, activityDate, ShiftUsers.unownedUserID());
	}

	public static Task createTask(sObject obj, String subject, String team, Date activityDate, String workflowIdentifier) {
		return createTask(obj, subject, team, activityDate, ShiftUsers.unownedUserID(), workflowIdentifier);
	}

	public static Task createTask(Contact contact, String subject, String team, String description, Date activityDate, Id owner, String workflowIdentifier) {
		// TODO: Remove Hold_Until__c assignment when we can migrate it to a formula field. See T1486
		return new Task(
			WhoId = contact.Id,
			Subject = subject,
			Description = description,
			Team__c = team,
			OwnerId = owner,
			ActivityDate = activityDate,
			Hold_Until__c = activityDate,
			Workflow_Identifier__c = workflowIdentifier
		);
	}

	public static Task createTask(Contact contact, String subject, String team, String description, Date activityDate, Id owner) {
		return createTask(contact, subject, team, description, activityDate, owner, null);
	}

	public static Task createTask(Contact contact, String subject, String team, String description) {
		return createTask(contact, subject, team, description, Date.today(), ShiftUsers.unownedUserID());
	}

	public static Task createTask(Contact contact, String subject, String team, String description, Id owner) {
		return createTask(contact, subject, team, description, Date.today(), owner);
	}

	public static Task createTask(Contact contact, String subject, String team, String description, Date activityDate) {
		return createTask(contact, subject, team, description, activityDate, ShiftUsers.unownedUserID());
	}

	public static Task createTask(Contact contact, String subject, String team, String description, Date activityDate, String workflowIdentifier) {
		return createTask(contact, subject, team, description, activityDate, ShiftUsers.unownedUserID(), workflowIdentifier);
	}

	static void insertShiftTaskEvents(Map<Id, Task> oldTasks, List<Task> newTasks) {
		List<Shift_Task_Event__c> events = new List<Shift_Task_Event__c>();
		for (Task task : newTasks) {
			Shift_Task_Event__c event = new Shift_Task_Event__c(
				Task_ID__c = task.Id,
				Occurred_At__c = Datetime.now()
			);
			Task oldTask = oldTasks == null ? null : oldTasks.get(task.Id);
			if (oldTask == null || task.Status != oldTask.Status) {
				event.Is_Status_Change__c = true;
				event.To_Status__c = task.Status;
				event.From_Status__c = oldTask == null ? null : oldTask.Status;
			}
			if (oldTask == null || task.OwnerId != oldTask.OwnerId) {
				event.Is_Owner_Change__c = true;
				event.To_Owner_ID__c = task.OwnerId;
				event.From_Owner_ID__c = oldTask == null ? null : oldTask.OwnerId;
			}
			events.add(event);
		}
		insert events;
	}

	public static void updateStatus(List<Task> tasks, String status) {
		List<Id> taskIds = new List<Id>();
		for (Task task : tasks) {
			taskIds.add(task.Id);
		}
		updateStatus(taskIds, status);
	}

	public static void updateStatus(List<Id> taskIds, String status) {
		Set<Task> toUpdate = new Set<Task>();
		for (Id taskId : taskIds) {
			toUpdate.add(new Task(
				Id = taskId, 
				Status = status
			));
		}
		update new List<Task>(toUpdate);
	}

	public static void beforeInsert(List<Task> newTasks) {
		setVisible(newTasks);
	}

	public static void beforeUpdate(Map<Id, Task> oldTasks, List<Task> newTasks) {
		setVisible(newTasks);
	}

	public static void afterInsert(List<Task> newTasks) {
		insertShiftTaskEvents(null, newTasks);
	}

	public static void afterUpdate(Map<Id, Task> oldTasks, List<Task> newTasks) {
		ShiftWorkflow.processTasksAfterUpdate(oldTasks, newTasks);
		insertShiftTaskEvents(oldTasks, newTasks);
	}

	// TODO: Refactor. See https://shift.phacility.com/T2532
	// The claim/complete/abandon methods below are meant to be used with tasks
	// created with the following assumptions:
	//
	//	- A task can only be claimed if it is currently owned by the 'unowned'
	//	user and in a known state
	//
	//	- A task can only be abandoned if is owned by the expected user and in
	//	a known state
	//
	//	- A task can only be completed if is owned by the expected user and in
	//	a known state.
	//
	// These assumptions may not be valid for all tasks, especially since the
	// Task object is a standard object and can be generated by users manually,
	// or by other installed packages or code.
	//
	// As we move forward we'll refactor the notion of Task.Team__c in favor of
	// some more specific pairing of a team, a set of users, and optionally a
	// Region. Part of that work will be to add or modify the claim() below to
	// respect team makeup.

	static Task expectTask(String opName, Id taskId, Id expectOwner, Set<String> expectStatuses) {
		Task task = [SELECT Id, OwnerId, Status FROM Task WHERE Id = :taskId];
		if (task.OwnerId != expectOwner) {
			throw new TaskException('cannot ' + opName + ' task (already owned by user with id ' + task.OwnerId + ')');
		}
		if (!expectStatuses.contains(task.Status)) {
			throw new TaskException('cannot ' + opName + ' task (status is "' + task.Status + '")');
		}
		return task;
	}

	public static void claim(Id taskId, Id newOwner) {
		Task task = expectTask('claim', taskId, ShiftUsers.unownedUserId(), STATUSES_FOR_CLAIM);
		task.Status = ShiftConstants.TASK_STATUS_IN_PROGRESS;
		task.OwnerId = newOwner;
		update task;
	}

	public static void claim(Id taskId) { claim(taskId, UserInfo.getUserId()); }

	public static void complete(Id taskId, Id expectOwner) {
		Task task = expectTask('complete', taskId, expectOwner, STATUSES_FOR_COMPLETE);
		task.Status = ShiftConstants.TASK_STATUS_COMPLETED;
		update task;
	}

	public static void complete(Id taskId) { complete(taskId, UserInfo.getUserId()); }

	public static void abandon(Id taskId, Id expectOwner) {
		Task task = expectTask('abandon', taskId, expectOwner, STATUSES_FOR_ABANDON);
		task.OwnerId = ShiftUsers.unownedUserId();
		task.Status = ShiftConstants.TASK_STATUS_NOT_STARTED;
		update task;
	}

	public static void abandon(Id taskId) { abandon(taskId, UserInfo.getUserId()); }
}