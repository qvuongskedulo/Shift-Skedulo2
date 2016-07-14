public with sharing class ShiftProcessingTaskController {
	static final String REPAIR_STATUS_OPTION_CHOOSE = '<choose>';

	static final String SELLER_APPROVAL_NEXT_STEP_BEGIN_REPAIRS = 'Begin Repairs';
	static final String SELLER_APPROVAL_NEXT_STEP_DIRECT_TO_WHOLESALE = 'Direct to Wholesale';
	static final Integer LISTING_TITLE_MAXIMUM_LENGTH = 70;

	static final List<String> REPAIR_STATUS_OPTIONS = 
		new List<String>(ShiftProcessingPipeline.VALID_STARTING_REPAIR_STATUSES);
	
	// to ensure a deterministic order within all select lists on the page
	static { REPAIR_STATUS_OPTIONS.sort(); }

	class PageException extends Exception {}

	PageReference reloadThisPage() {
		PageReference ref = ApexPages.currentPage();
		ref.setRedirect(true);
		return ref;
	}

	Task task;
	public Processing_Pipeline__c pipeline { get; private set; }

	public Id vehicleId { get { return pipeline.Seller_Opportunity_ID__r.Vehicle_ID__c; } }
	public String vehicleName { get { return pipeline.Seller_Opportunity_ID__r.Vehicle_ID__r.Name; } }

	public Id sellerOpportunityId { get { return pipeline.Seller_Opportunity_ID__c; } }
	public String sellerOpportunityName { get { return pipeline.Seller_Opportunity_ID__r.Name; } }

	public List<Opportunity_Note__c> processingNotes { get; private set; }
	public Boolean hasProcessingNotes { get { return !processingNotes.isEmpty(); } }

	public Opportunity_Note__c processingNoteToAdd { get; set; }

	Id inspectionId {
		get {
			if (!(task.Subject == ShiftProcessingPipeline.TASK_INSPECT_MECHANICAL || task.Subject == ShiftProcessingPipeline.TASK_INSPECT_COSMETIC || task.Subject == ShiftProcessingPipeline.TASK_HANDLE_CONDITION_REPORT)) {
				return null;
			}
			return pipeline.Inspections__r.get(0).Id;
		}
	}

	public Boolean hasInspection { get { return inspectionId != null; } }

	public String inspectionUrl {
		get {
			return ShiftProcessingPipeline.getInspectionUrl(inspectionId, task.Subject != ShiftProcessingPipeline.TASK_HANDLE_CONDITION_REPORT);
		}
	}

	public Id vehicleOptionsId { get; private set; }
	public Vehicle_Options_Item__c vehicleOptionsItem { get; private set; }
	public List<Vehicle_Options_Item__c> vehicleOptionsItems { get; private set; }
	public Boolean hasVehicleOptionsItems { get { return !vehicleOptionsItems.isEmpty(); } }
	public Boolean isTopFeatures { get { return vehicleOptionsItem != null; } }
	public Vehicle__c vehicle { get; private set; }
	public Boolean isPhotographVehicle { get { return task.Subject == ShiftProcessingPipeline.TASK_PHOTOGRAPH_VEHICLE; } }
	public Boolean isWriteListing { get { return task.Subject == ShiftProcessingPipeline.TASK_WRITE_LISTING; } }

	public PageReference doAddOptionsItem() {
		if (vehicleOptionsItem.Name == null) {
			ShiftPages.addErrorMessage('vehicle option needs a name');
			return null;
		}
		insert vehicleOptionsItem;
		return reloadThisPage();
	}

	public PageReference doAddProcessingNote() {
		if (processingNoteToAdd.Content__c == null || processingNoteToAdd.Content__c.trim() == '') {
			ShiftPages.addErrorMessage('note has no content');
			return null;
		}
		insert processingNoteToAdd;
		return reloadThisPage();
	}

	class RepairStatus {
		final ShiftProcessingTaskController controller;
		final Schema.SObjectField field;

		RepairStatus(ShiftProcessingTaskController controller, Schema.SObjectField field) {
			this.controller = controller;
			this.field = field;
		}

		public String label { get { return field.getDescribe().getLabel(); } }
		
		public String currentValue { 
			get {
				String res = (String) controller.pipeline.get(field);
				if (res == null) {
					return REPAIR_STATUS_OPTION_CHOOSE;
				}
				return res;
			}
			
			set { 
				if (value == REPAIR_STATUS_OPTION_CHOOSE) {
					value = null;
				}
				controller.pipeline.put(field, value); 
			}
		}

		public List<SelectOption> selectOptions { 
			get {
				List<SelectOption> res = new List<SelectOption>{
					new SelectOption(REPAIR_STATUS_OPTION_CHOOSE, REPAIR_STATUS_OPTION_CHOOSE)
				};
				for (String status : REPAIR_STATUS_OPTIONS) {
					res.add(new SelectOption(status, status));
				}
				return res;
			}
		}
	}

	public Boolean isDirectToWholesale { get; set; }

	public List<RepairStatus> repairStatuses { get; private set; }

	public Boolean isAssessRepairs { get { return repairStatuses != null; } }

	class BeforeAssessRepairs implements ShiftCallable {
		final ShiftProcessingTaskController controller;

		BeforeAssessRepairs(ShiftProcessingTaskController controller) {
			this.controller = controller;
		}

		void validate() {
			controller.pipeline.Is_Direct_To_Wholesale__c = controller.isDirectToWholesale;
			if (controller.pipeline.Is_Direct_To_Wholesale__c) {
				return;
			}
			List<String> missing = new List<String>();
			for (RepairStatus rs : controller.repairStatuses) {
				if (rs.currentValue == REPAIR_STATUS_OPTION_CHOOSE) {
					missing.add('"' + rs.label + '"');
				}
			}
			if (!missing.isEmpty()) {
				throw new PageException('need to select a value for status(es): ' + String.join(missing, ', '));
			}
		}

		public Object call() {
			validate();
			update controller.pipeline;
			return null;
		}
	}

	public Boolean isGetSellerApproval {
		get { return task.Subject == ShiftProcessingPipeline.TASK_GET_SELLER_APPROVAL; }
	}

	public List<SelectOption> sellerApprovalNextSteps {
		get {
			return new List<SelectOption>{
				new SelectOption(SELLER_APPROVAL_NEXT_STEP_BEGIN_REPAIRS, SELLER_APPROVAL_NEXT_STEP_BEGIN_REPAIRS),
				new SelectOption(SELLER_APPROVAL_NEXT_STEP_DIRECT_TO_WHOLESALE, SELLER_APPROVAL_NEXT_STEP_DIRECT_TO_WHOLESALE)
			};
		}
	}
	
	public String sellerApprovalNextStep { get; set; }

	class BeforeGetSellerApproval implements ShiftCallable {
		ShiftProcessingTaskController controller;
		BeforeGetSellerApproval(ShiftProcessingTaskController controller) { this.controller = controller; }

		public Object call() {
			if (controller.sellerApprovalNextStep == null) {
				throw new PageException('Need to select a next step');
			}
			if (controller.sellerApprovalNextStep == SELLER_APPROVAL_NEXT_STEP_DIRECT_TO_WHOLESALE) {
				controller.pipeline.Is_Direct_To_Wholesale__c = true;
				update controller.pipeline;
			}
			return null;
		}
	}

	abstract class AbstractVehicleUpdate implements ShiftCallable {
		final ShiftProcessingTaskController controller;
		AbstractVehicleUpdate(ShiftProcessingTaskController controller) { this.controller = controller; }

		abstract void validateUpdate();

		public Object call() {
			validateUpdate();
			update controller.vehicle;
			return null;
		}
	}

	class BeforePhotographVehicle extends AbstractVehicleUpdate {
		BeforePhotographVehicle(ShiftProcessingTaskController controller) { super(controller); }

		override void validateUpdate() {
			if (controller.vehicle.Dropbox_Photos_URL__c == null) {
				throw new PageException('Please enter a photo url');
			}
		}
	}

	class BeforeWriteListing extends AbstractVehicleUpdate {
		BeforeWriteListing(ShiftProcessingTaskController controller) { super(controller); }

		override void validateUpdate() {
			if (controller.vehicle.Listing_Text__c == null || controller.vehicle.Listing_Title__c == null) {
				throw new PageException('Please enter listing title and text');
			}

			if (controller.vehicle.Listing_Title__c.length() > LISTING_TITLE_MAXIMUM_LENGTH) {
				throw new PageException('Listing title can only be ' + LISTING_TITLE_MAXIMUM_LENGTH + ' characters long.');
			}
		}
	}

	public ShiftCallable beforeComplete {
		get { 
			if (task.Subject == ShiftProcessingPipeline.TASK_ASSESS_REPAIRS) {
				return new BeforeAssessRepairs(this);
			}
			if (isGetSellerApproval) {
				return new BeforeGetSellerApproval(this);
			}
			if (isPhotographVehicle) {
				return new BeforePhotographVehicle(this);
			}
			if (isWriteListing) {
				return new BeforeWriteListing(this);
			}
			return null;
		}
	}
	
	void setupRepairApproval() {
		if (pipeline.Is_Direct_To_Wholesale__c) {
			sellerApprovalNextStep = SELLER_APPROVAL_NEXT_STEP_DIRECT_TO_WHOLESALE;
		} else {
			sellerApprovalNextStep = SELLER_APPROVAL_NEXT_STEP_BEGIN_REPAIRS;
		}
	}

	void setupRepairStatuses() {
		if (task.Subject != ShiftProcessingPipeline.TASK_ASSESS_REPAIRS) {
			return;
		}
		repairStatuses = new List<RepairStatus>();
		for (Schema.SObjectField f : ShiftProcessingPipeline.getRepairStatusFields()) {
			repairStatuses.add(new RepairStatus(this, f));
		}
	}

	void setupVehicleOptions() {
		if (task.Subject != ShiftProcessingPipeline.TASK_TOP_FEATURES) {
			return;
		}
		vehicleOptionsId = pipeline.Vehicle_Options__r.get(0).Id;
		vehicleOptionsItem = new Vehicle_Options_Item__c(Vehicle_Options__c = vehicleOptionsId);
		vehicleOptionsItems = [
			SELECT Name, Description__c 
			FROM Vehicle_Options_Item__c
			WHERE Vehicle_Options__c = :vehicleOptionsId
			ORDER BY Name ASC
		];
	}

	void setupProcessingNotes() {
		this.processingNotes = [
			SELECT Content__c, CreatedBy.Name, CreatedDate
			FROM Opportunity_Note__c
			WHERE Processing_Pipeline_ID__c = :pipeline.Id
			ORDER BY CreatedDate DESC
		];
		this.processingNoteToAdd = new Opportunity_Note__c(
			Opportunity_ID__c = pipeline.Seller_Opportunity_ID__c,
			Processing_Pipeline_ID__c = pipeline.Id
		);
	}

	void setupVehicle() {
		if (!isPhotographVehicle && !isWriteListing) {
			return;
		}
		vehicle = [
				SELECT Dropbox_Photos_URL__c,
						Listing_Text__c,
						Listing_Title__c,
						Craigslist_Top_Features__c
				FROM Vehicle__c
				WHERE Id = :vehicleId
		];
	}

	public Boolean allowsCompletion { 
		get { 
			if (task.Subject == ShiftProcessingPipeline.TASK_INSPECT_MECHANICAL) {
				return false;
			}
			if (isTopFeatures) {
				return vehicleOptionsItems.size() >= ShiftProcessingPipeline.MIN_OPTIONS_FOR_TOP_FEATURES;
			}
			return true;
		} 
	}

	public ShiftProcessingTaskController() {
		Id taskId = ShiftPages.getIdParameter();
		task = [SELECT Id, Subject, WhatId FROM Task WHERE Id = :taskId];
		pipeline = [
			SELECT 
				Id, 
				Is_Direct_To_Wholesale__c,
				Seller_Opportunity_ID__c, 
				Seller_Opportunity_ID__r.Name,
				Seller_Opportunity_ID__r.Vehicle_ID__c,
				Seller_Opportunity_ID__r.Vehicle_ID__r.Name,
				Paintless_Dent_Removal_Repair_Status__c,
				Cosmetic_Repair_Status__c,
				Mechanical_Repair_Status__c,
				Smog_Repair_Status__c,
				(SELECT Id FROM Inspections__r),
				(SELECT Id FROM Vehicle_Options__r)
			FROM Processing_Pipeline__c
			WHERE Id = :task.WhatId
		];
		setupRepairStatuses();
		setupRepairApproval();
		setupVehicleOptions();
		setupProcessingNotes();
		setupVehicle();
	}
}