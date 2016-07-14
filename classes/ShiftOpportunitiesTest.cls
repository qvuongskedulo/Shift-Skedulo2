@IsTest
private with sharing class ShiftOpportunitiesTest {
	private static final String TEST_STAGE_NAME = 'Test Stage';

	private static void expectTaskCounts(Id opportunityId, Map<String, Integer> expected) {
		System.assertEquals(expected, getTaskSubjectCounts(opportunityId));
	}

	private static void expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(String stageName, Map<String, Integer> expected, ShiftTesting.SellerTestContext ctx) {
		ctx.opportunity.StageName = stageName;
		if (stageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER) {
			ShiftTesting.prepareVehicleForHandover(ctx.vehicle);
		}
		insert ctx.opportunity;
		expectTaskCounts(ctx.opportunity.Id, expected);

		update ctx.opportunity;
		expectTaskCounts(ctx.opportunity.Id, expected);
	}

	private static void expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(String stageName, Map<String, Integer> expected) {
		expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(stageName, expected, ShiftTesting.prepareSellerTestContext());
	}

	private static void expectTaskCountsOnSellerUpdateToStage(String fromStageName, Map<String, Integer> initialExpected, String toStageName, Map<String, Integer> finalExpected, ShiftTesting.SellerTestContext ctx) {
		ctx.opportunity.StageName = fromStageName;
		insert ctx.opportunity;
		expectTaskCounts(ctx.opportunity.Id, initialExpected);

		if (toStageName == ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER) {
			// This automatically changes the vehicle's seller opportunity's stage to Handover.
			ShiftTesting.prepareVehicleForHandover(ctx.vehicle);
		} else {
			ctx.opportunity.StageName = toStageName;
			ctx.signSellerContract();
			update ctx.opportunity;
		}
		expectTaskCounts(ctx.opportunity.Id, finalExpected);
	}

	private static void expectTaskCountsOnSellerUpdateToStage(String fromStageName, Map<String, Integer> initialExpected, String toStageName, Map<String, Integer> finalExpected) {
		expectTaskCountsOnSellerUpdateToStage(fromStageName, initialExpected, toStageName, finalExpected, ShiftTesting.prepareSellerTestContext());
	}

	@testSetup static void setup() { ShiftTesting.setup(); }

	private static Map<String, Integer> getTaskSubjectCounts(Id opportunityId) {
		List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :opportunityId];
		Map<String, Integer> subjectToCount = new Map<String, Integer>();
		for (Task task : tasks) {
			Integer count = subjectToCount.get(task.Subject);
			if (count == null) {
				count = 0;
			}
			subjectToCount.put(task.Subject, count + 1);
		}
		return subjectToCount;
	}

	@IsTest static void testBuyerOppNoTaskCreation() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.opportunity.StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS;
		insert ctx.opportunity;
		System.assertEquals(0, [SELECT COUNT() FROM Task Where WhatId = :ctx.opportunity.Id]);

		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		update ctx.opportunity;
		System.assertEquals(0, [SELECT COUNT() FROM Task Where WhatId = :ctx.opportunity.Id]);
	}

	@IsTest static void testLeadSourceCraigsListCreationTasks() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE;
		insert ctx.opportunity;
		expectTaskCounts(ctx.opportunity.Id, new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_SEND_REMOTE_QUOTE => 1
		});

		ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE;
		ctx.opportunity.LeadSource = ShiftConstants.LEAD_SOURCE_CRAIGSLIST;
		insert ctx.opportunity;
		expectTaskCounts(ctx.opportunity.Id, new Map<String, Integer>());
	}

	@IsTest static void testLeadSourceSellerAppCreationTasks() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE;
		ctx.opportunity.LeadSource = ShiftConstants.LEAD_SOURCE_SELLER_APP;
		insert ctx.opportunity;
		expectTaskCounts(ctx.opportunity.Id, new Map<String, Integer>());
	}

	@IsTest static void testQuoteSentAtCreationTasks() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE;
		ctx.opportunity.Quote_Sent_At__c = Date.today();
		insert ctx.opportunity;
		expectTaskCounts(ctx.opportunity.Id, new Map<String, Integer>());
	}

	@IsTest static void testEvaluatePickupTasks() {
		Map<String, Integer> expectedTasks = new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_SECONDARY_PRICING_RESEARCH => 1,
			ShiftOpportunities.SUBJECT_UPLOAD_CARFAX_AUTOCHECK_REPORTS => 1
		};

		expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE, expectedTasks);
		// query limits
		Test.startTest();
		expectTaskCountsOnSellerUpdateToStage(TEST_STAGE_NAME, new Map<String, Integer>(), ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE, expectedTasks);
		Test.stopTest();
	}

	@IsTest static void testPrepareCarSaleTasks() {
		Map<String, Integer> expectedTasks = new Map<String, Integer>{
			ShiftConstants.TASK_SUBJECT_INPUT_CONTRACT_EXPIRATION_DATE => 1,
			ShiftOpportunities.SUBJECT_OBTAIN_RECALL_WARRANTY_SERVICE_INFORMATION => 1,
			ShiftOpportunities.SUBJECT_SEND_APPRAISAL_SURVEY => 1,
			ShiftOpportunities.SUBJECT_SEND_SELLER_PROFILE_QUESTIONNAIRE => 1,
			ShiftOpportunities.SUBJECT_ADD_DEAL_PROPS_TRACKER_CONDITION_SHEET => 1,
			ShiftOpportunities.SUBJECT_CHECK_SELLER_PAPERWORK => 1,
			ShiftOpportunities.SUBJECT_VERIFY_SIRIUS_COMPATIBILITY => 1
		};

		expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE, expectedTasks);
		Test.startTest();
		expectTaskCountsOnSellerUpdateToStage(TEST_STAGE_NAME, new Map<String, Integer>(), ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE, expectedTasks);
		Test.stopTest();
	}

	@IsTest static void testSellCarTasks() {
		Map<String, Integer> expectedTasks = new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_PURCHASE_CARFAX_CIP => 1,
			ShiftOpportunities.SUBJECT_CHECK_COMING_SOON_BUYERS => 1,
			ShiftOpportunities.SUBJECT_UPDATE_SELLER => ShiftOpportunities.SELLER_NOTIFICATIONS_TO_CREATE
		};

		expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL, expectedTasks);
		// query limits
		Test.startTest();
		expectTaskCountsOnSellerUpdateToStage(TEST_STAGE_NAME, new Map<String, Integer>(), ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL, expectedTasks);
		Test.stopTest();
	}

	@IsTest static void testRemoveSellerNotificationsOnMoveFromSell() {
		Test.startTest();
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();

		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		insert ctx.opportunity;
		Test.stopTest();

		ShiftWorkflowTesting.Expector expector = new ShiftWorkflowTesting.Expector(ShiftOpportunities.WORKFLOW_IDENTIFIER_SELLER_NOTIFICATIONS, ctx.opportunity);
		List<ShiftTesting.TaskExpector> taskExpectors = expector.getAllTasks();
		for (ShiftTesting.TaskExpector taskExpector : taskExpectors) {
			taskExpector.expectStatus(ShiftConstants.TASK_STATUS_NOT_STARTED);
			taskExpector.expectSubject(ShiftOpportunities.SUBJECT_UPDATE_SELLER);
		}

		taskExpectors.get(0).updateStatus(ShiftConstants.TASK_STATUS_COMPLETED);

		// this automatically moves op to hand_over.
		ShiftTesting.prepareVehicleForHandover(ctx.vehicle);

		Map<String, Integer> expectedTaskStatusesToCount = new Map<String, Integer> {
			ShiftConstants.TASK_STATUS_CANCELED => ShiftOpportunities.SELLER_NOTIFICATIONS_TO_CREATE - 1,
			ShiftConstants.TASK_STATUS_COMPLETED => 1
		};
		expector.expectTaskStatusCounts(expector.getAllTasks(), expectedTaskStatusesToCount);
	}

	@IsTest static void testSellCarToWholesaleTasks() {
		Map<String, Integer> expectedTasks = new Map<String, Integer> {
			ShiftOpportunities.SUBJECT_CHECK_COMING_SOON_BUYERS => 1,
			ShiftOpportunities.SUBJECT_UPDATE_SELLER => ShiftOpportunities.SELLER_NOTIFICATIONS_TO_CREATE
		};

		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.Direct_To_Wholesale__c = true;
		expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL, expectedTasks, ctx);

		// query limits
		Test.startTest();
		ShiftTesting.SellerTestContext ctx2 = ShiftTesting.prepareSellerTestContext();
		ctx2.opportunity.Direct_To_Wholesale__c = true;
		expectTaskCountsOnSellerUpdateToStage(TEST_STAGE_NAME, new Map<String, Integer>(), ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL, expectedTasks, ctx2);
		Test.stopTest();
	}

	@IsTest static void testCreateTradeInPricingTasksInsert() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.Trade_In__c = true;
		insert ctx.opportunity;

		String opName = [SELECT Name FROM Opportunity WHERE Id = :ctx.opportunity.Id].Name;

		Map<String, Integer> expectedTasks = new Map<String, Integer> {
				ShiftOpportunities.SUBJECT_TRADE_IN_PRICING_PREFIX + opName => 1
		};

		expectTaskCounts(ctx.opportunity.Id, expectedTasks);
	}

	@IsTest static void testCreateTradeInPricingTasksUpdate() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		insert ctx.opportunity;
		ctx.opportunity.Trade_In__c = true;
		update ctx.opportunity;

		String opName = [SELECT Name FROM Opportunity WHERE Id = :ctx.opportunity.Id].Name;

		Map<String, Integer> expectedTasks = new Map<String, Integer> {
				ShiftOpportunities.SUBJECT_TRADE_IN_PRICING_PREFIX + opName => 1
		};

		expectTaskCounts(ctx.opportunity.Id, expectedTasks);
	}

	static Map<String, Integer> getExpectedHandoverTasks () {
		Map<String, Integer> expectedTasks = new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_DELETE_CAR_SHIFT_APPLICATION_PULL_DOWN_LISTINGS => 1,
			ShiftOpportunities.SUBJECT_SEND_SELLER_RECEIPT => 1,
			ShiftOpportunities.SUBJECT_SEND_MONEY_SELLER => 1,
			ShiftOpportunities.SUBJECT_COMPLETE_DMV_PAPERWORK => 1,
			ShiftOpportunities.SUBJECT_CANCEL_SCHEDULED_TEST_DRIVES => 1,
			ShiftOpportunities.SUBJECT_CAR_HAS_BEEN_SOLD => 1,
			ShiftOpportunities.SUBJECT_RECYCLE_LISTING_TEXT => 1,
			ShiftOpportunities.SUBJECT_NOTIFY_SELLER_DROP_INSURANCE => 1,
			ShiftOpportunities.SUBJECT_FILE_RELEASE_LIABILITY => 1,
			ShiftOpportunities.SUBJECT_CHECK_PROD_LIST_FINAL_BUYER_CLOSE_OUT_MARK_DND => 1,
			ShiftOpportunities.SUBJECT_DELETE_AND_RECYCLE_CRAIGSLIST_NUMBER => 1
		};

		return expectedTasks;
	}

	// testHandoverTasks and testHandoverTasksAfterUpdateToStage were split
	// because together they exceeded 100 SOQL statements in a transaction.
	@IsTest static void testHandoverTasks() {
		Map<String, Integer> expectedTasks = getExpectedHandoverTasks();
		Test.startTest();
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Test.stopTest();
		expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER, expectedTasks, ctx);
	}

	@IsTest static void testHandoverTasksAfterUpdateToStage() {
		Map<String, Integer> expectedTasks = getExpectedHandoverTasks();
		Test.startTest();
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Test.stopTest();
		expectTaskCountsOnSellerUpdateToStage(TEST_STAGE_NAME, new Map<String, Integer>(), ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER, expectedTasks, ctx);
	}

	@IsTest static void testSoldTasks() {
		Map<String, Integer> expectedTasks = new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_SEND_SELLER_BUYER_SURVEYS => 1
		};

		expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD, expectedTasks);
		// query limits
		Test.startTest();
		expectTaskCountsOnSellerUpdateToStage(TEST_STAGE_NAME, new Map<String, Integer>(), ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD, expectedTasks);
		Test.stopTest();
	}

	@IsTest static void testLostTasks() {
		Map<String, Integer> expectedLostInsertTasks = new Map<String, Integer>();
		Map<String, Integer> expectedSellInsertTasks = new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_PURCHASE_CARFAX_CIP => 1,
			ShiftOpportunities.SUBJECT_CHECK_COMING_SOON_BUYERS => 1,
			ShiftOpportunities.SUBJECT_UPDATE_SELLER => ShiftOpportunities.SELLER_NOTIFICATIONS_TO_CREATE
		};
		Map<String, Integer> expectedSellToLostUpdateTasks = new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_PURCHASE_CARFAX_CIP => 1,
			ShiftOpportunities.SUBJECT_CHECK_COMING_SOON_BUYERS => 1,
			ShiftOpportunities.SUBJECT_UPDATE_SELLER => ShiftOpportunities.SELLER_NOTIFICATIONS_TO_CREATE,
			ShiftOpportunities.SUBJECT_DELETE_CAR_SHIFT_APPLICATION_PULL_DOWN_LISTINGS => 1
		};

		expectTaskCountsOnSellerInsertAndSameStageUpdateWithStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST, expectedLostInsertTasks);
		// query limits
		Test.startTest();
		expectTaskCountsOnSellerUpdateToStage(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL, expectedSellInsertTasks, ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST, expectedSellToLostUpdateTasks);
		Test.stopTest();
	}

	@IsTest
	static void testUpdateISR() {
		List<ShiftTesting.SellerTestContext> ctxs = new List<ShiftTesting.SellerTestContext>{
				ShiftTesting.prepareSellerTestContext(),
				ShiftTesting.prepareSellerTestContext(),
				ShiftTesting.prepareSellerTestContext()
		};
		List<Opportunity> opportunities = new List<Opportunity>{
				ctxs[0].opportunity,
				ctxs[1].opportunity,
				ctxs[2].opportunity
		};
		User userA = ShiftTesting.createTestUser();
		User userB = ShiftTesting.createISRInboundUser();
		User userC = ShiftTesting.createISROutboundUser();

		insert new List<User> {userA, userB, userC};

		opportunities[0].OwnerId = userA.Id;
		opportunities[1].OwnerId = userB.Id;
		opportunities[2].OwnerId = userC.Id;

		ShiftOpportunities.updateInsideSalesRep(null, opportunities);

		System.assertEquals(opportunities[0].Inside_Sales_Representative__c, null);
		System.assertEquals(opportunities[1].Inside_Sales_Representative__c, userB.Id);
		System.assertEquals(opportunities[2].Inside_Sales_Representative__c, userC.Id);
	}

	@IsTest static void testLostFromEvaluateTasks() {
		Map<String, Integer> expectedTasksWithEvals = new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_SECONDARY_PRICING_RESEARCH => 1,
			ShiftOpportunities.SUBJECT_UPLOAD_CARFAX_AUTOCHECK_REPORTS => 1,
			ShiftOpportunities.SUBJECT_SEND_APPRAISAL_SURVEY => 1
		};

		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ShiftTesting.SellerTestContext ctxCanceledEval = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		insert ctx.opportunity;

		Evaluation__c eval = new Evaluation__c(
			Evaluated_At__c = Date.today(),
			Canceled__c = false,
			Seller_Opportunity_ID__c = ctx.opportunity.Id
		);
		Evaluation__c eval2 = new Evaluation__c(
			Evaluated_At__c = Date.today(),
			Canceled__c = false,
			Seller_Opportunity_ID__c = ctx.opportunity.Id
		);
		insert new List<Evaluation__c> {eval, eval2};

		Test.startTest();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST;
		update ctx.opportunity;

		expectTaskCounts(ctx.opportunity.Id, expectedTasksWithEvals);
		Test.stopTest();
	}

	@IsTest static void testLostFromEvaluateTasksCancelledEval() {
		Map<String, Integer> expectedTasksWithCancelledEvals = new Map<String, Integer>{
			ShiftOpportunities.SUBJECT_SECONDARY_PRICING_RESEARCH => 1,
			ShiftOpportunities.SUBJECT_UPLOAD_CARFAX_AUTOCHECK_REPORTS => 1
		};

		ShiftTesting.SellerTestContext ctxCanceledEval = ShiftTesting.prepareSellerTestContext();
		ctxCanceledEval.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		insert ctxCanceledEval.opportunity;

		Evaluation__c cancelledEval = new Evaluation__c(
			Evaluated_At__c = Date.today(),
			Canceled__c = true,
			Seller_Opportunity_ID__c = ctxCanceledEval.opportunity.Id
		);
		insert cancelledEval;

		Test.startTest();
		ctxCanceledEval.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST;
		update ctxCanceledEval.opportunity;

		expectTaskCounts(ctxCanceledEval.opportunity.Id, expectedTasksWithCancelledEvals);
		Test.stopTest();
	}

	@IsTest static void testUber() {
		Referrer_Analytics__c ra = new Referrer_Analytics__c(
						UTM_Campaign__c = ShiftConstants.UTM_CODE_UBER_DEC_LA
		);
		insert ra;

		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.Referrer_Analytics_ID__c = ra.Id;
		insert ctx.opportunity;

		Opportunity seller = [SELECT Referral_Program_Or_Promotion__c FROM Opportunity WHERE Id = :ctx.opportunity.Id];
		System.assertEquals('UberLA2015', seller.Referral_Program_Or_Promotion__c);
	}

	@IsTest static void testValidatePublicId() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.Public_ID__c = 'originalID';
		insert ctx.opportunity;
		ctx.opportunity.Public_ID__c = 'changedID';
		ShiftTesting.expectUpdateExceptionContains(ctx.opportunity, String.escapeSingleQuotes('Attempt to change Public_ID__c from originalID to changedID'));
	}
}