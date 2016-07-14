// Implements the Processing team's main workflow. See the original PRD:
//
//		https://docs.google.com/document/d/1cWBEwF-fd0kxdkktGGLkhqvXYcBUBQk65uSiF3QgZxI/edit
//
// as well as the visual description of the logic in this class:
//
//		https://docs.google.com/drawings/d/1KF9-JPKeMr9nWjuRq181WeKkiM93IW5de01ORPPB2ps/edit
//
// Where the visual description differs from this code, this code should be taken as authoritative.
public class ShiftProcessingPipeline {
	public static final String WORKFLOW_IDENTIFIER = 'processing-pipeline';
	static final Integer WORKFLOW_VERSION = 1;
	static final String LABEL = 'Processing Pipeline';

	@TestVisible static final String ERROR_NOTES_VERSION_STALE = 'Processing Pipeline Notes Version is stale';

	public static final Integer MIN_OPTIONS_FOR_TOP_FEATURES = 1;

	// The Schema.Processing_Pipeline__c.* values are already effectively
	// constants, but we use them enough below that it's worth the readability
	// to rename them here
	static final Schema.SObjectField FIELD_GOT_SELLER_APPROVAL = Schema.Processing_Pipeline__c.Got_Seller_Approval__c;
	static final Schema.SObjectField FIELD_IS_CONDITION_REPORT_HANDLED = Schema.Processing_Pipeline__c.Is_Condition_Report_Handled__c;
	static final Schema.SObjectField FIELD_IS_COSMETIC_INSPECTION_DONE = Schema.Processing_Pipeline__c.Is_Cosmetic_Inspection_Done__c;
	static final Schema.SObjectField FIELD_IS_INSPECTION_DONE = Schema.Processing_Pipeline__c.Is_Inspection_Done__c;
	static final Schema.SObjectField FIELD_IS_LISTING_COPY_DONE = Schema.Processing_Pipeline__c.Is_Listing_Copy_Done__c;
	static final Schema.SObjectField FIELD_IS_PHOTOGRAPHY_DONE = Schema.Processing_Pipeline__c.Is_Photography_Done__c;
	static final Schema.SObjectField FIELD_IS_QUALITY_CONTROL_CHECK_DONE = Schema.Processing_Pipeline__c.Is_Quality_Control_Check_Done__c;
	static final Schema.SObjectField FIELD_IS_REPAIR_ASSESSMENT_DONE = Schema.Processing_Pipeline__c.Is_Repair_Assessment_Done__c;
	static final Schema.SObjectField FIELD_IS_REPAIR_MANAGEMENT_DONE = Schema.Processing_Pipeline__c.Is_Repair_Management_Done__c;
	static final Schema.SObjectField FIELD_IS_TOP_FEATURES_DONE = Schema.Processing_Pipeline__c.Is_Top_Features_Done__c;
	static final Schema.SObjectField FIELD_IS_WASH_EXTERIOR_DONE = Schema.Processing_Pipeline__c.Is_Wash_Exterior_Done__c;
	static final Schema.SObjectField FIELD_IS_WASH_INTERIOR_DONE = Schema.Processing_Pipeline__c.Is_Wash_Interior_Done__c;
	
	public static final String TASK_ASSESS_REPAIRS = 'Assess Repairs';
	public static final String TASK_FINAL_PROCESSING_QUALITY_CONTROL_CHECK = 'Final Processing Quality Control Check';
	public static final String TASK_GET_SELLER_APPROVAL = 'Get Seller Approval';
	public static final String TASK_HANDLE_CONDITION_REPORT = 'Handle Condition Report';
	public static final String TASK_INSPECT_COSMETIC = 'Perform Cosmetic Inspection';
	public static final String TASK_INSPECT_MECHANICAL = 'Perform Mechanical Inspection';
	public static final String TASK_MANAGE_REPAIRS_COSMETIC = 'Manage Cosmetic Repairs';
	public static final String TASK_MANAGE_REPAIRS_MECHANICAL = 'Manage Mechanical Repairs';
	public static final String TASK_MANAGE_REPAIRS_PAINTLESS_DENT_REMOVAL = 'Manage Paintless Dent Removal';
	public static final String TASK_MANAGE_REPAIRS_SMOG = 'Manage Smog Check';
	public static final String TASK_PHOTOGRAPH_VEHICLE = 'Photograph Vehicle';
	public static final String TASK_TOP_FEATURES = 'Select Top Features';
	public static final String TASK_WASH_EXTERIOR = 'Wash Exterior';
	public static final String TASK_WASH_INTERIOR = 'Wash Interior';
	public static final String TASK_WRITE_LISTING = 'Write Listing for Vehicle';

