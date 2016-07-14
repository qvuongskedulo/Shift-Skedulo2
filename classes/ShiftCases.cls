public class ShiftCases {
	static final Set<String> CASE_TYPES_TO_SET_CUSTOMER_SERVICE_REP_FOR = new Set<String>{
		ShiftConstants.CASE_TYPE_SHIFT_TEST_DRIVE_REQUEST,
		ShiftConstants.CASE_TYPE_SHIFT_TEST_DRIVE_REQUEST_REJECTED,
		ShiftConstants.CASE_TYPE_SHIFT_VEHICLE_QUESTION,
		ShiftConstants.CASE_TYPE_THIRD_PARTY_LISTING_SITE_VEHICLE_QUESTION
	};

	static void handleOwnerChanges(Map<Id, Case> oldMap, List<Case> newList) {
		Set<Id> opportunityIds = new Set<Id>();
		Map<Id, Case> filteredCases = new Map<Id, Case>();
		Id unownedUserId = ShiftUsers.unownedUserId();

		for (Case c : newList) {
			if (c.Opportunity_ID__c != null && CASE_TYPES_TO_SET_CUSTOMER_SERVICE_REP_FOR.contains(c.Case_Type__c) && c.OwnerId != unownedUserId) {
				opportunityIds.add(c.Opportunity_ID__c);
				filteredCases.put(c.Id, c);
			}
		}
		List<Id> ids = new List<Id>(opportunityIds);
		Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>([
			SELECT Id 
			FROM Opportunity
			WHERE Customer_Experience_Representative__c = null 
			AND RecordTypeId = :ShiftOpportunities.getBuyerRecordTypeId()
			AND Id in :ids
		]);

		List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();	
		for (Id caseId : filteredCases.keySet()) {
			Case c = filteredCases.get(caseId);
			Opportunity o = opportunityMap.get(c.Opportunity_ID__c);
			Case oldCase = oldMap.get(caseId);

			if (o != null && (oldCase == null || oldCase.OwnerId == unownedUserId)) {
				opportunitiesToUpdate.add(new Opportunity(
					Id = o.Id,
					Customer_Experience_Representative__c = c.OwnerId
				));			
			}
		}
		update opportunitiesToUpdate;
	}

	public static void afterInsert(List<Case> newList) {
		handleOwnerChanges(new Map<Id, Case>(), newList);
	}

	public static void afterUpdate(Map<Id, Case> oldMap, List<Case> newList) {
		handleOwnerChanges(oldMap, newList);
	}
}