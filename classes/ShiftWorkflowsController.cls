// Controller for the ShiftWorkflows page, which provides a generic way to
// select and view the state of a workflow. This controller will work with any
// workflow registered globally with ShiftWorkflow (see that class file for
// more on that).
//
// The basic use/flow for this page is:
//
//	- Select a workflow identifier
//
//	- Select a Region and other optional filters
//
//	- View and potentially claim tasks
//
// Individual tasks are viewed in a new window and served by the page ShiftWorkflowTask. That
// display will have a simple default, but can be customized if the associated workflow has a
// ShiftWorkflow.FormatSupport registered that provides a custom UI for that workflow's tasks.
public with sharing class ShiftWorkflowsController {
	@TestVisible static final String PARAM_REGION_ID = 'region-id';
	@TestVisible static final String PARAM_TEAM_NAME = 'team-name';
	@TestVisible static final String PARAM_SHOW_CLOSED = 'show-closed';
	@TestVisible static final String PARAM_WORKFLOW_IDENTIFIER = 'workflow-identifier';

	static final String OPTION_ALL_TEAMS = '<all teams>';
	static final String OPTION_CHOOSE_WORKFLOW = '<none>';
	static final String OPTION_ALL_REGIONS = '<all regions>';

	ShiftWorkflow.Instance workflow;
	public Boolean hasWorkflow { get { return workflow != null; } }

	ShiftWorkflow.FormatSupport getFormatSupport() {
		return ShiftWorkflow.getFormatSupport(workflow.getIdentifier());
	}

	public String selectedWorkflowIdentifier { 
		get; 
		set {
			if (value != null) {
				workflow = ShiftWorkflow.newInstance(value);
			}
			if (workflow == null && value != null) {
				ShiftPages.addErrorMessage('Cannot find workflow for identifier: ' + value);
				selectedWorkflowIdentifier = OPTION_CHOOSE_WORKFLOW;
				return;
			}
			selectedWorkflowIdentifier = value;
		}
	}

	public List<SelectOption> getWorkflowIdentifierSelectOptions() {
		List<SelectOption> res = new List<SelectOption>{
			new SelectOption(OPTION_CHOOSE_WORKFLOW, OPTION_CHOOSE_WORKFLOW)
		};
		for (String wid : ShiftWorkflow.getWorkflowIdentifiers()) {
			ShiftWorkflow.Instance w = ShiftWorkflow.newInstance(wid);
			String label = wid;
			ShiftWorkflow.FormatSupport fmt = ShiftWorkflow.getFormatSupport(wid);
			if (fmt != null) {
				label = fmt.getWorkflowLabel(w);
			}
			res.add(new SelectOption(wid, label));
		}
		res.sort();
		return res;
	}

	List<Region__c> regions = new List<Region__c>();
	public String selectedRegion { get; set; }

	public List<SelectOption> getRegionSelectOptions() { 
		List<SelectOption> res = new List<SelectOption>();
		res.add(new SelectOption(OPTION_ALL_REGIONS, OPTION_ALL_REGIONS));
		for (Region__c r : regions) {
			res.add(new SelectOption(r.Id, r.Name));
		}
		return res;
	}

	List<String> teams = new List<String>();
	public String selectedTeam { get; set; }

	public List<SelectOption> getTeamSelectOptions() {
		List<SelectOption> res = new List<SelectOption>();
		res.add(new SelectOption(OPTION_ALL_TEAMS, OPTION_ALL_TEAMS));
		for (String team : teams) {
			res.add(new SelectOption(team, team));
		}
		return res;
	}

	public Boolean showClosed { get; set; }

	final static Id USER_ID_UNOWNED = [
		SELECT Id FROM User WHERE Shift_Key__c = :ShiftConstants.USER_SHIFT_KEY_UNOWNED
	].Id;

	public Id taskIdToClaim { get; set; }

	PageReference pageReferenceForTaskDetail(Id taskId) {
		ShiftWorkflow.FormatSupport fs = getFormatSupport();
		PageReference pageRef = fs == null ? null : fs.getTaskPageReference(taskId, workflow);
		if (pageRef == null) {
			pageRef = Page.ShiftWorkflowTask;
			pageRef.getParameters().put('id', taskId);
		}
		return pageRef;
	}

	public class TaskDetail implements Comparable {
		final Task task;
		String referenceLabel;

		TaskDetail(Task task) { this.task = task; }

		public Id taskId { get { return task.Id; } }
		public String taskSubject { get { return task.Subject; } }
		public String taskTeam { get { return task.Team__c; } }
		public String taskStatus { get { return task.Status; } }
		public DateTime taskCreatedDate { get { return task.CreatedDate; } }
		public String taskDetailUrl { get; private set; }

		public Boolean isPriority {
			get { return isPriority == null ? false : isPriority; }
			private set;
		}

		public String taskReferenceLabel { 
			get { return referenceLabel == null ? task.What.Name : referenceLabel; } 
		}

		public String getTaskCreatedDateFormat() {
			return taskCreatedDate.format('yyyy/MM/dd HH:mm');
		}

		public Boolean hasOwner {
			get { return task.OwnerId != USER_ID_UNOWNED; }
		}

		public String ownerName { get { return task.Owner.Name; } }

		public Boolean canClaim { get { return !hasOwner; } }

		public Boolean isOwner { get { return task.OwnerId == UserInfo.getUserId(); } }

		public Integer compareTo(Object otherObject) {
			TaskDetail otherTaskDetail = (TaskDetail) otherObject;
			if (this.isPriority && !otherTaskDetail.isPriority) {
				return -1;
			}
			if (!this.isPriority && otherTaskDetail.isPriority) {
				return 1;
			}

			// `DateTime.getTime()` returns a Long.  It's unlikely that the difference between these
			// timestamps will overflow an Integer, so calling `intValue` on that difference is safe.
			return (this.taskCreatedDate.getTime() - otherTaskDetail.taskCreatedDate.getTime()).intValue();
		}
	}

	void applyFormatSupport(List<TaskDetail> details) {
		ShiftWorkflow.FormatSupport support = getFormatSupport();
		if (support == null) {
			return;
		}
		List<Task> tasks = new List<Task>();
		for (TaskDetail d : details) {
			tasks.add(d.task);
		}
		Map<Id, String> taskReferenceLabels = support.getTaskReferenceLabels(tasks, workflow);
		Set<Id> priorityTaskIds = support.getPriorityTaskIds(tasks, workflow);
		for (TaskDetail d : details) {
			d.referenceLabel = taskReferenceLabels.get(d.task.Id);
			d.isPriority = priorityTaskIds.contains(d.task.Id);
		}
	}

	public List<TaskDetail> getTasks() {
		if (!hasWorkflow) {
			return new List<TaskDetail>();
		}
		String workflowIdentifier = workflow.getIdentifier();
		final String selectString = 'SELECT Id, WhatId, What.Name, What.Type, Subject, Team__c, Status, CreatedDate, OwnerId, Owner.Name FROM Task ';
		String whereString = 'WHERE Workflow_Identifier__c = :workflowIdentifier AND (Hold_Until__c = NULL OR Hold_Until__c <= TODAY)';
		final String orderByString = 'ORDER BY CreatedDate ASC LIMIT 1000 ';
		if (selectedTeam != OPTION_ALL_TEAMS) {
			whereString += 'AND Team__c = :selectedTeam ';
		}
		if (selectedRegion != OPTION_ALL_REGIONS) {
			whereString += 'AND Region_ID__c = :selectedRegion ';
		}
		if (!showClosed) {
			whereString += 'AND IsClosed = FALSE ';
		}
		List<Task> tasks = Database.query(selectString + whereString + orderByString);
		List<TaskDetail> res = new List<TaskDetail>();
		for (Task t : tasks) {
			TaskDetail d = new TaskDetail(t);
			d.taskDetailUrl = pageReferenceForTaskDetail(d.taskId).getUrl();
			res.add(d);
		}
		applyFormatSupport(res);
		res.sort();
		return res;
	}

	// Returns and redirects to a minimal reference to this page with its updated options. The
	// minimality isn't strictly necessary, but without it the page URL accumulates various
	// state parameters relative to visualforce and to this session. We want to make the current
	// URL an easily bookmarked and shared view of the state, so minimal is likely better.
	public PageReference doUpdateOptions() {
		PageReference pageRef = Page.ShiftWorkflows;
		if (selectedWorkflowIdentifier != OPTION_CHOOSE_WORKFLOW) {
			pageRef.getParameters().put(PARAM_WORKFLOW_IDENTIFIER, selectedWorkflowIdentifier);
		}
		if (selectedRegion != OPTION_ALL_REGIONS) {
			pageRef.getParameters().put(PARAM_REGION_ID, selectedRegion);
		}
		if (selectedTeam != OPTION_ALL_TEAMS) {
			pageRef.getParameters().put(PARAM_TEAM_NAME, selectedTeam);
		}
		pageRef.getParameters().put(PARAM_SHOW_CLOSED, String.valueOf(showClosed));
		pageRef.setRedirect(true);
		return pageRef;
	}

	public PageReference doClaim() {
		ShiftTasks.claim(taskIdToClaim);
		return pageReferenceForTaskDetail(taskIdToClaim);
	}

	void initWorkflows() {
		selectedWorkflowIdentifier = ShiftPages.getStringParameter(PARAM_WORKFLOW_IDENTIFIER);
	}

	void initRegions() {
		regions = [
			SELECT Id, Name 
			FROM Region__c
			WHERE Shift_Key__c NOT IN ('unserviced')
			ORDER BY Name ASC
		];
		selectedRegion = ShiftPages.getStringParameter(PARAM_REGION_ID);
		if (selectedRegion != null) {
			return;
		}
		selectedRegion = OPTION_ALL_REGIONS;

	}

	void initTeams() {
		List<AggregateResult> results = [
			SELECT Team__c team
			FROM Task 
			WHERE Workflow_Identifier__c = :workflow.getIdentifier() AND Team__c != NULL
			GROUP BY Team__c 
			ORDER BY Team__c ASC
		];
		teams = new List<String>();
		for (AggregateResult r : results) {
			teams.add((String) r.get('team'));
		}
		selectedTeam = ShiftPages.getStringParameter(PARAM_TEAM_NAME);
		if (selectedTeam == null) {
			selectedTeam = OPTION_ALL_TEAMS;
		}
	}

	void initShowCompleted() {
		showClosed = ShiftPages.getBooleanParameter(PARAM_SHOW_CLOSED);
	}

	public ShiftWorkflowsController() {
		initWorkflows();
		initShowCompleted();
		if (workflow == null) {
			return;
		}
		initRegions();
		initTeams();
	}
}