@IsTest
private class ShiftVehicleOrderTriggersTest {
	@TestSetup private static void setup() { ShiftTesting.setup(); }

	@IsTest
	static void testErrorOnDepositReturnedWithoutDeposit() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		vo.Deposit_Returned_Reason__c = ShiftConstants.VEHICLE_ORDER_DEPOSIT_RETURNED_REASON_OTHER;
		ShiftTesting.expectInsertExceptionContains(vo, 'Cannot insert vehicle order with deposit returned but no deposit');
	}

	@IsTest
	static void testErrorOnVehicleReturnWithoutPurchase() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		vo.Returned_On__c = Date.today();
		ShiftTesting.expectInsertExceptionContains(vo, 'Cannot insert vehicle order with vehicle returned but no vehicle purchased');
	}

	@IsTest
	static void testErrorOnOpenDepositOnVehicleWithExistingOpenDeposit() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		ShiftTesting.setOpenDeposit(vo1);
		insert vo1;

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		ShiftTesting.setOpenDeposit(vo2);
		ShiftTesting.expectInsertExceptionContains(vo2, 'Vehicle already has an open order');
	}

	@IsTest
	static void testErrorOnOpenPurchaseOnVehicleWithExistingOpenDeposit() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		insert vo1;
		ShiftTesting.setOpenDeposit(vo1);
		update vo1;

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		insert vo2;
		ctx.setOpenPurchase(vo2);
		ShiftTesting.expectUpdateExceptionContains(vo2, 'Vehicle already has an open order');
	}

	@IsTest
	static void testReturnedDepositOnVehicleWithExistingOpenDeposit() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		ShiftTesting.setOpenDeposit(vo1);
		insert vo1;

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		ShiftTesting.setReturnedDeposit(vo2);
		insert vo2;
		System.assertEquals(2, [SELECT COUNT() FROM Vehicle_Order__c WHERE Vehicle_ID__c = :v.Id]);
	}

	@IsTest
	static void testErrorOnOpenDepositOnVehicleWithExistingOpenPurchase() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		insert vo1;
		ctx.setAndUpdateOpenPurchase(vo1);

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		ShiftTesting.setOpenDeposit(vo2);
		ShiftTesting.expectInsertExceptionContains(vo2, 'Vehicle already has an open order');
	}

	@IsTest
	static void testErrorOnOpenPurchaseOnVehicleWithExistingOpenPurchase() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		insert vo1;
		ctx.setAndUpdateOpenPurchase(vo1);

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		insert vo2;
		ctx.setOpenPurchase(vo2);
		ShiftTesting.expectUpdateExceptionContains(vo2, 'Vehicle already has an open order');
	}

	@IsTest
	static void testReturnedDepositOnVehicleWithExistingOpenPurchase() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		insert vo1;
		ctx.setAndUpdateOpenPurchase(vo1);

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		insert vo2;
		ShiftTesting.setReturnedDeposit(vo2);
		update vo2;
		System.assertEquals(2, [SELECT COUNT() FROM Vehicle_Order__c WHERE Vehicle_ID__c = :v.Id]);
	}

	@IsTest
	static void testOpenDepositOnVehicleWithExistingOrder() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		insert vo1;

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		ShiftTesting.setOpenDeposit(vo2);
		insert vo2;
		System.assertEquals(2, [SELECT COUNT() FROM Vehicle_Order__c WHERE Vehicle_ID__c = :v.Id]);
	}

	@IsTest
	static void testOpenPurchaseOnVehicleWithExistingOrder() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		insert vo1;

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		insert vo2;
		ctx.setAndUpdateOpenPurchase(vo2);
		System.assertEquals(2, [SELECT COUNT() FROM Vehicle_Order__c WHERE Vehicle_ID__c = :v.Id]);
	}

	@IsTest
	static void testReturnedDepositOnVehicleWithExistingOrder() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo1 = ctx.createVehicleOrder(v);
		insert vo1;

		Vehicle_Order__c vo2 = ctx.createVehicleOrder(v);
		ShiftTesting.setReturnedDeposit(vo2);
		insert vo2;
		System.assertEquals(2, [SELECT COUNT() FROM Vehicle_Order__c WHERE Vehicle_ID__c = :v.Id]);
	}

	@IsTest
	static void testReturnedPurchaseOnVehicleWithExistingOrder() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();
		Vehicle_Order__c vo1 = bctx.createVehicleOrder(sctx.vehicle);
		insert vo1;

		Test.startTest();
		Vehicle_Order__c vo2 = bctx.createVehicleOrder(sctx.vehicle);
		insert vo2;
		bctx.setAndUpdateOpenPurchase(vo2);
		bctx.setReturnedPurchase(vo2);
		update vo2;
		System.assertEquals(2, [SELECT COUNT() FROM Vehicle_Order__c WHERE Vehicle_ID__c = :sctx.vehicle.Id]);
		Test.stopTest();
	}

	static void testErrorOnVehicleWithIncompleteOpenPurchase() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);

		vo.Final_Sale_Price__c = 10000.00;
		ShiftTesting.expectInsertExceptionContains(vo, 'Vehicle order must have all or none');

		vo.Taxes_And_Registration__c = 1000.00;
		ShiftTesting.expectInsertExceptionContains(vo, 'Vehicle order must have all or none');

		vo.Final_Sale_Price__c = null;
		ShiftTesting.expectInsertExceptionContains(vo, 'Vehicle order must have all or none');

		vo.Payment_Method__c = ShiftConstants.VEHICLE_ORDER_PAYMENT_METHOD_CASH;
		ShiftTesting.expectInsertExceptionContains(vo, 'Vehicle order must have all or none');

		vo.Taxes_And_Registration__c = null;
		ShiftTesting.expectInsertExceptionContains(vo, 'Vehicle order must have all or none');

		vo.Final_Sale_Price__c = 10000.00;
		ShiftTesting.expectInsertExceptionContains(vo, 'Vehicle order must have all or none');
	}

	@IsTest
	static void testErrorOnVehicleSaleCompleteWithIncompleteOpenPurchase() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		vo.Vehicle_Sale_Complete__c = true;
		ShiftTesting.expectInsertExceptionContains(vo, ShiftVehicleOrders.VEHICLE_SALE_CANNOT_COMPLETE_ERROR);

		vo.Final_Sale_Price__c = 100;
		vo.Taxes_And_Registration__c = 100;
		ShiftTesting.expectInsertExceptionContains(vo, ShiftVehicleOrders.VEHICLE_SALE_CANNOT_COMPLETE_ERROR);

		vo.Taxes_And_Registration__c = null;
		vo.Final_Sale_Price__c = null;
		vo.Vehicle_Sale_Complete__c = false;
		insert vo;
		Payment__c payment = ctx.createPayment(vo);
		insert payment;
		vo.Vehicle_Sale_Complete__c = true;
		ShiftTesting.expectUpdateExceptionContains(vo, ShiftVehicleOrders.VEHICLE_SALE_CANNOT_COMPLETE_ERROR);
	}

	@IsTest
	static void testOpportunityStageOnVehicleOrderInsertUpdate() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();

		Test.startTest();
		Vehicle_Order__c vo1 = bctx.createVehicleOrder(sctx.vehicle);
		insert vo1;
		System.assertEquals(ShiftConstants.SELLER_OPPORTUNITY_STAGE_LEADS, [SELECT StageName FROM Opportunity WHERE Id = :sctx.opportunity.Id].StageName);
		System.assertEquals(null, [SELECT Handover_Date__c FROM Vehicle_Order__c WHERE Id = :vo1.Id].Handover_Date__c);

		Vehicle_Order__c vo2 = bctx.createVehicleOrder(sctx.vehicle);
		insert vo2;
		bctx.setOpenPurchase(vo2);
		update vo2;
		System.assertEquals(ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER, [SELECT StageName FROM Opportunity WHERE Id = :sctx.opportunity.Id].StageName);
		System.assertEquals(Date.today(), [SELECT Handover_Date__c FROM Vehicle_Order__c WHERE Id = :vo2.Id].Handover_Date__c);

		bctx.setReturnedPurchase(vo2);
		update vo2;
		System.assertEquals(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL, [SELECT StageName FROM Opportunity WHERE Id = :sctx.opportunity.Id].StageName);
		System.assertEquals(Date.today(), [SELECT Handover_Date__c FROM Vehicle_Order__c WHERE Id = :vo2.Id].Handover_Date__c);
		Test.stopTest();
	}

	@IsTest
	static void testErrorOnInsertNewlySoldOrderAlreadyReturned() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		vo.Final_Sale_Price__c = 10000.00;
		vo.Taxes_And_Registration__c = 1000.00;
		vo.Payment_Method__c = ShiftConstants.VEHICLE_ORDER_PAYMENT_METHOD_CASH;
		vo.Vehicle_Sale_Complete__c = true;
		vo.Returned_On__c = Date.today();
		vo.Returned_Reason__c = ShiftConstants.VEHICLE_ORDER_RETURNED_REASON_BUYERS_REMORSE;
		ShiftTesting.expectInsertExceptionContains(vo, 'A vehicle order cannot be newly sold and also returned');
	}

	@IsTest
	static void testErrorOnUpdateNewlySoldOrderAlreadyReturned() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		insert vo;
		ctx.setReturnedPurchase(vo);
		ShiftTesting.expectUpdateExceptionContains(vo, 'A vehicle order cannot be newly sold and also returned');
	}

	@IsTest
	static void testErrorOnInsertNewlySoldOrderWithHandoverDate() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.insertOpportunity();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		vo.Handover_Date__c = Date.today();
		vo.Final_Sale_Price__c = 10000.00;
		vo.Taxes_And_Registration__c = 1000.00;
		vo.Vehicle_Sale_Complete__c = true;
		vo.Payment_Method__c = ShiftConstants.VEHICLE_ORDER_PAYMENT_METHOD_CASH;
		ShiftTesting.expectInsertExceptionContains(vo, 'A vehicle order cannot be newly sold with an existing handover date');
	}

	@IsTest
	static void testErrorOnUpdateNewlySoldOrderWithHandoverDate() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.insertOpportunity();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		insert vo;
		vo.Handover_Date__c = Date.today();
		ctx.setOpenPurchase(vo);
		ShiftTesting.expectUpdateExceptionContains(vo, 'A vehicle order cannot be newly sold with an existing handover date');
	}

	@IsTest
	static void testDepositReturnOnVehicleReturn() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();
		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
		bctx.setOpenPurchase(vo);
		ShiftTesting.setOpenDeposit(vo);
		Test.startTest();
		update vo;

		bctx.setReturnedPurchase(vo);
		update vo;
		Vehicle_Order__c updatedVehicleOrder = [SELECT Deposit_Returned_On__c, Deposit_Returned_Reason__c FROM Vehicle_Order__c WHERE Id = :vo.Id];
		System.assertEquals(vo.Returned_On__c, updatedVehicleOrder.Deposit_Returned_On__c);
		System.assertEquals(ShiftConstants.VEHICLE_ORDER_DEPOSIT_RETURNED_REASON_CAR_RETURNED, updatedVehicleOrder.Deposit_Returned_Reason__c);
		Test.stopTest();
	}

	@IsTest
	static void testNoDepositReturnOnVehicleReturnWithNoDeposit() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();
		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
    Test.startTest();
		bctx.setOpenPurchase(vo);
		update vo;

		bctx.setReturnedPurchase(vo);
		update vo;
		Vehicle_Order__c updatedVehicleOrder = [SELECT Deposit_Returned_On__c, Deposit_Returned_Reason__c FROM Vehicle_Order__c WHERE Id = :vo.Id];
		System.assertEquals(null, updatedVehicleOrder.Deposit_Returned_On__c);
		System.assertEquals(null, updatedVehicleOrder.Deposit_Returned_Reason__c);
    Test.stopTest();
	}

	@IsTest
	static void testErrorOnVehicleWithIncompleteReturn() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		insert vo;
		ctx.setOpenPurchase(vo);
		update vo;

		vo.Returned_On__c = Date.today();
		ShiftTesting.expectUpdateExceptionContains(vo, 'If Returned On is specified, Returned Reason must also be specified');

		vo.Returned_On__c = null;
		vo.Returned_Reason__c = ShiftConstants.VEHICLE_ORDER_RETURNED_REASON_BUYERS_REMORSE;
		ShiftTesting.expectUpdateExceptionContains(vo, 'If Returned Reason is specified, Returned On must also be specified');
	}

	@IsTest
	static void testOnDepositTriggerReturned() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);

		vo.Deposit_Accepted_On__c = Date.today();
		vo.Deposit_Returned_On__c = null;
		vo.Deposit_Expired__c = false;
		insert vo;
		v = [SELECT Id, On_Deposit__c FROM Vehicle__c WHERE Id = :v.Id];
		System.assertEquals(v.On_Deposit__c, true);

		vo.Deposit_Returned_On__c = Date.today();
		vo.Deposit_Returned_Reason__c = ShiftConstants.VEHICLE_ORDER_RETURNED_REASON_BUYERS_REMORSE;
		update vo;
		v = [SELECT Id, On_Deposit__c FROM Vehicle__c WHERE Id = :v.Id];
		System.assertEquals(false, v.On_Deposit__c);
	}


	@IsTest
	static void testOnDepositTriggerExpired() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);

		vo.Deposit_Accepted_On__c = Date.today();
		vo.Deposit_Returned_On__c = null;
		vo.Deposit_Expired__c = false;
		insert vo;

		v = [SELECT Id, On_Deposit__c FROM Vehicle__c WHERE Id = :v.Id];
		System.assertEquals(true, v.On_Deposit__c);

		vo.Deposit_Expired__c = true;
		update vo;
		v = [SELECT Id, On_Deposit__c FROM Vehicle__c WHERE Id = :v.Id];
		System.assertEquals(false, v.On_Deposit__c);
	}

	@IsTest
	static void testAssignPurchasedVehicleOrder() {
		ShiftTesting.SellerTestContext sctx = ShiftTesting.createAndInsertSeller();
		ShiftTesting.BuyerTestContext bctx = ShiftTesting.createAndInsertBuyer();
		Vehicle_Order__c vo = bctx.createVehicleOrder(sctx.vehicle);
		insert vo;
		Test.startTest();
		System.assertEquals(null, [SELECT Purchased_Vehicle_Order_ID__c FROM Vehicle__c WHERE Id = :sctx.vehicle.Id].Purchased_Vehicle_Order_ID__c);

		vo.Final_Sale_Price__c = 10000.00;
		vo.Taxes_And_Registration__c = 1000.00;
		vo.Payment_Method__c = ShiftConstants.VEHICLE_ORDER_PAYMENT_METHOD_CASH;
		update vo;
		System.assertEquals(null, [SELECT Purchased_Vehicle_Order_ID__c FROM Vehicle__c WHERE Id = :sctx.vehicle.Id].Purchased_Vehicle_Order_ID__c);

		bctx.setOpenPurchase(vo);
		update vo;
		System.assertEquals(vo.Id, [SELECT Purchased_Vehicle_Order_ID__c FROM Vehicle__c WHERE Id = :sctx.vehicle.Id].Purchased_Vehicle_Order_ID__c);

		bctx.setReturnedPurchase(vo);
		update vo;
		System.assertEquals(null, [SELECT Purchased_Vehicle_Order_ID__c FROM Vehicle__c WHERE Id = :sctx.vehicle.Id].Purchased_Vehicle_Order_ID__c);
		Test.stopTest();
	}
}