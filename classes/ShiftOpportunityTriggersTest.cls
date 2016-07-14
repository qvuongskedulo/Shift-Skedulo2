@IsTest
private class ShiftOpportunityTriggersTest {

	@TestSetup private static void setup() { ShiftTesting.setup(); }

	static void insertOpportunity(boolean seller) {
		Region__c region = new Region__c(
			Name = 'Test Region',
			Shift_Key__c = 'us/sfo',
			Timezone__c = ShiftTesting.REGION_TIMEZONE_TESTING
		);
		insert region;
		insert ShiftTesting.createRandomParkingLot(region.Id, true);

		Account acct = new Account(Name = 'John Doe');
		insert acct;

		RecordType recordTypeSeller = [SELECT Id FROM RecordType WHERE DeveloperName = 'Seller' AND SObjectType = 'Opportunity'];
		RecordType recordTypeBuyer = [SELECT Id FROM RecordType WHERE DeveloperName = 'Buyer' AND SObjectType = 'Opportunity'];

		Opportunity opp = new Opportunity(
			CloseDate = Date.parse('01/02/3000'),
			StageName = seller ? ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE : ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED,
			RecordTypeId = seller ? recordTypeSeller.Id : recordTypeBuyer.Id,
			AccountId = acct.Id,
			Region_ID__r = new Region__c(Shift_Key__c = ShiftTesting.REGION_SHIFT_KEY_TESTING)
		);

		if (seller) {
			Vehicle__c bmw = new Vehicle__c(
				Year__c = 2010,
				Make__c = 'BMW',
				Model__c = '328i',
				Body_Style__c = 'Sedan',
				Exterior_Color__c = 'white',
				Mileage__c = 52000,
				List_Price__c = 20,
				Listing_Region_ID__c = region.ID
			);
			insert bmw;
			opp.Vehicle_ID__c = bmw.Id;
		}
		insert opp;
	}

	@IsTest
	static void testSeller() {
		insertOpportunity(true);
		System.assertEquals('2010 BMW 328i - John Doe - white', [SELECT Name FROM Opportunity LIMIT 1].Name);
	}

	@IsTest
	static void testSellerColorChange() {
		insertOpportunity(true);
		System.assertEquals('2010 BMW 328i - John Doe - white', [SELECT Name FROM Opportunity LIMIT 1].Name);
		Vehicle__c vehicle = [SELECT Id FROM Vehicle__c];
		vehicle.Exterior_Color__c = 'black';
		update vehicle;
		System.assertEquals('2010 BMW 328i - John Doe - black', [SELECT Name FROM Opportunity LIMIT 1].Name);
	}

	@IsTest
	static void testOpportunityInsertWithStagePrepare() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Shift_Contract__c sellerContract = ShiftTesting.createAndInsertShiftContract(ctx.opportunity.Id);
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		ctx.opportunity.Days_Guaranteed__c = '75';
		ctx.opportunity.Seller_Contract_ID__c = sellerContract.Id;
		ctx.insertOpportunity();

