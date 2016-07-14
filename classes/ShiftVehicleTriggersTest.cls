@IsTest
class ShiftVehicleTriggersTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	static void insertTestVehicle(String name, String trim) {
		insert new Vehicle__c(
			Name = name,
			Year__c = 2005.0,
			Make__c = 'Subaru',
			Model__c = 'Impreza',
			Trim__c = trim,
			Body_Style__c = 'Sedan',
			Mileage__c = 52000,
			List_Price__c = 20,
			Listing_Region_ID__c = ShiftTesting.getTestRegionId()
		);
	}

	static Vehicle__c createVehicle(String paperWorkMissing, String listingTitle) {
		Vehicle__c vehicle = ShiftTesting.createVehicle();
		vehicle.Paperwork_Missing__c = paperWorkMissing;
		vehicle.Listing_Title__c = listingTitle;
		insert vehicle;
		return vehicle;
	}

	static Opportunity createSellerOpportunity(ShiftTesting.SellerTestContext ctx, Boolean directToWholesale, String stageName) {
		Opportunity opportunity = ShiftTesting.createSellerOpportunity();
		opportunity.Vehicle_ID__c = ctx.vehicle.Id;
		opportunity.AccountId = ctx.account.Id;
		opportunity.Direct_To_Wholesale__c = directToWholesale;
		opportunity.StageName = stageName;
		insert opportunity;
		return opportunity;
	}

	static List<Task> getNonCanceledTasksOnOpportunityForSubject(Id opportunityId, String subject) {
		return [
			SELECT Id, Subject, Team__c
			FROM Task
			WHERE
				WhatId = :opportunityId AND
				Status != :ShiftConstants.TASK_STATUS_CANCELED AND
				Subject = :subject
		];
	}

	static void completeTasksForOpportunityAndSubject(Id opportunityId, String subject) {
		List<Task> tasks = getNonCanceledTasksOnOpportunityForSubject(opportunityId, subject);
		ShiftTasks.updateStatus(tasks, ShiftConstants.TASK_STATUS_COMPLETED);
	}

	static void assertSingleTaskWithSubjectExistsOnOpportunity(Id opportunityId, String subject) {
		List<Task> tasks = getNonCanceledTasksOnOpportunityForSubject(opportunityId, subject);

		System.assertEquals(1, tasks.size());
		Task task = tasks.get(0);
		ShiftTesting.TaskExpector taskExpector = new ShiftTesting.TaskExpector(task);
		taskExpector.expectSubject(subject);
		taskExpector.expectTeam(ShiftConstants.TASK_TEAM_MERCHANDISING);
	}

	static void assertNoTasksWithSubjectExistOnOpportunity(Id opportunityId, String subject) {
		List<Task> tasks = getNonCanceledTasksOnOpportunityForSubject(opportunityId, subject);
		System.assertEquals(0, tasks.size());
	}

	class SellerContextSetup {
		public String paperWorkMissing;
		public String listingTitle;
		public Boolean directToWholesale;
		public String stageName;
	}

	static ShiftTesting.SellerTestContext setupSellerTestContext(SellerContextSetup setup) {
		ShiftTesting.SellerTestContext ctx = new ShiftTesting.SellerTestContext();
		ctx.prepare();
		ctx.vehicle = createVehicle(setup.paperWorkMissing, setup.listingTitle);
		ctx.opportunity = createSellerOpportunity(ctx, setup.directToWholesale, setup.stageName);
		return ctx;
	}

	static ShiftTesting.SellerTestContext setupSellerTestContextWithEbayListing() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ctx.vehicle.Ebay_Listing_URL__c = 'http://test.com/shift-vehicle-triggers-test';
		update ctx.vehicle;
		return ctx;
	}

	@IsTest
	static void testInsertCorrect() {
		insertTestVehicle('2005 Subaru Impreza WRX', 'WRX');
		Vehicle__c v = [SELECT Name FROM Vehicle__c LIMIT 1];
		System.assertEquals('2005 Subaru Impreza WRX', v.Name);
	}

	@IsTest
	static void testInsertNeedsCorrection() {
		insertTestVehicle('this is the wrong name', 'WRX');
		Vehicle__c v = [SELECT Name FROM Vehicle__c LIMIT 1];
		System.assertEquals('2005 Subaru Impreza WRX', v.Name);
	}

	@IsTest
	static void testNoTrim() {
		insertTestVehicle('doesn\'t matter', '');
		Vehicle__c v = [SELECT Name FROM Vehicle__c LIMIT 1];
		System.assertEquals('2005 Subaru Impreza', v.Name);
	}

	@IsTest
	static void testInsertVehicleCanBeListedStagePrepare() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ctx.newVehicleTester().
			sync().
			expectCanBeListed(true);
	}

	@IsTest
	static void testInsertVehicleCanBeListedSellerStage() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ctx.newVehicleTester().
			sync().
			expectCanBeListed(true);
	}

	@IsTest
	static void testPaperwork() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ctx.newVehicleTester().
			sync().
			expectCanBeListed(true).
			updatePaperworkMissing(ShiftConstants.PAPERWORK_MISSING_YES_LESS_THAN_7_DAYS_UNAVAILABLE).
			sync().
			expectCanBeListed(true).
			updatePaperworkMissing(ShiftConstants.PAPERWORK_MISSING_YES_AVAILABLE_WITHOUT_FINANCING).
			sync().
			expectCanBeListed(true).
			updatePaperworkMissing(ShiftConstants.PAPERWORK_MISSING_YES_MORE_THAN_7_DAYS_UNAVAILABLE).
			sync().
			expectCanBeListed(false);
	}

	@IsTest
	static void testPaperworkFeeIfLateNoContract() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ctx.insertOpportunity();
		ctx.newVehicleTester().sync();

		System.assertEquals(0, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);

		ctx.vehicle.Paperwork_Missing__c = ShiftConstants.PAPERWORK_MISSING_YES_MORE_THAN_7_DAYS_UNAVAILABLE;
		ctx.vehicle.Paperwork_Missing_Reason__c = ShiftConstants.PAPERWORK_MISSING_REASON_PAYOFF_SELLER_UNDERWATER;
		update ctx.vehicle;

		System.assertEquals(ShiftConstants.PAPERWORK_MISSING_FEE, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);

		ctx.vehicle.Paperwork_Missing__c = ShiftConstants.PAPERWORK_MISSING_NO;
		update ctx.vehicle;

		System.assertEquals(0, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);
	}

	@IsTest
	static void testPaperworkFeeIfLateBefore30Days() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		Shift_Contract__c contract = new Shift_Contract__c(Opportunity_ID__c = ctx.opportunity.Id, Signed_On__c = Date.today());
		insert contract;
		ctx.opportunity.Seller_Contract_ID__c = contract.Id;
		ctx.insertOpportunity();
		ctx.newVehicleTester().sync();

		System.assertEquals(0, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);

		ctx.vehicle.Paperwork_Missing__c = ShiftConstants.PAPERWORK_MISSING_YES_MORE_THAN_7_DAYS_UNAVAILABLE;
		ctx.vehicle.Paperwork_Missing_Reason__c = ShiftConstants.PAPERWORK_MISSING_REASON_PAYOFF_SELLER_UNDERWATER;
		update ctx.vehicle;

		System.assertEquals(ShiftConstants.PAPERWORK_MISSING_FEE, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);

		ctx.vehicle.Paperwork_Missing__c = ShiftConstants.PAPERWORK_MISSING_NO;
		update ctx.vehicle;

		System.assertEquals(0, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);
	}

	@IsTest
	static void testPaperworkFeeIfLateAfter30Days() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		Shift_Contract__c contract = new Shift_Contract__c(Opportunity_ID__c = ctx.opportunity.Id, Signed_On__c = Date.today().addDays(-31));
		insert contract;
		ctx.opportunity.Seller_Contract_ID__c = contract.Id;
		ctx.insertOpportunity();
		ctx.newVehicleTester().sync();

		System.assertEquals(0, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);

		ctx.vehicle.Paperwork_Missing__c = ShiftConstants.PAPERWORK_MISSING_YES_MORE_THAN_7_DAYS_UNAVAILABLE;
		ctx.vehicle.Paperwork_Missing_Reason__c = ShiftConstants.PAPERWORK_MISSING_REASON_PAYOFF_SELLER_UNDERWATER;
		update ctx.vehicle;

		System.assertEquals(ShiftConstants.PAPERWORK_MISSING_FEE, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);

		ctx.vehicle.Paperwork_Missing__c = ShiftConstants.PAPERWORK_MISSING_NO;
		update ctx.vehicle;

		System.assertEquals(ShiftConstants.PAPERWORK_MISSING_FEE, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);
	}
	
	@IsTest
	static void testPersistedLatePaperworkFeeOnIrrelevantChange() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ctx.insertOpportunity();
		ctx.newVehicleTester().sync();

		System.assertEquals(0, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);

		ctx.vehicle.Accident_Notes__c = 'Was used in a game of Mario Kart.';
		update ctx.vehicle;

		System.assertEquals(0, [SELECT Paperwork_Fee_Pending__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Paperwork_Fee_Pending__c);
	}

	@IsTest
	static void testListingTitle() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = '';
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ctx.newVehicleTester().
			sync().
			expectCanBeListed(false).
			updateListingTitle('booyah!').
			sync().
			expectCanBeListed(true).
			updateListingTitle(null).
			sync().
			expectCanBeListed(false);
	}

	@IsTest
	static void testOpportunityWholesale() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = true;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		Test.startTest();
		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ShiftTesting.VehicleTester vehicleTester = ctx.newVehicleTester();
		vehicleTester.sync().expectCanBeListed(false);

		ctx.opportunity.Direct_To_Wholesale__c = false;
		update ctx.opportunity;
		vehicleTester.sync().expectCanBeListed(true);

		ctx.opportunity.Direct_To_Wholesale__c = true;
		update ctx.opportunity;
		vehicleTester.sync().expectCanBeListed(false);
		Test.stopTest();
	}

	@IsTest
	static void testOpportunityStageName() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ShiftTesting.VehicleTester vehicleTester = ctx.newVehicleTester();
		vehicleTester.sync().expectCanBeListed(false);

		Test.startTest();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		ctx.signSellerContract();
		update ctx.opportunity;
		vehicleTester.sync().expectCanBeListed(true);

		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_LOST;
		update ctx.opportunity;
		vehicleTester.sync().expectCanBeListed(false);
		Test.stopTest();
	}

	@IsTest
	static void testUnrelatedFieldChanges() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ctx.newVehicleTester().
			expectCanBeListed(false).
			sync().
			updateYear(2009).
			sync().
			expectCanBeListed(false);
	}

	@IsTest
	static void testInsertUpdateListingsWithProfessionalPhotosTaskOnPhotosReadyTrue() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		ShiftTesting.VehicleTester vehicleTester = ctx.newVehicleTester();

		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);
		assertNoTasksWithSubjectExistOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_UPDATE_LISTINGS_WITH_PROFESSIONAL_PHOTOS);

		vehicleTester.updatePhotosReady(true);
		assertNoTasksWithSubjectExistOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_UPDATE_LISTINGS_WITH_PROFESSIONAL_PHOTOS);

		vehicleTester.updatePhotosReady(false);
		completeTasksForOpportunityAndSubject(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);
		vehicleTester.updatePhotosReady(true);
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_UPDATE_LISTINGS_WITH_PROFESSIONAL_PHOTOS);

		List<Id> opportunityIds = new List<Id> ();
		opportunityIds.add(ctx.Opportunity.Id);
		ShiftOpportunities.cancelTasksForSubject(opportunityIds, ShiftVehicles.SUBJECT_UPDATE_LISTINGS_WITH_PROFESSIONAL_PHOTOS);
		assertNoTasksWithSubjectExistOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_UPDATE_LISTINGS_WITH_PROFESSIONAL_PHOTOS);

		vehicleTester.updatePhotosReady(false);
		vehicleTester.updatePhotosReady(true);
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_UPDATE_LISTINGS_WITH_PROFESSIONAL_PHOTOS);
	}

	@IsTest
	static void testInsertPostListingsAddLinksTaskOnCanBeListedTrue() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);
	}

	@IsTest
	static void testNoDoubleInsertOfPostListingsAndLinksTaskOnCanBeListedTrue() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);

		Test.startTest();
		ctx.opportunity.Direct_To_Wholesale__c = true;
		update ctx.opportunity;
		ctx.opportunity.Direct_To_Wholesale__c = false;
		update ctx.opportunity;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);
		Test.stopTest();
	}

	@IsTest
	static void testNoInsertOfPostListingsAndLinksTaskOnCanBeListedFalse() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = true;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		assertNoTasksWithSubjectExistOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);
		ctx.opportunity.Direct_To_Wholesale__c = false;
		update ctx.opportunity;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);
	}

	@IsTest
	static void testInsertOfPostListingsAndLinksTaskWhenPreviousTaskWasCanceled() {
		SellerContextSetup setup = new SellerContextSetup();
		setup.paperWorkMissing = ShiftConstants.PAPERWORK_MISSING_NO;
		setup.listingTitle = ShiftUtil.randomStringLowercaseAlphanum(20);
		setup.directToWholesale = false;
		setup.stageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;

		ShiftTesting.SellerTestContext ctx = setupSellerTestContext(setup);
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);

		Test.startTest();
		List<Id> opportunityIds = new List<Id> ();
		opportunityIds.add(ctx.Opportunity.Id);
		ShiftOpportunities.cancelTasksForSubject(opportunityIds, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);
		assertNoTasksWithSubjectExistOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);

		// this forces the vehicle trigger to fire with Can Be Listed false then true.
		ctx.opportunity.Direct_To_Wholesale__c = true;
		update ctx.opportunity;
		ctx.opportunity.Direct_To_Wholesale__c = false;
		update ctx.opportunity;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_POST_LISTINGS_ADD_LINKS);
		Test.stopTest();
	}

	@IsTest
	static void testRemoveEbayTaskCreatedOnDeposit() {
		ShiftTesting.SellerTestContext ctx = setupSellerTestContextWithEbayListing();

		ctx.vehicle.On_Deposit__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
	}

	@IsTest
	static void testRemoveEbayTaskCreatedGoingToAuction() {
		ShiftTesting.SellerTestContext ctx = setupSellerTestContextWithEbayListing();

		ctx.vehicle.Going_To_Auction__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
	}

	@IsTest
	static void testRemoveEbayTaskCreatedHoldForFinancing() {
		ShiftTesting.SellerTestContext ctx = setupSellerTestContextWithEbayListing();

		ctx.vehicle.Hold_For_Financing__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
	}

	@IsTest
	static void testRemoveEbayTaskCreatedHoldForTradeIn() {
		ShiftTesting.SellerTestContext ctx = setupSellerTestContextWithEbayListing();

		ctx.vehicle.Hold_For_Trade_In__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
	}

	@IsTest
	static void testRemoveEbayTaskCreatedMultiple() {
		ShiftTesting.SellerTestContext ctx = setupSellerTestContextWithEbayListing();

		ctx.vehicle.On_Deposit__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
		ctx.vehicle.Going_To_Auction__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
		ctx.vehicle.Hold_For_Financing__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
		ctx.vehicle.Hold_For_Trade_In__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
	}

	@IsTest
	static void testRemoveEbayTaskCreatedSetandUnset() {
		ShiftTesting.SellerTestContext ctx = setupSellerTestContextWithEbayListing();

		ctx.vehicle.On_Deposit__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);

		ctx.vehicle.On_Deposit__c = false;
		update ctx.vehicle;
		ctx.vehicle.On_Deposit__c = true;
		update ctx.vehicle;
		assertSingleTaskWithSubjectExistsOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
	}

	@IsTest
	static void testNoInsertOfRemoveEbayTaskNoEbayURL() {
		ShiftTesting.SellerTestContext ctx = setupSellerTestContextWithEbayListing();
		ctx.vehicle.Ebay_Listing_URL__c = '';
		update ctx.vehicle;

		ctx.vehicle.On_Deposit__c = true;
		ctx.vehicle.Going_To_Auction__c = true;
		ctx.vehicle.Hold_For_Financing__c = true;
		ctx.vehicle.Hold_For_Trade_In__c = true;
		update ctx.vehicle;
		assertNoTasksWithSubjectExistOnOpportunity(ctx.opportunity.Id, ShiftVehicles.SUBJECT_REMOVE_LISTING_FROM_EBAY);
	}

	@IsTest
	static void testUpdateParkingLot() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		ctx.insertOpportunity();
		System.assertEquals(ShiftTesting.PARKING_LOT_NAME_TESTING, [SELECT Parking_Lot_ID__r.Name FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Parking_Lot_ID__r.Name);

		Region__c newRegion = ShiftTesting.createRandomRegion('ParkingLotTest');
		insert newRegion;
		Parking_Lot__c newParkingLot = ShiftTesting.createRandomParkingLot(newRegion.Id, true);
		insert newParkingLot;
		ctx.vehicle.Listing_Region_ID__r = null;
		ctx.vehicle.Listing_Region_ID__c = newRegion.Id;
		update ctx.vehicle;
		System.assertEquals(newParkingLot.Name, [SELECT Parking_Lot_ID__r.Name FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Parking_Lot_ID__r.Name);
	}
}