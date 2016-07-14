public with sharing class ShiftWorkflowTaskComponentController {
	public Boolean attrRenderRelatedTo { get; set; }
	public Boolean attrAllowsCompletion { get; set; }
	public ShiftCallable attrBeforeComplete { get; set; }

	public Task task { get; private set; }
	public Id taskId { get { return task.Id; } }
	public String taskSubject { get { return task.Subject; } }
	public String taskOwnerName { get { return task.Owner.Name; } }
	public Id taskOwnerId { get { return task.OwnerId; } }
	public String taskDescription { get { return task.Description; } }
	public Boolean hasTaskDescription { get { return taskDescription != NULL; } }
	public String taskTeam { get { return task.Team__c; } }
	public String taskReferenceLabel { get; private set; }

	public String taskReferenceUrl {
		get { return new PageReference('/' + task.WhatId).getUrl(); }
	}
	
	public Boolean canComplete { 
		get {
			return task.Status == ShiftConstants.TASK_STATUS_IN_PROGRESS &&
				task.OwnerId == UserInfo.getUserId(); 
		}
	}

	public Boolean canAbandon { get { return canComplete; } }

	public PageReference doComplete() {
		try {
			if (attrBeforeComplete != null) {
				PageReference ref = (PageReference) attrBeforeComplete.call();
				if (ref != null) {
					return ref;
				}
			} 
			ShiftTasks.complete(task.Id);
		} catch (Exception ex) {
			ShiftPages.addErrorMessage(ex.getMessage());
		}
		return ApexPages.currentPage();
	}

	public PageReference doAbandon() {
		ShiftTasks.abandon(task.Id);
		return ApexPages.currentPage();
	}

	void setFormatDetails() {
		ShiftWorkflow.FormatSupport formatSupport = ShiftWorkflow.getFormatSupport(task.Workflow_Identifier__c);
		if (formatSupport != null) {
			ShiftWorkflow.Instance instance = ShiftWorkflow.newInstance(task.Workflow_Identifier__c);
			List<Task> tasks = new List<Task>{task};
			Map<Id, String> labels = formatSupport.getTaskReferenceLabels(tasks, instance);
			taskReferenceLabel = labels.get(task.Id);
		}
		if (taskReferenceLabel == null) {
			taskReferenceLabel = task.What.Name;
		}
	}

	public ShiftWorkflowTaskComponentController() {
		this.task = [
			SELECT 
				Id, Status, Description, WhatId, What.Name, OwnerId, Owner.Name,
				Subject, Team__c, Workflow_Identifier__c
			FROM Task 
			WHERE Id = :ShiftPages.getIdParameter()
		];
		setFormatDetails();
	}
}