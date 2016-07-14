trigger ShiftStageChangeInsertTrigger on Opportunity (after insert, after update) {
	// trigger runs after insert, update so that we can get the value of LastModifiedDate
	// for use in our stage change. We could run as before, and avoid the extra update at the end,
	// but we'd have to use DateTime.now() for Changed_At__c, but it could be different, if even
	// only by microseconds. In case it leads to confusion later, we'll start by keeping the two
	List<Shift_Stage_Change__c> scList = new List<Shift_Stage_Change__c>();
    for (Opportunity opp : Trigger.new) {
        Shift_Stage_Change__c sc = null;
        if (Trigger.isUpdate) {
            String prev = Trigger.oldMap.get(opp.ID).StageName;
            if (prev.equals(opp.StageName)) {
                continue;
            }
            sc = new Shift_Stage_Change__c(From_Stage__c = prev);
        } else {
            // Don't add stage changes on insert of a migrated object (migration will set stage changes)
            if (opp.Migration_Tree_ID__c != null) {
                continue;
            }
            sc = new Shift_Stage_Change__c();
        }
        sc.To_Stage__c = opp.StageName;
        sc.Opportunity_ID__c = opp.ID;
        sc.Changed_At__c = opp.LastModifiedDate;
        sc.Changed_By__c = opp.LastModifiedByID;
        scList.add(sc);
    }
    if (scList.isEmpty()) {
    	return;
    }
    insert scList;
	ShiftOpportunities.processStageChanges(scList, Trigger.newMap);
}