	public static final String REPAIR_STATUS_AWAITING_REPAIR = 'Awaiting Repair';
	public static final String REPAIR_STATUS_IN_PROGRESS = 'In Progress';
	public static final String REPAIR_STATUS_COMPLETE = 'Complete';
	public static final String REPAIR_STATUS_UNNECESSARY = 'Unnecessary';

	public static final Set<String> VALID_STARTING_REPAIR_STATUSES = new Set<String>{
		REPAIR_STATUS_AWAITING_REPAIR,
		REPAIR_STATUS_UNNECESSARY
	};

	// In the absence of LinkedHashMap, we keep a Map and a list of keys in our desired
	// iteration order (the order was provided by Props team), and ensure that
	// they are in sync by adding via putRepairStatus()
	@TestVisible final static Map<String, Schema.SObjectField> REPAIR_STATUS_FIELD_MAP = 
		new Map<String, Schema.SObjectField>();

	static final List<String> REPAIR_STATUS_ITERATION_ORDER = new List<String>();

	public static List<Schema.SObjectField> getRepairStatusFields() {
		List<Schema.SObjectField> res = new List<Schema.SObjectField>();
		for (String k : REPAIR_STATUS_ITERATION_ORDER) {
			res.add(REPAIR_STATUS_FIELD_MAP.get(k));
		}
		return res;
	}

	static void putRepairStatus(String subject, Schema.SObjectField field) {
		REPAIR_STATUS_FIELD_MAP.put(subject, field);
		REPAIR_STATUS_ITERATION_ORDER.add(subject);
	}

	static{
		putRepairStatus(TASK_MANAGE_REPAIRS_PAINTLESS_DENT_REMOVAL, Schema.Processing_Pipeline__c.Paintless_Dent_Removal_Repair_Status__c);
		putRepairStatus(TASK_MANAGE_REPAIRS_COSMETIC, Schema.Processing_Pipeline__c.Cosmetic_Repair_Status__c);
		putRepairStatus(TASK_MANAGE_REPAIRS_MECHANICAL, Schema.Processing_Pipeline__c.Mechanical_Repair_Status__c);
		putRepairStatus(TASK_MANAGE_REPAIRS_SMOG, Schema.Processing_Pipeline__c.Smog_Repair_Status__c);
	}

	static void setupPipelinesForOpportunities(Map<Id, Opportunity> opportunities, Workflow workflow) {
		if (opportunities.isEmpty()) {
			return;
		}

		List<Processing_Pipeline__c> existingPipelines = [
				SELECT Id, Seller_Opportunity_ID__c
				FROM Processing_Pipeline__c
				WHERE Seller_Opportunity_ID__c IN :opportunities.keySet()
		];

		Set<Id> newOpportunityIds = new Set<Id>(opportunities.keySet());
		for (Processing_Pipeline__c p: existingPipelines) {
			newOpportunityIds.remove(p.Seller_Opportunity_ID__c);
			workflow.addEvent(Event.PIPELINE_REACTIVATED, p.Id);
		}

		List<Processing_Pipeline__c> newPipelines = new List<Processing_Pipeline__c>();
		for (Id newId : newOpportunityIds) {
			newPipelines.add(new Processing_Pipeline__c(Seller_Opportunity_ID__c = newId));
		}
		insert newPipelines;

		for (Processing_Pipeline__c pipeline : newPipelines) {
			workflow.addEvent(Event.PIPELINE_CREATED, pipeline.Id);
		}
	}

	static void closePipelinesForOpportunities(List<Id> opportunityIds, Workflow workflow) {
		if (opportunityIds.isEmpty()) {
			return;
		}

		List<Processing_Pipeline__c> toCancel = [SELECT Id FROM Processing_Pipeline__c WHERE Seller_Opportunity_ID__c IN :opportunityIds];
		for (Processing_Pipeline__c pipeline : toCancel) {
			workflow.addEvent(Event.PIPELINE_CANCELED, pipeline.Id);
		}
	}

	public static String getInspectionUrl(Id inspectionId, Boolean editable) {
		String relPath = 'inspect/' + inspectionId;
		Map<String, String> parameters = new Map<String, String>();
		if (editable) {
			parameters.put('mode', 'edit');
		}
		return ShiftPages.getShiftcarsAdminUrl(relPath, parameters);
	}

