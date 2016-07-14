@IsTest private class ShiftStageChangeTriggerTest {
	@TestSetup private static void setup() { ShiftTesting.setup(); }

	private static void assertShiftStageChanges(ID oppID, List<String> expct) {
		List<Shift_Stage_Change__c> scList = [
				SELECT From_Stage__c, To_Stage__c, Changed_At__c, Changed_By__c
				FROM Shift_Stage_Change__c
				WHERE Opportunity_ID__c = :oppID
				ORDER BY SystemModstamp ASC
		];
		System.assertEquals(expct.size(), scList.size());
		for (Integer i = 0; i < expct.size(); ++i ) {
			Shift_Stage_Change__c sc = scList.get(i);
			String prevExpct = null;
			if (i > 0) {
				prevExpct = expct.get(i-1);
			}
			System.assertEquals(prevExpct, sc.From_Stage__c);
			System.assertEquals(expct.get(i), sc.To_Stage__c);
			System.assertNotEquals(null, sc.Changed_At__c);
			System.assertNotEquals(null, sc.Changed_By__c);
		}
	}

	@IsTest private static void testShiftStageChangeInsertsForSeller() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE;
		insert ctx.opportunity;
		assertShiftStageChanges(ctx.opportunity.Id, new String[]{
			ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE
		});
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL;
		update ctx.opportunity;
		assertShiftStageChanges(ctx.opportunity.Id, new String[]{
			ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE,
			ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL
		});
		ctx.opportunity.CloseDate = Date.today().addDays(30); // change that shouldn't generate stage change inserts
		update ctx.opportunity;
		assertShiftStageChanges(ctx.opportunity.Id, new String[]{
			ShiftConstants.SELLER_OPPORTUNITY_STAGE_QUOTE,
			ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL
		});
	}

	@IsTest private static void testShiftStageChangeInsertsForBuyer() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.opportunity.CloseDate = Date.today().addDays(60);
		ctx.opportunity.StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_HANDOVER;
		insert ctx.opportunity;
		assertShiftStageChanges(ctx.opportunity.Id, new String[]{
			ShiftConstants.BUYER_OPPORTUNITY_STAGE_HANDOVER
		});
		ctx.opportunity.StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_SOLD;
		update ctx.opportunity;
		assertShiftStageChanges(ctx.opportunity.Id, new String[]{
			ShiftConstants.BUYER_OPPORTUNITY_STAGE_HANDOVER,
			ShiftConstants.BUYER_OPPORTUNITY_STAGE_SOLD
		});
		ctx.opportunity.CloseDate = Date.today().addDays(30);
		update ctx.opportunity;
		assertShiftStageChanges(ctx.opportunity.Id, new String[]{
			ShiftConstants.BUYER_OPPORTUNITY_STAGE_HANDOVER,
			ShiftConstants.BUYER_OPPORTUNITY_STAGE_SOLD
		});
	}

	// Asserts that the given opp has stage entry values only for the expected fields
	private static void assertStageEntryFields(ID sellerID, Set<Schema.SObjectField> expct) {
		List<Schema.SObjectField> allFields = new List<Schema.SObjectField>{
			Schema.Opportunity.Entered_Stage_Evaluate_And_Pickup__c,
			Schema.Opportunity.Entered_Stage_Handover__c,
			Schema.Opportunity.Entered_Stage_Leads__c,
			Schema.Opportunity.Entered_Stage_Lost__c,
			Schema.Opportunity.Entered_Stage_Prepare_Car_For_Sale__c,
			Schema.Opportunity.Entered_Stage_Quote_And_Schedule__c,
			Schema.Opportunity.Entered_Stage_Sell_Car__c,
			Schema.Opportunity.Entered_Stage_Sold__c
		};
		Opportunity seller = [
				SELECT
					Entered_Stage_Evaluate_And_Pickup__c,
					Entered_Stage_Handover__c,
					Entered_Stage_Leads__c,
					Entered_Stage_Lost__c,
					Entered_Stage_Prepare_Car_For_Sale__c,
					Entered_Stage_Quote_And_Schedule__c,
					Entered_Stage_Sell_Car__c,
					Entered_Stage_Sold__c
				FROM Opportunity
				WHERE ID = :sellerID
		];
		for (Schema.SObjectField fld : allFields) {
			Object val = seller.get(fld);
			if (expct.contains(fld)) {
				System.assertNotEquals(null, val);
			} else {
				System.assertEquals(null, val);
			}
		}
	}

	@IsTest private static void testStageChangeEntryTimeNotOverwritten() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		Set<Schema.SObjectField> expct = new Set<Schema.SObjectField>{Schema.Opportunity.Entered_Stage_Evaluate_And_Pickup__c};
		Test.startTest();
		insert ctx.opportunity;
		assertStageEntryFields(ctx.opportunity.Id, expct);
		// set a stage value to something non-empty to assert below that the trigger does not
		// overwrite it.	Note that the value doesn't need to be in the past necessarily, but we
		// set it just to avoid any possibility of a false positive in our testing in which the
		// trigger does in fact set a value (the same one) on top of an existing one.
		ctx.opportunity.Entered_Stage_Handover__c = DateTime.now().addDays(-1);
		update ctx.opportunity;
		Test.stopTest();
		// This automatically changes the vehicle's seller opportunity's stage to Handover.
		ShiftTesting.prepareVehicleForHandover(ctx.vehicle);
		expct.add(Schema.Opportunity.Entered_Stage_Handover__c);
		update ctx.opportunity;
		assertStageEntryFields(ctx.opportunity.Id, expct);
		Opportunity o = [SELECT Entered_Stage_Handover__c FROM Opportunity WHERE ID = :ctx.opportunity.Id];
		System.assertEquals(ctx.opportunity.Entered_Stage_Handover__c, o.Entered_Stage_Handover__c);
	}

	private static void assertSellerStageChangeEntry(String fromStage, Schema.SObjectField fromStageEntryField, String toStage, Schema.SObjectField toStageEntryField) {
		Test.startTest();
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = fromStage;
		Set<Schema.SObjectField> expect = new Set<Schema.SObjectField>{fromStageEntryField};
		insert ctx.opportunity;
		assertStageEntryFields(ctx.opportunity.Id, expect);
		if (toStage == ShiftConstants.SELLER_OPPORTUNITY_STAGE_HANDOVER) {
			// This automatically changes the vehicle's seller opportunity's stage to Handover.
			ShiftTesting.prepareVehicleForHandover(ctx.vehicle);
		} else {
			ctx.opportunity.StageName = toStage;
		}
		Test.stopTest();
		expect.add(toStageEntryField);
		// query limits
		ctx.signSellerContract();
		update ctx.opportunity;
		assertStageEntryFields(ctx.opportunity.Id, expect);
	}

	// The testEnteredXXXAndYYY() methods below are a hack to give coverage of each of the
	// fields for which we expect to maintain an explicit first-entry timestamp. Originally they
	// were all sequential in one test method, but with the growth of our trigger codebase that
	// has led us to exceed the governor limits in that long test, so we just break it down into
	// smaller individual test methods. There is nothing magical about the groupings of a
	// particular XXX and YYY below.

	@IsTest private static void testEnteredEvaluateAndPickupAndHandover() {
		assertSellerStageChangeEntry('Evaluate and Pickup', Schema.Opportunity.Entered_Stage_Evaluate_And_Pickup__c, 'Handover', Schema.Opportunity.Entered_Stage_Handover__c);
	}

	@IsTest private static void testEnteredLeadsAndLost() {
		assertSellerStageChangeEntry('Leads', Schema.Opportunity.Entered_Stage_Leads__c, 'Lost', Schema.Opportunity.Entered_Stage_Lost__c);
	}

	@IsTest private static void testEnteredQuoteAndSchedulePrepareCarForSale() {
		assertSellerStageChangeEntry('Quote and Schedule', Schema.Opportunity.Entered_Stage_Quote_And_Schedule__c, 'Prepare Car For Sale', Schema.Opportunity.Entered_Stage_Prepare_Car_For_Sale__c);
	}

	@IsTest private static void testSellCarAndSold() {
		assertSellerStageChangeEntry('Sell Car', Schema.Opportunity.Entered_Stage_Sell_Car__c, 'Sold', Schema.Opportunity.Entered_Stage_Sold__c);
	}

	@IsTest private static void testStageEntryTriggerIsNoOpOnUntrackedStage() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = 'not in use';
		Set<Schema.SObjectField> expct = new Set<Schema.SObjectField>();
		insert ctx.opportunity;
		assertStageEntryFields(ctx.opportunity.Id, expct);
	}
}