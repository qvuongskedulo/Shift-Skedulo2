public class ShiftEvaluations {
	@TestVisible static final String EVALUATION_CHECKBOXES_ERROR = 'Should not have both "On The Spot Pickup" and "Seller Drop Off" selected.';

	private static void validateEvaluation(List<Evaluation__c> evaluations) {
		for (Evaluation__c eval : evaluations) {
			 //Ensure that the evaluation doesn't have both On The Spot Pickup and Seller Drop-Off checked
			if (eval.On_The_Spot_Pickup__c && eval.Seller_Drop_Off__c) {
				eval.On_The_Spot_Pickup__c.addError(EVALUATION_CHECKBOXES_ERROR);
				eval.Seller_Drop_Off__c.addError(EVALUATION_CHECKBOXES_ERROR);
			}
		}
	}

	private static void updateSellerOpportunityPickupFee(List<Evaluation__c> evaluations) {
		Map<Id, Opportunity> opportunitiesToUpdate = new Map<Id, Opportunity>();

		for (Evaluation__c eval : evaluations) {
			Id sellerOpportunityId = eval.Seller_Opportunity_ID__c;
			if (eval.On_The_Spot_Pickup__c) {
				opportunitiesToUpdate.put(sellerOpportunityId, new Opportunity(Id = sellerOpportunityId, Pickup_Fee__c = ShiftConstants.SELLER_PICKUP_DURING_EVAL_FEE));
			} else if (eval.Seller_Drop_Off__c) {
				opportunitiesToUpdate.put(sellerOpportunityId, new Opportunity(Id = sellerOpportunityId, Pickup_Fee__c = ShiftConstants.SELLER_DROPOFF_FEE));
			} else {
				opportunitiesToUpdate.put(sellerOpportunityId, new Opportunity(Id = sellerOpportunityId, Pickup_Fee__c = ShiftConstants.SELLER_PICKUP_FEE));
			}
		}

		update opportunitiesToUpdate.values();
	}

	public static void beforeInsert(List<Evaluation__c> newList) {
		validateEvaluation(newList);
		updateSellerOpportunityPickupFee(newList);
	}

	public static void beforeUpdate(Map<Id, Evaluation__c> oldMap, List<Evaluation__c> newList) {
		validateEvaluation(newList);

		List<Evaluation__c> changed = new List<Evaluation__c>();
		for (Evaluation__c eval : newList) {
			if (eval.On_The_Spot_Pickup__c != oldMap.get(eval.Id).On_The_Spot_Pickup__c || 
					eval.Seller_Drop_Off__c != oldMap.get(eval.Id).Seller_Drop_Off__c) {
				changed.add(eval);
			}
		}
		if (changed.isEmpty()) {
			return;
		}

		updateSellerOpportunityPickupFee(changed);
	}
}