	// Creates new workflows when an opportunity moves to prepare and cancels existing ones when
	// an opportunity is lost.
	public static void processStageChanges(List<Shift_Stage_Change__c> changes, Map<Id, Opportunity> opportunities) {
		// TODO: It would be good to break apart the new pipeline creation from the lost
		// pipelines, and not explicitly need to add the PIPELINE_CREATED event
		// (AbstractWorkflow should pick that up). But there is currently something subtle about
		// our ordering that is not allowing that to work, and it needs more attention as a
		// followon task (https://shift.phacility.com/T1687)
		Map<Id, Opportunity> enteredPrepare = new Map<Id, Opportunity>();
		List<Id> lostOpportunityIds = new List<Id>();
		for (Shift_Stage_Change__c change : changes) {
			if (change.To_Stage__c == ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE) {
				if (enteredPrepare.containsKey(change.Opportunity_ID__c)) {
					opportunities.get(change.Opportunity_ID__c).addError('attempted concurrent re-entry into prepare stage');
					continue;
				}
				enteredPrepare.put(change.Opportunity_ID__c, opportunities.get(change.Opportunity_ID__c));
			} else if (change.From_Stage__c == ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE && change.To_Stage__c == ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST) {
				lostOpportunityIds.add(change.Opportunity_ID__c);
			}
		}

		Workflow w = new Workflow();
		setupPipelinesForOpportunities(enteredPrepare, w);
		closePipelinesForOpportunities(lostOpportunityIds, w);
		w.applyUpdates();
	}

	public static void processInspectionChanges(Map<Id, Inspection__c> previous, List<Inspection__c> changes) {
		List<Id> pipelineIds = new List<Id>();
		for (Inspection__c change : changes) {
			if (!previous.get(change.Id).Complete__c && change.Complete__c) {
				pipelineIds.add(change.Processing_Pipeline_ID__c);
			}
		}
		if (pipelineIds.isEmpty()) {
			return;
		}
		// TODO: add an explicit task id to the inspection so we can skip this
		// query (https://shift.phacility.com/T1687)
		List<Task> inspectionTasks = [
			SELECT Id FROM Task WHERE Subject = :TASK_INSPECT_MECHANICAL AND WhatId IN :pipelineIds
		];
		for (Task t : inspectionTasks) {
			t.Status = ShiftConstants.TASK_STATUS_COMPLETED;
		}
		update inspectionTasks;
	}

	// an Event is logged as an Action (see EventAdder) on some task completion
	// or node readiness, and acted upon by our Workflow in handleUpdates().
	// It's likely that this notion of event tracking/handling
	// will be something we push up into ShiftWorkflows.AbstractWorkflow, but
	// will wait to see how other workflows shape up before doing that
	// refactor.
	enum Event {
		TOP_FEATURES_COMPLETE,
		REPAIR_MANAGEMENT_AFFECTED,
		INSPECTION_COMPLETE,
		REQUESTING_WHOLESALE_APPROVAL,
		GOT_SELLER_APPROVAL,
		PHOTOGRAPHY_DONE,
		PIPELINE_CANCELED,
		PIPELINE_COMPLETED,
		PIPELINE_CREATED,
		PIPELINE_REACTIVATED
	}

	// Represents the core logic of the props workflow.
	class Workflow extends ShiftWorkflow.AbstractInstance {
		final Map<Id, Opportunity> opportunityUpdates = new Map<Id, Opportunity>();
		final Map<Event, Set<Id>> eventMap = new Map<Event, Set<Id>>();

