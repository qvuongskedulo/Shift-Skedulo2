@IsTest
private class ShiftEvaluationsTriggersTest {
	@TestSetup private static void setup() { ShiftTesting.setup(); }

	@IsTest static void testEvaluationValidatePickupDropoff() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		insert new List<Opportunity>{ctx.opportunity};

		Evaluation__c eval = new Evaluation__c(
			Seller_Opportunity_ID__c = ctx.opportunity.Id,
			On_The_Spot_Pickup__c = true,
			Seller_Drop_Off__c = true
		);

		ShiftTesting.expectInsertExceptionContains(eval, ShiftEvaluations.EVALUATION_CHECKBOXES_ERROR);
	}

	@IsTest static void testEvaluationChangesPickupFee() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ShiftTesting.SellerTestContext ctxPickupDuringEval = ShiftTesting.prepareSellerTestContext();
		ShiftTesting.SellerTestContext ctxDropoff = ShiftTesting.prepareSellerTestContext();
		List<Opportunity> opportunities = new List<Opportunity>{ctx.opportunity, ctxPickupDuringEval.opportunity, ctxDropoff.opportunity};
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		ctxPickupDuringEval.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		ctxDropoff.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		insert opportunities;

		Evaluation__c eval = new Evaluation__c(
			Seller_Opportunity_ID__c = ctx.opportunity.Id
		);
		Evaluation__c evalPickupDuringEval = new Evaluation__c(
			On_The_Spot_Pickup__c = true,
			Seller_Opportunity_ID__c = ctxPickupDuringEval.opportunity.Id
		);
		Evaluation__c evalDropoff = new Evaluation__c(
			Seller_Drop_Off__c = true,
			Seller_Opportunity_ID__c = ctxDropoff.opportunity.Id
		);
		insert new List<Evaluation__c> {eval, evalPickupDuringEval, evalDropoff};

		List<Id> opportunityIds = new List<Id> {ctx.opportunity.Id, ctxPickupDuringEval.opportunity.Id, ctxDropoff.opportunity.Id};
		opportunities = [SELECT Id, Pickup_Fee__c FROM Opportunity where Id = :opportunityIds];
		Map<Id, Opportunity> updatedOpportunities = new Map<Id, Opportunity>(opportunities);
		System.assertEquals(updatedOpportunities.get(ctx.opportunity.Id).Pickup_Fee__c, ShiftConstants.SELLER_PICKUP_FEE);
		System.assertEquals(updatedOpportunities.get(ctxPickupDuringEval.opportunity.Id).Pickup_Fee__c, ShiftConstants.SELLER_PICKUP_DURING_EVAL_FEE);
		System.assertEquals(updatedOpportunities.get(ctxDropoff.opportunity.Id).Pickup_Fee__c, ShiftConstants.SELLER_DROPOFF_FEE);
	}

	@IsTest static void testEvaluationUpdatePickupFee() {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_EVALUATE;
		insert new List<Opportunity>{ctx.opportunity};

		Evaluation__c eval = new Evaluation__c(
			Seller_Opportunity_ID__c = ctx.opportunity.Id
		);
		insert new List<Evaluation__c> {eval};

		Map<Id, Opportunity> updatedOpportunities = new Map<Id, Opportunity>([SELECT Id, Pickup_Fee__c FROM Opportunity where Id = :ctx.opportunity.Id]);
		System.assertEquals(updatedOpportunities.get(ctx.opportunity.Id).Pickup_Fee__c, ShiftConstants.SELLER_PICKUP_FEE);

		eval.On_The_Spot_Pickup__c = true;
		update new List<Evaluation__c> {eval};

		updatedOpportunities = new Map<Id, Opportunity>([SELECT Id, Pickup_Fee__c FROM Opportunity where Id = :ctx.opportunity.Id]);
		System.assertEquals(updatedOpportunities.get(ctx.opportunity.Id).Pickup_Fee__c, ShiftConstants.SELLER_PICKUP_DURING_EVAL_FEE);
	}
}