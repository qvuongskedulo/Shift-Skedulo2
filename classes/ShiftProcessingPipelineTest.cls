@IsTest class ShiftProcessingPipelineTest {

	static final String REGION_SHIFT_KEY_TEST_LISTING_REGION = 'testing/props-listing-region';

	@TestSetup static void setup() {
		ShiftTesting.setup();
		Region__c region = new Region__c(
			Shift_Key__c = REGION_SHIFT_KEY_TEST_LISTING_REGION,
			Timezone__c = ShiftTesting.REGION_TIMEZONE_TESTING
		);
		insert region;
		insert new Parking_Lot__c(
			Name = 'Listing Region Lot',
			Address__c = 'Listing Region Address',
			Region_ID__c = region.Id,
			Is_Region_Primary__c = true,
			Geolocation__Latitude__s = 1.6180,
			Geolocation__Longitude__s = 1.4142
		);
	}

	// lazily set by getTestListingRegionId(), but null at the beginning of each test
	static Id testListingRegionId;

	static Id getTestListingRegionId() {
		if (testListingRegionId == null) {
			testListingRegionId = [
				SELECT Id
				FROM Region__c
				WHERE Shift_Key__c = :REGION_SHIFT_KEY_TEST_LISTING_REGION
			].Id;
		}
		return testListingRegionId;
	}

	class Expector extends ShiftWorkflowTesting.Expector {
		Processing_Pipeline__c pipeline { get { return (Processing_Pipeline__c) state; } }
		ShiftTesting.SellerTestContext sellerTestContext; // null until start()

		Expector() {
			super(ShiftProcessingPipeline.WORKFLOW_IDENTIFIER, new Processing_Pipeline__c());
		}

		Expector start() {
			sellerTestContext.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
			sellerTestContext.signSellerContract();
			update sellerTestContext.opportunity;
			state = [
				SELECT Id
				FROM Processing_Pipeline__c
				WHERE Seller_Opportunity_ID__c = :sellerTestContext.opportunity.Id
			];
			return this;
		}

		void expectOpportunityStage(String expect) {
			Opportunity opp = [
				SELECT StageName
				FROM Opportunity
				WHERE Id = :sellerTestContext.opportunity.Id
			];
			System.assertEquals(expect, opp.StageName);
		}

		Id getInspectionId() {
			List<Inspection__c> l = [
				SELECT Id FROM Inspection__c WHERE Processing_Pipeline_ID__c = :pipeline.Id
			];
			if (l.isEmpty()) {
				return null;
			}
			System.assertEquals(1, l.size());
			return l.get(0).Id;
		}

		Id expectInspectionCreated() {
			Id res = getInspectionId();
			System.assert(res != null);
			return res;
		}

		Id expectVehicleOptionsCreated() {
			Vehicle_Options__c options = [
				SELECT Id FROM Vehicle_Options__c WHERE Processing_Pipeline_ID__c = :pipeline.Id
			];
			return options.Id;
		}

		// gets to a point where an update to t.pipeline will start detection of repair
		// management tasks
		void setRendezvousForRepairManagement() {
			pipeline.Is_Wash_Interior_Done__c = true;
			pipeline.Is_Condition_Report_Handled__c = true;
		}

		void expectRepairStatusesForWholesale() {
			for (Schema.SObjectField f : ShiftProcessingPipeline.REPAIR_STATUS_FIELD_MAP.values()) {
				Id pipelineId = pipeline.Id;
				String query = 'SELECT ' + f.getDescribe().getName() + ' FROM Processing_Pipeline__c WHERE Id = :pipelineId';
				Processing_Pipeline__c p = Database.query(query);
				System.assertEquals(ShiftProcessingPipeline.REPAIR_STATUS_UNNECESSARY, p.get(f));
			}
			System.assert([SELECT Direct_To_Wholesale__c FROM Opportunity WHERE Id = :sellerTestContext.opportunity.Id].Direct_To_Wholesale__c);
		}

		Id getSellerRegionID() {
			return [
				SELECT Region_ID__c
				FROM Opportunity
				WHERE Id = :sellerTestContext.opportunity.Id
			].Region_ID__c;
		}

		void expectWholesaleTask() {
			Task t = [
				SELECT Id
				FROM TASK
				WHERE
					Subject = :ShiftOpportunities.SUBJECT_EXECUTE_WHOLESALE AND
					Region_ID__c = :getTestListingRegionId()
			];
		}

		void expectWholesaleResult() {
			expectRepairStatusesForWholesale();
			expectWholesaleTask();
			expectOpportunityStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL);
			expectOpenTaskCount(0);
		}

		void syncPipeline() {
			state = [
				SELECT
					Mechanical_Repair_Status__c,
					Cosmetic_Repair_Status__c,
					Smog_Repair_Status__c,
					Paintless_Dent_Removal_Repair_Status__c,
					Is_Repair_Management_Done__c
				FROM Processing_Pipeline__c
				WHERE Id = :pipeline.Id
			];
		}

		void simulateInspectionCompletion() {
			Id inspectionId = getInspectionId();
			if (inspectionId != null) {
				update new Inspection__c(Id = inspectionId, Complete__c = true);
			} else {
				insert new Inspection__c(
					Processing_Pipeline_ID__c = pipeline.Id,
					Forcebase_Deal_ID__c = sellerTestContext.opportunity.Id,
					Region_ID__r = sellerTestContext.opportunity.Region_ID__r,
					Complete__c = true
				);
			}
			pipeline.Is_Cosmetic_Inspection_Done__c = true;
			pipeline.Is_Inspection_Done__c = true;
			update pipeline;
		}
	}

	static Expector createExpector() {
		Expector res = new Expector();
		res.sellerTestContext = ShiftTesting.createAndInsertSeller();
		update new Vehicle__c(
			Id = res.sellerTestContext.vehicle.Id,
			Listing_Region_ID__c = getTestListingRegionId()
		);
		return res;
	}

	// Tests execution of a successful and fully active pipeline from start to finish.
	@IsTest static void testPipelineToSellCar() {
		// TODO (Included in https://shift.phacility.com/T1687) This test uses more than the max
		// of 100 queries, but it's not clear yet whether we can slim that down by refactoring
		// this test code, and also whether some gains will come from other improvements to
		// associated triggers which may unnecessarily hit the DB. We currently just stick the
		// Test.startTest() halfway through this test to reset our count and buy us 200 queries,
		// but that's not ideal. If there really is no way around this issue, we could always
		// move this test out of salesforce and add it in Go, and test the pipeline using API
		// calls. Hopefully it won't come to that, and what we have here does work.
		Expector e = createExpector().start();
		Id inspectionId = e.expectInspectionCreated();
		Id optionsId = e.expectVehicleOptionsCreated();
		insert new Vehicle_Options_Item__c(
			Name = 'test-item',
			Description__c = 'test-description',
			Vehicle_Options__c = optionsId
		);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_TOP_FEATURES, ShiftConstants.TASK_TEAM_TOP_FEATURES);
		// We only assert region/workflow identifier once and rely on the
		// implementation's common code path to assume it is set correctly
		// everywhere else
		e.expectTask(ShiftProcessingPipeline.TASK_INSPECT_COSMETIC).
			expectTeam(ShiftConstants.TASK_TEAM_INSPECTION).
			expectRegion(getTestListingRegionId()).
			expectWorkflowIdentifier(ShiftProcessingPipeline.WORKFLOW_IDENTIFIER).
			expectNotStarted().
			updateComplete();
		e.expectTask(ShiftProcessingPipeline.TASK_INSPECT_MECHANICAL).
			expectTeam(ShiftConstants.TASK_TEAM_INSPECTION);
		update new Inspection__c(Id = inspectionId, Complete__c = true);
		System.assert([SELECT Is_Inspection_Done__c FROM Processing_Pipeline__c WHERE Id = :e.pipeline.Id].Is_Inspection_Done__c);
		ShiftTesting.TaskExpector assess = e.expectTask(ShiftProcessingPipeline.TASK_ASSESS_REPAIRS).
			expectTeam(ShiftConstants.TASK_TEAM_ESTIMATES_AND_APPROVALS).
			expectNotStarted();
		e.pipeline.Mechanical_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		e.pipeline.Cosmetic_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		e.pipeline.Smog_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		e.pipeline.Paintless_Dent_Removal_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		update e.pipeline;
		assess.updateComplete();
		Test.startTest();
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_GET_SELLER_APPROVAL, ShiftConstants.TASK_TEAM_ESTIMATES_AND_APPROVALS);
		update e.pipeline;
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_HANDLE_CONDITION_REPORT, ShiftConstants.TASK_TEAM_ESTIMATES_AND_APPROVALS);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_WRITE_LISTING, ShiftConstants.TASK_TEAM_COPYWRITING);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_MANAGE_REPAIRS_PAINTLESS_DENT_REMOVAL, ShiftConstants.TASK_TEAM_REPAIR_MANAGEMENT);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_MANAGE_REPAIRS_COSMETIC, ShiftConstants.TASK_TEAM_REPAIR_MANAGEMENT);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_MANAGE_REPAIRS_MECHANICAL, ShiftConstants.TASK_TEAM_REPAIR_MANAGEMENT);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_MANAGE_REPAIRS_SMOG, ShiftConstants.TASK_TEAM_REPAIR_MANAGEMENT);
		e.syncPipeline();
		System.assert(e.pipeline.Is_Repair_Management_Done__c);
		System.assertEquals(ShiftConstants.TASK_STATUS_COMPLETED, e.pipeline.Mechanical_Repair_Status__c);
		System.assertEquals(ShiftConstants.TASK_STATUS_COMPLETED, e.pipeline.Cosmetic_Repair_Status__c);
		System.assertEquals(ShiftConstants.TASK_STATUS_COMPLETED, e.pipeline.Smog_Repair_Status__c);
		System.assertEquals(ShiftConstants.TASK_STATUS_COMPLETED, e.pipeline.Paintless_Dent_Removal_Repair_Status__c);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_WASH_EXTERIOR, ShiftConstants.TASK_TEAM_DETAILING);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_WASH_INTERIOR, ShiftConstants.TASK_TEAM_DETAILING);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_PHOTOGRAPH_VEHICLE, ShiftConstants.TASK_TEAM_PHOTOGRAPHY);
		// just select and make sure exactly one exists
		Task editPhotos = [SELECT Id FROM TASK WHERE
			Team__c = :ShiftConstants.TASK_TEAM_MERCHANDISING AND
			Subject = :ShiftOpportunities.SUBJECT_EDIT_VEHICLE_PHOTOS AND
			WhatId = :e.sellerTestContext.opportunity.Id
		];
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_FINAL_PROCESSING_QUALITY_CONTROL_CHECK, ShiftConstants.TASK_TEAM_PROCESSING_QUALITY_CONTROL);
		e.expectOpenTaskCount(0);
		e.expectOpportunityStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL);
		// There was an error that changed all tasks to canceled when an
		// opportunity moved to Lost even if the opportunity was already out of
		// processing. This check is to confirm the fix for that (only cancel
		// when moving from prep --> lost) and as a regression test.
		e.sellerTestContext.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST;
		update e.sellerTestContext.opportunity;
		System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :e.pipeline.Id AND Status != :ShiftConstants.TASK_STATUS_COMPLETED]);
		Test.stopTest();
	}

	@IsTest static void testRepairManagementWithNotNeededRepairs() {
		Expector e = createExpector().start();
		e.setRendezvousForRepairManagement();
		e.pipeline.Smog_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		e.pipeline.Cosmetic_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		update e.pipeline;
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_MANAGE_REPAIRS_COSMETIC);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_MANAGE_REPAIRS_SMOG);
		e.expectTask(ShiftProcessingPipeline.TASK_WASH_EXTERIOR);
	}

	@IsTest static void testRepairManagementWithNoNeededRepairs() {
		Expector e = createExpector().start();
		e.setRendezvousForRepairManagement();
		update e.pipeline;
		e.expectTask(ShiftProcessingPipeline.TASK_WASH_EXTERIOR);
	}

	@IsTest static void testPipelineWithIncomingDirectToWholesale() {
		Expector e = createExpector();
		Test.startTest();
		e.sellerTestContext.opportunity.Direct_To_Wholesale__c = true;
		update e.sellerTestContext.opportunity;
		e.start();
		e.expectWholesaleResult();
		Test.stopTest();
	}

	@IsTest static void testPipelineWithRepairDeskSendingToWholesale() {
		Expector e = createExpector().start();
		Test.startTest();
		e.simulateInspectionCompletion();
		ShiftTesting.TaskExpector assess = e.expectTask(ShiftProcessingPipeline.TASK_ASSESS_REPAIRS);
		e.pipeline.Is_Direct_To_Wholesale__c = true;
		update e.pipeline;
		assess.updateComplete();
		e.expectOpenTaskCount(1);
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_GET_SELLER_APPROVAL);
		e.expectWholesaleResult();
		Test.stopTest();
	}

	@IsTest static void testPipelineWithApprovalsSendingToWholesale() {
		Expector e = createExpector().start();
		e.simulateInspectionCompletion();
		ShiftTesting.TaskExpector assess = e.expectTask(ShiftProcessingPipeline.TASK_ASSESS_REPAIRS);
		e.pipeline.Mechanical_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		e.pipeline.Cosmetic_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		e.pipeline.Smog_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		e.pipeline.Paintless_Dent_Removal_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		update e.pipeline;
		assess.updateComplete();
		Test.startTest();
		ShiftTesting.TaskExpector approve = e.expectTask(ShiftProcessingPipeline.TASK_GET_SELLER_APPROVAL);
		e.pipeline.Is_Direct_To_Wholesale__c = true;
		update e.pipeline;
		approve.updateComplete();
		e.expectWholesaleResult();
		Test.stopTest();
	}

	@IsTest static void testValidationOnSendToWholesale() {
		Expector e = createExpector().start();
		e.simulateInspectionCompletion();
		e.pipeline.Is_Direct_To_Wholesale__c = true;
		e.pipeline.Cosmetic_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		update e.pipeline;
		try {
			e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_ASSESS_REPAIRS);
			System.assert(false, 'expected error on move to wholesale');
		} catch (DmlException ex) {
			if (!ex.getMessage().contains('attempt to send to wholesale but repair status for field "Cosmetic Repair Status" (Cosmetic_Repair_Status__c) is "Awaiting Repair"')) {
				throw ex;
			}
		}
	}

	@IsTest static void testRepairStatusesCheckedOnAssessmentComplete() {
		Expector e = createExpector().start();
		e.simulateInspectionCompletion();
		e.pipeline.Mechanical_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_UNNECESSARY;
		e.pipeline.Cosmetic_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_UNNECESSARY;
		e.pipeline.Smog_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_UNNECESSARY;
		update e.pipeline;
		try {
			e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_ASSESS_REPAIRS);
			System.assert(false, 'expected error on assessment completion');
		} catch (DmlException ex) {
			if (!ex.getMessage().contains('attempt to complete repair assessment without value for "Paintless Dent Removal Repair Status"')) {
				throw ex;
			}
		}
	}

	@IsTest static void testInvalidStatusOnRepairAssessmentCompletion() {
		Expector e = createExpector().start();
		e.simulateInspectionCompletion();
		e.pipeline.Mechanical_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_UNNECESSARY;
		e.pipeline.Cosmetic_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_UNNECESSARY;
		e.pipeline.Smog_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_UNNECESSARY;
		e.pipeline.Paintless_Dent_Removal_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_IN_PROGRESS;
		update e.pipeline;
		try {
			e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_ASSESS_REPAIRS);
			System.assert(false, 'expected error on assessment completion');
		} catch (DmlException ex) {
			if (!ex.getMessage().contains('attempt to complete repair assessment but value for "Paintless Dent Removal Repair Status" is "In Progress"')) {
				throw ex;
			}
		}
	}

	@IsTest static void testErrorOnRepairStatusTypeChangeAfterRepairManagementDone() {
		Expector e = createExpector().start();
		e.pipeline.Is_Repair_Management_Done__c = true;
		update e.pipeline;
		e.pipeline.Smog_Repair_Status__c = ShiftProcessingPipeline.REPAIR_STATUS_AWAITING_REPAIR;
		try {
			update e.pipeline;
			System.assert(false, 'expected error changing repair status');
		} catch (DmlException ex) {
			if (!ex.getMessage().contains('attempt to change status field(s) for repairs after repair management is done: Smog Repair Status')) {
				throw ex;
			}
		}
	}

	@IsTest static void testErrorOnIncompleteInspection() {
		Expector e = createExpector().start();
		e.expectInspectionCreated();
		e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_INSPECT_COSMETIC);
		try {
			e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_INSPECT_MECHANICAL);
			System.assert(false, 'expected error completing inspection task');
		} catch (DmlException ex) {
			if (!ex.getMessage().contains('attempt to complete inspection task but inspection is not complete')) {
				throw ex;
			}
		}
	}

	@IsTest static void testErrorOnIncompleteTopFeatures() {
		Expector e = createExpector().start();
		try {
			e.expectAndCompleteNewTask(ShiftProcessingPipeline.TASK_TOP_FEATURES);
			System.assert(false, 'expected error completing top features');
		} catch (DmlException ex) {
			if (!ex.getMessage().contains('attempt to complete top features task but top features has fewer than')) {
				throw ex;
			}
		}
	}

	@IsTest static void testStageChangeLostCancelsPipeline() {
		Expector e = createExpector().start();
		Test.startTest();
		e.sellerTestContext.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST;
		update e.sellerTestContext.opportunity;
		e.expectOpenTaskCount(0);
		Test.stopTest();
	}

	@IsTest static void testReentryToPrepareFromLost() {
		Expector e = createExpector().start();
		e.expectTask(ShiftProcessingPipeline.TASK_INSPECT_COSMETIC).updateComplete();
		Test.startTest();
		e.sellerTestContext.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST;
		update e.sellerTestContext.opportunity;
		e.sellerTestContext.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		update e.sellerTestContext.opportunity;
		e.expectTask(ShiftProcessingPipeline.TASK_INSPECT_COSMETIC).expectStatus(ShiftConstants.TASK_STATUS_COMPLETED);
		e.expectTask(ShiftProcessingPipeline.TASK_TOP_FEATURES).expectNotStarted();
		e.expectTask(ShiftProcessingPipeline.TASK_INSPECT_MECHANICAL).expectNotStarted();
		Test.stopTest();
	}

	@IsTest static void testReentryToPrepareFromEval() {
		Expector e = createExpector().start();
		Test.startTest();
		e.expectTask(ShiftProcessingPipeline.TASK_INSPECT_COSMETIC).updateComplete();
		e.sellerTestContext.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		update e.sellerTestContext.opportunity;
		e.sellerTestContext.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		e.sellerTestContext.signSellerContract();
		update e.sellerTestContext.opportunity;
		e.expectTask(ShiftProcessingPipeline.TASK_INSPECT_COSMETIC).expectStatus(ShiftConstants.TASK_STATUS_COMPLETED);
		e.expectTask(ShiftProcessingPipeline.TASK_TOP_FEATURES).expectNotStarted();
		e.expectTask(ShiftProcessingPipeline.TASK_INSPECT_MECHANICAL).expectNotStarted();
		Test.stopTest();
	}

	@IsTest static void testCompletionStageChangeIgnoredIfNotPrepare() {
		Expector e = createExpector().start();
		Test.startTest();
		Id oppId = e.sellerTestContext.opportunity.Id;
		String stageExpect = 'test-stage';
		update new Opportunity(Id = oppId, StageName = stageExpect);
		e.pipeline.Is_Quality_Control_Check_Done__c = true;
		update e.pipeline;

		String stage = [SELECT StageName FROM Opportunity WHERE Id = :oppId].StageName;
		System.assertEquals(stageExpect, stage);
		Test.stopTest();
	}

	@IsTest static void testPropsTrackerNotesVersioning() {
		Expector expector = createExpector().start();
		Test.startTest();

		Processing_Pipeline__c pipeline = refreshPipelineTrackerNotes(expector.pipeline.Id);

		// test normal save
		pipeline.Props_Tracker_Notes__c = 'A';
		Integer startingVersion = pipeline.Props_Tracker_Notes_Version__c.intValue();
		update pipeline;
		pipeline = refreshPipelineTrackerNotes(pipeline.Id);
		System.assertEquals(startingVersion + 1, pipeline.Props_Tracker_Notes_Version__c.intValue());

		// test changed notes with wrong version number
		pipeline = refreshPipelineTrackerNotes(pipeline.Id);
		startingVersion = pipeline.Props_Tracker_Notes_Version__c.intValue();
		pipeline.Props_Tracker_Notes__c = 'B';
		pipeline.Props_Tracker_Notes_Version__c = startingVersion - 1;
		ShiftTesting.expectUpdateExceptionContains(pipeline, ShiftProcessingPipeline.ERROR_NOTES_VERSION_STALE);

		// test unchanged notes with wrong version number
		pipeline = refreshPipelineTrackerNotes(pipeline.Id);
		startingVersion = pipeline.Props_Tracker_Notes_Version__c.intValue();
		pipeline.Props_Tracker_Notes_Version__c = startingVersion - 1;
		update pipeline;
		pipeline = refreshPipelineTrackerNotes(pipeline.Id);
		System.assertEquals(startingVersion, pipeline.Props_Tracker_Notes_Version__c.intValue());
	}

	static Processing_Pipeline__c refreshPipelineTrackerNotes(Id pipelineID) {
		return [
				SELECT Id, Props_Tracker_Notes_Version__c, Props_Tracker_Notes__c
				FROM Processing_Pipeline__c
				WHERE Id = :pipelineID
		];
	}
}