		public Workflow() { 
			super(Processing_Pipeline__c.class, WORKFLOW_IDENTIFIER, WORKFLOW_VERSION); 
			setFieldOnTask(FIELD_IS_TOP_FEATURES_DONE, TASK_TOP_FEATURES);
			setFieldOnTask(FIELD_IS_COSMETIC_INSPECTION_DONE, TASK_INSPECT_COSMETIC);
			setFieldOnTask(FIELD_IS_INSPECTION_DONE, TASK_INSPECT_MECHANICAL);
			setFieldOnTask(FIELD_IS_REPAIR_ASSESSMENT_DONE, TASK_ASSESS_REPAIRS);
			setFieldOnTask(FIELD_GOT_SELLER_APPROVAL, TASK_GET_SELLER_APPROVAL);
			setFieldOnTask(FIELD_IS_WASH_EXTERIOR_DONE, TASK_WASH_EXTERIOR);
			setFieldOnTask(FIELD_IS_WASH_INTERIOR_DONE, TASK_WASH_INTERIOR);
			setFieldOnTask(FIELD_IS_CONDITION_REPORT_HANDLED, TASK_HANDLE_CONDITION_REPORT);
			setFieldOnTask(FIELD_IS_LISTING_COPY_DONE, TASK_WRITE_LISTING);
			setFieldOnTask(FIELD_IS_PHOTOGRAPHY_DONE, TASK_PHOTOGRAPH_VEHICLE);
			addTaskObserver(new RepairTaskObserver());
			setFieldOnTask(FIELD_IS_QUALITY_CONTROL_CHECK_DONE, TASK_FINAL_PROCESSING_QUALITY_CONTROL_CHECK);
			startTaskOnFields(TASK_INSPECT_MECHANICAL, ShiftConstants.TASK_TEAM_INSPECTION, FIELD_IS_COSMETIC_INSPECTION_DONE);
			startActionOnFields(new EventAdder(Event.TOP_FEATURES_COMPLETE), FIELD_IS_TOP_FEATURES_DONE);
			startTaskOnFields(
				TASK_WRITE_LISTING, ShiftConstants.TASK_TEAM_COPYWRITING,
				FIELD_IS_TOP_FEATURES_DONE, FIELD_IS_CONDITION_REPORT_HANDLED
			);
			startActionOnFields(
				actionList(
					new EventAdder(Event.INSPECTION_COMPLETE),
					actionAddTask(TASK_ASSESS_REPAIRS, ShiftConstants.TASK_TEAM_ESTIMATES_AND_APPROVALS)
				),
				FIELD_IS_INSPECTION_DONE
			);
			startActionOnFields(new RepairAssessmentCompleter(), FIELD_IS_REPAIR_ASSESSMENT_DONE);
			startActionOnFields(new EventAdder(Event.GOT_SELLER_APPROVAL), FIELD_GOT_SELLER_APPROVAL);
			startActionOnFields(new EventAdder(Event.REPAIR_MANAGEMENT_AFFECTED), FIELD_IS_CONDITION_REPORT_HANDLED);
			startTaskOnFields(TASK_WASH_EXTERIOR, ShiftConstants.TASK_TEAM_DETAILING, FIELD_IS_REPAIR_MANAGEMENT_DONE);
			startTaskOnFields(TASK_WASH_INTERIOR, ShiftConstants.TASK_TEAM_DETAILING, FIELD_IS_WASH_EXTERIOR_DONE);
			startTaskOnFields(TASK_PHOTOGRAPH_VEHICLE, ShiftConstants.TASK_TEAM_PHOTOGRAPHY, FIELD_IS_WASH_INTERIOR_DONE);
			startActionOnFields(new EventAdder(Event.PHOTOGRAPHY_DONE), FIELD_IS_PHOTOGRAPHY_DONE);
			startTaskOnFields(
				TASK_FINAL_PROCESSING_QUALITY_CONTROL_CHECK, ShiftConstants.TASK_TEAM_PROCESSING_QUALITY_CONTROL,
				FIELD_IS_LISTING_COPY_DONE, FIELD_IS_PHOTOGRAPHY_DONE
			);
			startActionOnFields(new EventAdder(Event.PIPELINE_COMPLETED), FIELD_IS_QUALITY_CONTROL_CHECK_DONE);
		}

		Processing_Pipeline__c pipelineUpdate(Id pid) {
			return (Processing_Pipeline__c) getStateUpdate(pid);
		}

		Id pipelineRegionId(Processing_Pipeline__c p) {
			return p.Seller_Opportunity_ID__r.Vehicle_ID__r.Listing_Region_ID__c;
		}

		Opportunity opportunityUpdateForPipeline(Processing_Pipeline__c p) {
			Id oid = p.Seller_Opportunity_ID__c;
			Opportunity res = opportunityUpdates.get(oid);
			if (res == null) {
				res = new Opportunity(Id = oid);
				opportunityUpdates.put(oid, res);
			}
			return res;
		}

		void addEvent(Event event, Id src) {
			Set<Id> s = eventMap.get(event);
			if (s == null) {
				s = new Set<Id>();
				eventMap.put(event, s);
			}
			s.add(src);
		}

		// Returns pipelines with field data needed to process the various
		// events in eventMap. Not all pipelines or fields are needed for all
		// updates, but we only want to make a single query to get our working
		// context.
		List<Processing_Pipeline__c> getStoredPipelines() {
			Set<Id> ids = new Set<Id>();
			for (Set<Id> s : eventMap.values()) {
				ids.addAll(s);
			}
			for (Task t : tasks) {
				ids.add(t.WhatId);
			}
			if (ids.isEmpty()) {
				return new List<Processing_Pipeline__c>();
			}
			return [
				SELECT 
					Id,
					Cosmetic_Repair_Status__c,
					Is_Direct_To_Wholesale__c,
					Mechanical_Repair_Status__c,
					Name,
					Paintless_Dent_Removal_Repair_Status__c,
					Smog_Repair_Status__c,
					Seller_Opportunity_ID__c,
					Seller_Opportunity_ID__r.Direct_To_Wholesale__c,
					Seller_Opportunity_ID__r.Vehicle_ID__c,
					Seller_Opportunity_ID__r.Vehicle_ID__r.Name,
					Seller_Opportunity_ID__r.Vehicle_ID__r.Listing_Region_ID__c,
					Seller_Opportunity_ID__r.StageName,
					(SELECT Item_Count__c FROM Vehicle_Options__r),
					(SELECT Complete__c FROM Inspections__r),
					(SELECT Id, IsClosed, Status, Subject FROM Tasks)
				FROM Processing_Pipeline__c
				WHERE Id IN :ids
			];
		}