		System.assertEquals(Date.today().addDays(75), [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
		System.assertEquals(ShiftTesting.PARKING_LOT_NAME_TESTING, [SELECT Parking_Lot_ID__r.Name FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Parking_Lot_ID__r.Name);
	}

	@IsTest
	static void testSellerContractOnOpportunityInsertWithStageSell() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Shift_Contract__c sellerContract = ShiftTesting.createAndInsertShiftContract(ctx.opportunity.Id);
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ctx.opportunity.Days_Guaranteed__c = '75';
		ctx.opportunity.Seller_Contract_ID__c = sellerContract.Id;
		ctx.insertOpportunity();

		System.assertEquals(null, [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
	}

	@IsTest
	static void testSellerContractOnOpportunityWithNoSellerContract() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		ctx.opportunity.Days_Guaranteed__c = '75';
		ctx.insertOpportunity();

		// Ensure that the contract still doesn't exist and a task was created.
		System.assertEquals(null, [SELECT Seller_Contract_ID__c FROM Opportunity WHERE Id = :ctx.opportunity.Id].Seller_Contract_ID__c);
		System.assertEquals(0, [SELECT COUNT() FROM Shift_Contract__c WHERE Opportunity_ID__c = :ctx.opportunity.Id]);
		System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Subject = :ShiftConstants.TASK_SUBJECT_INPUT_CONTRACT_EXPIRATION_DATE]);

		// Update the opportunity.
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ctx.opportunity.Entered_Stage_Prepare_Car_For_Sale__c = DateTime.now().addDays(-10);
		update ctx.opportunity;

		// Ensure that the contract still doesn't exist and a task was created.
		System.assertEquals(null, [SELECT Seller_Contract_ID__c FROM Opportunity WHERE Id = :ctx.opportunity.Id].Seller_Contract_ID__c);
		System.assertEquals(0, [SELECT COUNT() FROM Shift_Contract__c WHERE Opportunity_ID__c = :ctx.opportunity.Id]);
		System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Subject = :ShiftConstants.TASK_SUBJECT_REVIEW_CONTRACT_EXPIRATION_DATE]);
	}

	@IsTest
	static void testSellerContractOnOpportunityWithNoDaysGuaranteed() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Shift_Contract__c sellerContract = ShiftTesting.createAndInsertShiftContract(ctx.opportunity.Id);
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		ctx.opportunity.Seller_Contract_ID__c = sellerContract.Id;
		ctx.insertOpportunity();

		// Ensure that the contract's expiration date isn't set and a task is created.
		System.assertEquals(null, [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
		System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Subject = :ShiftConstants.TASK_SUBJECT_INPUT_CONTRACT_EXPIRATION_DATE]);

		// Update the opportunity.
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ctx.opportunity.Entered_Stage_Prepare_Car_For_Sale__c = DateTime.now().addDays(-10);
		update ctx.opportunity;

		// Ensure that the contract's expiration date still isn't set and a task is created.
		System.assertEquals(null, [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
		System.assertEquals(1, [SELECT COUNT() FROM Task WHERE Subject = :ShiftConstants.TASK_SUBJECT_REVIEW_CONTRACT_EXPIRATION_DATE]);
	}

	@IsTest
	static void testOpportunityUpdateToStagePrepare() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Shift_Contract__c sellerContract = ctx.signSellerContract();
		ctx.opportunity.Days_Guaranteed__c = '75';
		ctx.insertOpportunity();

		Test.startTest();
		System.assertEquals(null, [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
		System.assertEquals(null, [SELECT Parking_Lot_ID__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Parking_Lot_ID__c);

		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		update ctx.opportunity;
		System.assertEquals(null, [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
		System.assertEquals(null, [SELECT Parking_Lot_ID__c FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Parking_Lot_ID__c);

		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		update ctx.opportunity;
		System.assertEquals(Date.today().addDays(75), [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
		System.assertEquals(ShiftTesting.PARKING_LOT_NAME_TESTING, [SELECT Parking_Lot_ID__r.Name FROM Vehicle__c WHERE Id = :ctx.vehicle.Id].Parking_Lot_ID__r.Name);
		Test.stopTest();
	}

	@IsTest
	static void testOpportunityUpdateToStagePrepareWithNoContract() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		insert ctx.opportunity;

		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		update ctx.opportunity;

		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		ShiftTesting.expectUpdateExceptionContains(ctx.opportunity, 'Cannot change to stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE + ': Seller Contract Signed On cannot be empty');
	}

	@IsTest
	static void testSellerContractOnOpportunityUpdateToStageSellAfterSevenDays() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Shift_Contract__c sellerContract = ShiftTesting.createAndInsertShiftContract(ctx.opportunity.Id);
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		ctx.opportunity.Days_Guaranteed__c = '75';
		ctx.opportunity.Seller_Contract_ID__c = sellerContract.Id;
		ctx.insertOpportunity();

		// Update the opportunity.
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ctx.opportunity.Entered_Stage_Prepare_Car_For_Sale__c = DateTime.now().addDays(-10);
		ctx.opportunity.Days_Guaranteed__c = '50';
		update ctx.opportunity;

		// Ensure that the expiration date is updated.
		System.assertEquals(Date.today().addDays(50), [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
	}

	@IsTest
	static void testSellerContractOnOpportunityUpdateToStageSellBeforeSevenDays() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Shift_Contract__c sellerContract = ShiftTesting.createAndInsertShiftContract(ctx.opportunity.Id);
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		ctx.opportunity.Days_Guaranteed__c = '75';
		ctx.opportunity.Seller_Contract_ID__c = sellerContract.Id;
		ctx.insertOpportunity();

		// Store the contract expiration date so we can ensure it doesn't change.
		DateTime originalContractExpiration = [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c;

		// Update the opportunity.
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ctx.opportunity.Days_Guaranteed__c = '50';
		ctx.opportunity.Entered_Stage_Prepare_Car_For_Sale__c = DateTime.now().addDays(-4);
		update ctx.opportunity;

		// Ensure that the expiration date is not updated (because it hasn't been seven days since PREPARE).
		System.assertEquals(originalContractExpiration, [SELECT Expires_On__c FROM Shift_Contract__c WHERE Id = :sellerContract.Id].Expires_On__c);
	}

	@IsTest
	static void testValidSellerUpsidePercentage() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_SINGLE_PRICE_0_UPSIDE;
		ctx.opportunity.Seller_Upside_Percentage__c = 0;
		insert ctx.opportunity;

		Test.startTest();
		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_SPECIFIC_CAR_SEARCH;
		update ctx.opportunity;

		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT;
		ctx.opportunity.Flat_Fee__c = 100;
		ctx.opportunity.Seller_Upside_Percentage__c = 100;
		update ctx.opportunity;

		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT;
		ctx.opportunity.Flat_Fee__c = null;
		ctx.opportunity.Flat_Fee_Percent__c = 100;
		update ctx.opportunity;
		Test.stopTest();
	}

	@IsTest
	static void testFailureOnInvalidSellerUpsidePercentage() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_SINGLE_PRICE_0_UPSIDE;
		ctx.opportunity.Seller_Upside_Percentage__c = 50;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Seller upside percentage must be 0 for pricing strategy: ' + ShiftConstants.PRICING_STRATEGY_SINGLE_PRICE_0_UPSIDE);

		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_SPECIFIC_CAR_SEARCH;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Seller upside percentage must be 0 for pricing strategy: ' + ShiftConstants.PRICING_STRATEGY_SPECIFIC_CAR_SEARCH);

		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Seller upside percentage must be 100 for pricing strategy: ' + ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT);

		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Seller upside percentage must be 100 for pricing strategy: ' + ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT);
	}

	@IsTest
	static void testFlatFeeDollarAmountValidation() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT;
		ctx.opportunity.Seller_Upside_Percentage__c = 100;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Flat Fee field must be populated for pricing strategy: ' + ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT);

		ctx.opportunity.Flat_Fee__c = 100;
		ctx.opportunity.Flat_Fee_Percent__c = 100;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Flat Fee - Percent field must not be populated for pricing strategy: ' + ShiftConstants.PRICING_STRATEGY_FLAT_FEE_DOLLAR_AMOUNT);

		ctx.opportunity.Flat_Fee_Percent__c = null;
		insert ctx.opportunity;
	}

	@IsTest
	static void testFlatFeePercentValidation() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.Pricing_Strategy__c = ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT;
		ctx.opportunity.Seller_Upside_Percentage__c = 100;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Flat Fee - Percent field must be populated for pricing strategy: ' + ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT);

		ctx.opportunity.Flat_Fee__c = 100;
		ctx.opportunity.Flat_Fee_Percent__c = 100;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Flat Fee field must not be populated for pricing strategy: ' + ShiftConstants.PRICING_STRATEGY_FLAT_FEE_PERCENT);

		ctx.opportunity.Flat_Fee__c = null;
		insert ctx.opportunity;
	}

	@IsTest
	static void testSpecificCarSearchWithFee() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.prepareSellerTestContext();
		sctx.opportunity.Specific_Car_Search__c = true;
		insert sctx.opportunity;

		ShiftTesting.BuyerTestContext bctx = ShiftTesting.prepareBuyerTestContext();
		bctx.opportunity.Specific_Car_Search_Fee__c = 100;
		insert bctx.opportunity;

		Test.startTest();
		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
		bctx.setAndUpdateOpenPurchase(vo);

		sctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER;
		update sctx.opportunity;
		Test.stopTest();
	}

	@IsTest
	static void testErrorSpecificCarSearchWithNoFee() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.prepareSellerTestContext();
		sctx.opportunity.Specific_Car_Search__c = true;
		insert sctx.opportunity;

		ShiftTesting.BuyerTestContext bctx = ShiftTesting.prepareBuyerTestContext();
		insert bctx.opportunity;

		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
		bctx.setOpenPurchase(vo);
		ShiftTesting.expectUpdateExceptionContains(vo, 'Specific Car Search is true but the buyer opportunity does not have a Specific Car Search Fee');
	}

	@IsTest
	static void testErrorNoSpecificCarSearchButFeePresent() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.prepareSellerTestContext();
		insert sctx.opportunity;

		ShiftTesting.BuyerTestContext bctx = ShiftTesting.prepareBuyerTestContext();
		bctx.opportunity.Specific_Car_Search_Fee__c = 100;
		insert bctx.opportunity;

		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
		bctx.setOpenPurchase(vo);
		ShiftTesting.expectUpdateExceptionContains(vo, 'Specific Car Search is false but the buyer opportunity has a Specific Car Search Fee');
	}

	@IsTest
	static void testStageChangeToHandover() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER;
		ShiftTesting.expectInsertExceptionContains(ctx.opportunity, 'Cannot change to stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER + ': vehicle does not have a completed sale');

		ShiftTesting.prepareVehicleForHandover(ctx.vehicle);
		insert ctx.opportunity;
	}

	@IsTest
	static void testValidationOnStageChangeFromHandoverToSellCar() {
		Test.startTest();
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();
		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
		bctx.setAndUpdateOpenPurchase(vo);
		Test.stopTest();

		ShiftTesting.expectOpportunityStage(sctx.opportunity.Id, ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER);
		sctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ShiftTesting.expectUpdateExceptionContains(sctx.opportunity, 'Cannot change from stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER + ' to stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL + ': vehicle has not been returned');

		bctx.setReturnedPurchase(vo);
		update vo;
		update sctx.opportunity;
	}

	@IsTest
	static void testValidationOnStageChangeFromSoldToSellCar() {
		Test.startTest();
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();
		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
		bctx.setAndUpdateOpenPurchase(vo);
		Test.stopTest();

		sctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD;
		update sctx.opportunity;

		sctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		ShiftTesting.expectUpdateExceptionContains(sctx.opportunity, 'Cannot change from stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD + ' to stage ' + ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL + ': vehicle has not been returned');

		bctx.setReturnedPurchase(vo);
		update vo;
		update sctx.opportunity;
	}

	@IsTest
	static void testStandardStageChangeToSellCar() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();
		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		Test.startTest();
		insert vo;
		bctx.setAndUpdateOpenPurchase(vo);
		sctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		sctx.signSellerContract();
		update sctx.opportunity;

		sctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		update sctx.opportunity;
		Test.stopTest();
	}

	@IsTest
	static void testExistingVehicleParkingLot() {
		Test.startTest();
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();
		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
		bctx.setAndUpdateOpenPurchase(vo);

		Parking_Lot__c parkingLot = ShiftTesting.createRandomParkingLot(ShiftTesting.getTestRegionId(), false);
		insert parkingLot;
		sctx.vehicle.Parking_Lot_ID__c = parkingLot.Id;
		update sctx.vehicle;
		Test.stopTest();

		sctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE;
		sctx.signSellerContract();
		update sctx.opportunity;
		System.assertEquals(ShiftTesting.PARKING_LOT_NAME_TESTING, [SELECT Parking_Lot_ID__r.Name FROM Vehicle__c WHERE Id = :sctx.vehicle.Id].Parking_Lot_ID__r.Name);
	}

	@IsTest
	static void testUpdateISRInboundAfterInsertAndUpdate() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Opportunity opportunity = ctx.opportunity;
		User user = ShiftTesting.createISRInboundUser();
		User userNew = ShiftTesting.createISRInboundUser();

		insert new List<User> {user, userNew};

		opportunity.OwnerId = user.Id;

		Test.startTest();
		insert opportunity;

		opportunity = [SELECT Id, Inside_Sales_Representative__c FROM Opportunity WHERE Id = :opportunity.Id];

		System.assertEquals(opportunity.Inside_Sales_Representative__c, user.Id);
		Test.stopTest();

		opportunity.OwnerId = userNew.Id;

		update opportunity;

		opportunity = [SELECT Id, Inside_Sales_Representative__c FROM Opportunity WHERE Id = :opportunity.Id];

		System.assertEquals(opportunity.Inside_Sales_Representative__c, userNew.Id);
	}

	@IsTest
	static void testUpdateISROutboundAfterInsertAndUpdate() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		Opportunity opportunity = ctx.opportunity;
		User user = ShiftTesting.createISROutboundUser();
		User userNew = ShiftTesting.createISROutboundUser();

		insert new List<User> {user, userNew};

		opportunity.OwnerId = user.Id;

		Test.startTest();
		insert opportunity;

		opportunity = [SELECT Id, Inside_Sales_Representative__c FROM Opportunity WHERE Id = :opportunity.Id];

		System.assertEquals(opportunity.Inside_Sales_Representative__c, user.Id);
		Test.stopTest();

		opportunity.OwnerId = userNew.Id;

		update opportunity;

		opportunity = [SELECT Id, Inside_Sales_Representative__c FROM Opportunity WHERE Id = :opportunity.Id];

		System.assertEquals(opportunity.Inside_Sales_Representative__c, userNew.Id);
	}

	@IsTest
	static void testBuyer() {
		insertOpportunity(false);
		System.assertEquals('John Doe', [SELECT Name FROM Opportunity LIMIT 1].Name);
	}

	@IsTest
	static void testAutoAdvanceStageWithSourceDriveshift() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.opportunity.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		ctx.opportunity.StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS;
		ctx.insertOpportunity();

		ShiftTesting.expectOpportunityStage(ctx.opportunity.Id, ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED);
	}

	@IsTest
	static void testNoAutoAdvanceStageWithSourceNonDriveshift() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.opportunity.LeadSource = ShiftConstants.LEAD_SOURCE_WORD_OF_MOUTH;
		ctx.opportunity.StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS;
		ctx.insertOpportunity();

		ShiftTesting.expectOpportunityStage(ctx.opportunity.Id, ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS);
	}

	@IsTest
	static void testNoAutoAdvanceStageWithStageNonLeads() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.opportunity.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		ctx.opportunity.StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_SOLD;
		ctx.insertOpportunity();

		ShiftTesting.expectOpportunityStage(ctx.opportunity.Id, ShiftConstants.BUYER_OPPORTUNITY_STAGE_SOLD);
	}
}