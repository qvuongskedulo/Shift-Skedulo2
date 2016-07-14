public class ShiftDelivery {

	static Case createNewCase(Delivery__c delivery, Id buyerOpportunityId) {
		return new Case(
				Case_Type__c = ShiftConstants.CASE_TYPE_DELIVERY_REQUEST,
				Delivery__c = delivery.Id,
				Delivery_By__c = delivery.Delivery_By__c,
				Delivery_Notes__c = delivery.Notes__c,
				Delivery_Scheduled_By__c = delivery.Scheduled_By__c,
				Delivery_Scheduled_For__c = delivery.Scheduled_For__c,
				Location__c = delivery.Location__c,
				Opportunity_ID__c = buyerOpportunityId,
				OwnerId = ShiftUsers.unownedUserId(),
				Status = ShiftConstants.CASE_STATUS_NEW,
				Vehicle_Interest__c = delivery.Vehicle_Interest__c
		);
	}

	static void insertNewCases(List<Delivery__c> newList) {
		List<Case> casesToInsert = new List<Case>();
		Set<Id> vehicleInterestIds = new Set<Id>();
		for (Delivery__c delivery : newList) {
			vehicleInterestIds.add(delivery.Vehicle_Interest__c);
		}

		Map<Id, Vehicle_Interest__c> relatedVi = new Map<Id, Vehicle_Interest__c>(
			[SELECT Id, Buyer_Opportunity_ID__c FROM Vehicle_Interest__c WHERE Id IN :vehicleInterestIds]
		);
		for (Delivery__c delivery : newList) {
			Vehicle_Interest__c vi = relatedVi.get(delivery.Vehicle_Interest__c);
			casesToInsert.add(createNewCase(delivery, vi.Buyer_Opportunity_ID__c));
		}
		insert casesToInsert;
	}

	public static void afterInsert(List<Delivery__c> newList) {
		insertNewCases(newList);
	}
}