		// Returns only Processing_Pipeline__c objects for which event was registered during
		// this run
		List<Processing_Pipeline__c> withEvent(List<Processing_Pipeline__c> pipelines, Event event) {
			List<Processing_Pipeline__c> res = new List<Processing_Pipeline__c>();
			Set<Id> s = eventMap.get(event);
			if (s == null) {
				return res;
			}
			for (Processing_Pipeline__c p : pipelines) {
				if (s.contains(p.Id)) {
					res.add(p);
				}
			}
			return res;
		}
		
		void addWholesaleTask(Processing_Pipeline__c pipeline) {
			for (Schema.SObjectField f : REPAIR_STATUS_FIELD_MAP.values()) {
				pipelineUpdate(pipeline.Id).put(f, REPAIR_STATUS_UNNECESSARY);
			}
			addTask(new Task(
				WhatId = pipeline.Seller_Opportunity_ID__c,
				Subject = ShiftOpportunities.SUBJECT_EXECUTE_WHOLESALE,
				OwnerId = ShiftUsers.unownedUserId(),
				Team__c = ShiftConstants.TASK_TEAM_WHOLESALE,
				Workflow_Identifier__c = ShiftOpportunities.WORKFLOW_IDENTIFIER_WHOLESALING,
				Region_ID__c = pipelineRegionId(pipeline)
			));
			addEvent(Event.PIPELINE_CANCELED, pipeline.Id);
			Opportunity o = opportunityUpdateForPipeline(pipeline);
			o.Direct_To_Wholesale__c = true;
			o.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		}

		void deleteCanceledTasks(List<Processing_Pipeline__c> current) {
			List<Task> toCancel = new List<Task>();
			current = withEvent(current, Event.PIPELINE_CANCELED);
			for (Processing_Pipeline__c pipeline : current) {
				for (Task t : pipeline.Tasks) {
					if (t.IsClosed) {
						continue;
					}
					toCancel.add(new Task(
						Id = t.Id, 
						Status = ShiftConstants.TASK_STATUS_CANCELED
					));
				}
			}
			update toCancel;
		}

		void insertVehicleOptions(List<Processing_Pipeline__c> current) {
			List<Vehicle_Options__c> options = new List<Vehicle_Options__c>();
			current = withEvent(current, Event.PIPELINE_CREATED);
			for (Processing_Pipeline__c pipeline : current) {
				if (pipeline.Seller_Opportunity_ID__r.Direct_To_Wholesale__c) {
					continue;
				}
				options.add(new Vehicle_Options__c(
					Processing_Pipeline_ID__c = pipeline.Id,
					Forcebase_Deal_ID__c = pipeline.Seller_Opportunity_ID__c,
					Vehicle_ID__c = pipeline.Seller_Opportunity_ID__r.Vehicle_ID__c,
					Vehicle_Description__c = pipeline.Seller_Opportunity_ID__r.Vehicle_ID__r.Name
				));
			}
			insert options;
		}

		void handleRequestsForWholesaleApproval(List<Processing_Pipeline__c> current) {
			current = withEvent(current, Event.REQUESTING_WHOLESALE_APPROVAL);
			for (Processing_Pipeline__c p : current) {
				addEvent(Event.PIPELINE_CANCELED, p.Id);
			}
		}

		void handleRepairApprovals(List<Processing_Pipeline__c> current) {
			current = withEvent(current, Event.GOT_SELLER_APPROVAL);
			for (Processing_Pipeline__c p : current) {
				if (p.Is_Direct_To_Wholesale__c) {
					addWholesaleTask(p);
				} else {
					addTask(p.Id, TASK_HANDLE_CONDITION_REPORT, ShiftConstants.TASK_TEAM_ESTIMATES_AND_APPROVALS);
				}
			}
		}

		void handlePhotoCompletions(List<Processing_Pipeline__c> current) {
			current = withEvent(current, Event.PHOTOGRAPHY_DONE);
			for (Processing_Pipeline__c pipeline : current) {
				addTask(new Task(
					WhatId = pipeline.Seller_Opportunity_ID__c,
					Subject = ShiftOpportunities.SUBJECT_EDIT_VEHICLE_PHOTOS,
					Team__c = ShiftConstants.TASK_TEAM_MERCHANDISING,
					OwnerId = ShiftUsers.unownedUserId()
				));
			}
		}

