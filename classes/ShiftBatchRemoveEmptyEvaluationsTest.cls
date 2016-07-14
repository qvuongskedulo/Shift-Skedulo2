@isTest private class ShiftBatchRemoveEmptyEvaluationsTest {

	@testSetup private static void setup() { ShiftTesting.setup(); }

	@isTest private static void testExecute() {
		ShiftTesting.SellerTestContext sc = ShiftTesting.createAndInsertSeller();
		Id oppId = sc.opportunity.Id;
		List<Evaluation__c> evals = new List<Evaluation__c>();
		Integer insertSize = 100;
		for (Integer i = 0; i < insertSize; ++i) {
			Evaluation__c eval = new Evaluation__c(
				Seller_Opportunity_ID__c = oppId,
				Migration_Tree_ID__c = 'test-tree-id-' + i
			);
			if (Math.mod(i, 2) == 0) {
				eval.Canceled__c = false; // an empty migrated eval
			} else {
				eval.Evaluated_At__c = DateTime.now(); // a nonempty migrated eval
			}
			evals.add(eval);
		}
		insert evals;
		// also insert something which looks empty but wasn't migrated, ensure
		// we don't touch it
		insert new Evaluation__c( Seller_Opportunity_ID__c = oppId, Canceled__c = false);
		Test.startTest();
		Database.executeBatch(new ShiftBatchRemoveEmptyEvaluations());
		Test.stopTest();
		Integer ctRemain = [SELECT COUNT() FROM Evaluation__c WHERE Seller_Opportunity_ID__c = :oppId];
		System.assertEquals(insertSize / 2 + 1, ctRemain);
	}
}