		// Handler for Event.REPAIR_MANAGEMENT_AFFECTED. After a repair management task is
		// completed, or the first time we move into the repair management node, this is called
		// and either kicks off the next repair management task that can start or marks repair
		// management as done if none remain. In later revisions, each repair will likely
		// become its own dependent workflow, so the implementation here will change slightly to
		// determine which dependent workflows can be started. 
		void advanceRepairs(List<Processing_Pipeline__c> current) {
			current = withEvent(current, Event.REPAIR_MANAGEMENT_AFFECTED);
			for (Processing_Pipeline__c pipeline : current) {
				for (String subject : REPAIR_STATUS_ITERATION_ORDER) {
					Schema.SObjectField f = REPAIR_STATUS_FIELD_MAP.get(subject);
					String status = (String) pipeline.get(f);
					if (status == REPAIR_STATUS_AWAITING_REPAIR) {
						getStateUpdate(pipeline.Id).put(f, REPAIR_STATUS_IN_PROGRESS);
						addTask(pipeline.Id, subject, ShiftConstants.TASK_TEAM_REPAIR_MANAGEMENT);
						return;
					}
				}
				pipelineUpdate(pipeline.Id).Is_Repair_Management_Done__c = true;
			}
		}

		void setPipelineCompletions(List<Processing_Pipeline__c> current) {
			List<Opportunity> opportunities = new List<Opportunity>();
			current = withEvent(current, Event.PIPELINE_COMPLETED);
			for (Processing_Pipeline__c pipeline : current) {
				if (pipeline.Seller_Opportunity_ID__r.StageName != ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE) {
					continue;
				}
				opportunities.add(new Opportunity(
					Id = pipeline.Seller_Opportunity_ID__c,
					StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL
				));
			}
			update opportunities;
		}

		void checkInspectionCompletions(List<Processing_Pipeline__c> current) {
			current = withEvent(current, Event.INSPECTION_COMPLETE);
			for (Processing_Pipeline__c pipeline : current) {
				if (!pipeline.Inspections__r.get(0).Complete__c) {
					errorTargets.get(pipeline.Id).addError('attempt to complete inspection task but inspection is not complete');
				}
			}
		}

		void checkTopFeaturesCompletions(List<Processing_Pipeline__c> current) {
			current = withEvent(current, Event.TOP_FEATURES_COMPLETE);
			for (Processing_Pipeline__c p : current) {
				if (p.Vehicle_Options__r.get(0).Item_Count__c < MIN_OPTIONS_FOR_TOP_FEATURES) {
					errorTargets.get(p.Id).addError('attempt to complete top features task but top features has fewer than ' + MIN_OPTIONS_FOR_TOP_FEATURES);
				}
			}
		}

		Inspection__c createInspection(Processing_Pipeline__c pipeline) {
			return new Inspection__c(
				Processing_Pipeline_ID__c = pipeline.Id,
				Forcebase_Deal_ID__c = pipeline.Seller_Opportunity_ID__c,
				Region_ID__c = pipelineRegionId(pipeline),
				Vehicle_ID__c = pipeline.Seller_Opportunity_ID__r.Vehicle_ID__c,
				Vehicle_Description__c = pipeline.Seller_Opportunity_ID__r.Vehicle_ID__r.Name
			);
		}

		void processNewPipelines(List<Processing_Pipeline__c> current) {
			List<Inspection__c> inspections = new List<Inspection__c>();
			current = withEvent(current, Event.PIPELINE_CREATED);
			for (Processing_Pipeline__c pipeline : current) {
				if (pipeline.Seller_Opportunity_ID__r.Direct_To_Wholesale__c) {
					addWholesaleTask(pipeline);
					continue;
				} 
				addTask(pipeline.Id, TASK_TOP_FEATURES, ShiftConstants.TASK_TEAM_TOP_FEATURES);
				inspections.add(createInspection(pipeline));
				addTask(pipeline.Id, TASK_INSPECT_COSMETIC, ShiftConstants.TASK_TEAM_INSPECTION);
			}
			insert inspections;
		}

		void reopenTasks(List<Processing_Pipeline__c> current) {
			List<Task> toReopen = new List<Task>();
			current = withEvent(current, Event.PIPELINE_REACTIVATED);
			for (Processing_Pipeline__c pipeline : current) {
				for (Task t : pipeline.Tasks) {
					if (t.Status == ShiftConstants.TASK_STATUS_CANCELED) {
						toReopen.add(new Task(
							Id = t.Id,
							Status = ShiftConstants.TASK_STATUS_NOT_STARTED
						));
					}
				}
			}
			update toReopen;
		}

		void setTaskRegions(List<Processing_Pipeline__c> current) {
			Map<Id, Processing_Pipeline__c> m = new Map<Id, Processing_Pipeline__c>(current);
			for (Task t : tasks) {
				Processing_Pipeline__c pipeline = m.get(t.WhatId);
				if (pipeline == null) {
					continue;
				}
				t.Region_ID__c = pipelineRegionId(pipeline);
			}
		}

		protected override void handleUpdates() {
			super.handleUpdates();
			List<Processing_Pipeline__c> current = getStoredPipelines();
			advanceRepairs(current);
			processNewPipelines(current);
			reopenTasks(current);
			setPipelineCompletions(current);
			checkInspectionCompletions(current);
			checkTopFeaturesCompletions(current);
			insertVehicleOptions(current);
			handleRequestsForWholesaleApproval(current);
			handleRepairApprovals(current);
			handlePhotoCompletions(current);
			setTaskRegions(current);
			// This comes after the methods above since some might cancel a pipeline
			deleteCanceledTasks(current);
			update opportunityUpdates.values();
		}

		// Disallows a repair status field change after completion of repair management
		void checkErrorRepairManagementChangeAfterRepairManagementCompletion(Map<Id, SObject> oldStates, List<SObject> newStates) {
			for (SObject newState : newStates) {
				Processing_Pipeline__c upd = (Processing_Pipeline__c) newState;
				Processing_Pipeline__c old = (Processing_Pipeline__c) oldStates.get(upd.Id);
				if (!old.Is_Repair_Management_Done__c) {
					continue;
				}
				List<String> errFields = new List<String>();
				for (Schema.SObjectField f : REPAIR_STATUS_FIELD_MAP.values()) {
					if (old.get(f) != upd.get(f)) {
						errFields.add(f.getDescribe().getLabel());
					}
				}
				if (!errFields.isEmpty()) {
					// TODO (https://shift.phacility.com/T1687): add some mechanism in Workflow
					// to more declaratively catch errors of this nature (attempt to change Node
					// X after a previous completion)
					upd.addError('attempt to change status field(s) for repairs after repair management is done: ' + String.join(errFields, ', '));
				}
			}
		}

		public override void stateObjectsUpdated(Map<Id, SObject> oldStates, List<SObject> newStates) {
			checkErrorRepairManagementChangeAfterRepairManagementCompletion(oldStates, newStates);
			super.stateObjectsUpdated(oldStates, newStates);
		}
	}

	class EventAdder implements ShiftWorkflow.Action {
		final Event event;
		EventAdder(Event event) { this.event = event; }

		public void execute(SObject state, ShiftWorkflow.Instance instance) {
			((Workflow) instance).addEvent(event, state.Id);
		}
	}

	class RepairTaskObserver extends ShiftWorkflow.CompletionObserver {
		RepairTaskObserver() { super(REPAIR_STATUS_FIELD_MAP.keySet()); }

		public override void taskCompleted(Task newTask, ShiftWorkflow.Instance instance) {
			Schema.SObjectField f = REPAIR_STATUS_FIELD_MAP.get(newTask.Subject);
			System.assert(f != null, 'no repair status field mapped to task: ' + newTask);
			Id pipelineId = newTask.WhatId;
			instance.getStateUpdate(pipelineId).put(f, ShiftConstants.TASK_STATUS_COMPLETED);
			((Workflow) instance).addEvent(Event.REPAIR_MANAGEMENT_AFFECTED, pipelineId);
		}
	}

	// Validates the decision of wholesale/sell and validates that we have the
	// correct context in either case to continue
	class RepairAssessmentCompleter implements ShiftWorkflow.Action {
		Boolean validateCanMoveToWholesale(Processing_Pipeline__c pipeline) {
			Boolean ok = true;
			for (Schema.SObjectField f : REPAIR_STATUS_FIELD_MAP.values()) {
				String status = (String) pipeline.get(f);
				if (!(status == null || status == REPAIR_STATUS_UNNECESSARY)) {
					pipeline.addError('attempt to send to wholesale but repair status for field "' + f.getDescribe().getLabel() + '" (' + f.getDescribe().getName() + ') is "' + status + '"');
					ok = false;
				}
			}
			return ok;
		}

		Boolean validateCanGetRepairApproval(Processing_Pipeline__c pipeline) {
			if (pipeline.Is_Direct_To_Wholesale__c) {
				return validateCanMoveToWholesale(pipeline);
			}
			Boolean ok = true;
			for (Schema.SObjectField f : REPAIR_STATUS_FIELD_MAP.values()) {
				String val = (String) pipeline.get(f);
				if (VALID_STARTING_REPAIR_STATUSES.contains(val)) {
					continue;
				}
				ok = false;
				if (val == null) {
					pipeline.addError('attempt to complete repair assessment without value for "' + f.getDescribe().getLabel() + '"');
					continue;
				} 
				pipeline.addError('attempt to complete repair assessment but value for "' + f.getDescribe().getLabel() + '" is "' + val + '"');
			}
			return ok;
		}

		public void execute(SObject state, ShiftWorkflow.Instance instance) {
			Processing_Pipeline__c pipeline = (Processing_Pipeline__c) state;
			Workflow w = (Workflow) instance;
			if (validateCanGetRepairApproval(pipeline)) {
				w.addTask(pipeline.Id, TASK_GET_SELLER_APPROVAL, ShiftConstants.TASK_TEAM_ESTIMATES_AND_APPROVALS);
			}
			if (pipeline.Is_Direct_To_Wholesale__c) {
				w.addEvent(Event.REQUESTING_WHOLESALE_APPROVAL, pipeline.Id);
			}
		}
	}

	class FormatSupport extends ShiftWorkflow.DefaultFormatSupport {
		public override Map<Id, String> getTaskReferenceLabels(List<Task> tasks, ShiftWorkflow.Instance instance) {
			Set<Id> whatIds = new Set<Id>();
			for (Task t : tasks) {
				whatIds.add(t.WhatId);
			}
			Map<Id, Processing_Pipeline__c> pipelineMap = new Map<Id, Processing_Pipeline__c>([
				SELECT Id, Seller_Opportunity_ID__r.Name
				FROM Processing_Pipeline__c
				WHERE Id IN :whatIds
			]);
			Map<Id, String> res = new Map<Id, String>();
			for (Task t : tasks) {
				Processing_Pipeline__c pipeline = pipelineMap.get(t.WhatId);
				if (pipeline == null) {
					continue;
				}
				res.put(t.Id, pipeline.Seller_Opportunity_ID__r.Name);
			}
			return res;
		}

		public override String getWorkflowLabel(ShiftWorkflow.Instance instance) { 
			return LABEL; 
		}

		public override PageReference getTaskPageReference(Id taskId, ShiftWorkflow.Instance instance) {
			PageReference res = Page.ShiftProcessingTask;
			res.getParameters().put('id', taskId);
			return res;
		}

		public override Set<Id> getPriorityTaskIds(List<Task> tasks, ShiftWorkflow.Instance instance) {
			Set<Id> whatIds = new Set<Id>();
			for (Task t : tasks) {
				whatIds.add(t.WhatId);
			}
			Set<Id> priorityProcessingPipelineIds = new Map<Id, Processing_Pipeline__c>([
				SELECT Id
				FROM Processing_Pipeline__c
				WHERE
					Id IN :whatIds AND
					Seller_Opportunity_ID__r.Vehicle_ID__r.Is_Priority__c = TRUE
			]).keySet();
			Set<Id> res = new Set<Id>();
			for (Task t : tasks) {
				if (priorityProcessingPipelineIds.contains(t.WhatId)) {
					res.add(t.Id);
				}
			}
			return res;
		}
	}

	public static void beforeUpdate(Map<Id, Processing_Pipeline__c> originalValues, Map<Id, Processing_Pipeline__c> updatedValues){
		validateNoteVersion(updatedValues);
	}

	public static void loadWorkflows() { 
		ShiftWorkflow.registerInstanceType(WORKFLOW_IDENTIFIER, Workflow.class); 
		ShiftWorkflow.registerFormatSupport(WORKFLOW_IDENTIFIER, FormatSupport.class);
	}

	public static void validateNoteVersion(Map<Id, Processing_Pipeline__c> updatedValues) {
		Set<Id> pipelineIds = updatedValues.keySet();
		List<Processing_Pipeline__c> originalList = [
				SELECT Id, Props_Tracker_Notes_Version__c, Props_Tracker_Notes__c FROM Processing_Pipeline__c WHERE Id in :pipelineIds FOR UPDATE
		];

		for (Processing_Pipeline__c original : originalList) {
			Processing_Pipeline__c updated = updatedValues.get(original.Id);

			Decimal expectedVersionDecimal = updated.Props_Tracker_Notes_Version__c;
			if (expectedVersionDecimal == null) {
				expectedVersionDecimal = 0;
			}

			Decimal originalVersionDecimal = original.Props_Tracker_Notes_Version__c;
			if (originalVersionDecimal == null) {
				originalVersionDecimal = 0;
			}

			Integer expectedVersionNumber = expectedVersionDecimal.intValue();
			Integer originalVersionNumber = originalVersionDecimal.intValue();

			if (original.Props_Tracker_Notes__c == updated.Props_Tracker_Notes__c) {
				updated.Props_Tracker_Notes_Version__c = originalVersionNumber;
			} else if (originalVersionNumber != expectedVersionNumber) {
				updated.addError(ERROR_NOTES_VERSION_STALE);
			} else {
				updated.Props_Tracker_Notes_Version__c = originalVersionNumber + 1;
			}
		}
	}
}