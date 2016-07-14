// ensures that when Opportunity.Vehicle_ID__c is set that the referenced
// vehicle points back to the seller (and updates affected vehicles so they can
// assert that they are not referenced from more than one opportunity)
trigger ShiftOpportunityVehicleIdInsertUpdate on Opportunity (after insert, after update) {
    List<Id> vehicleIds = new List<Id>();
    for (Opportunity opp : Trigger.new) {
        if (opp.Vehicle_ID__c != null) { // may not be a seller opp
            vehicleIds.add(opp.Vehicle_ID__c);
        }
    }
    if (vehicleIds.isEmpty()) {
        return;
    }
    Map<Id, Vehicle__c> vehiclesMap = new Map<Id, Vehicle__c>([SELECT Id, Seller_Opportunity_ID__c FROM Vehicle__c WHERE Id IN :vehicleIds]);
        
    // updates tracks vehicles that are updated as a result of this trigger, and
    // updatesSeen allows us to fail if we see multiple updates to a vehicle
    // (and thus to its Seller_Opportunity_ID__c field) in this batch (we need
    // to track this ourselves rather than accumulate dupes in updates since the
    // final update() call will fail leading to a higher level error ("duplicate
    // elements in list") than what we'd like (multiple changes to vehicle)
    List<Vehicle__c> updates = new List<Vehicle__c>();
    Set<Id> updatesSeen = new Set<Id>();
    for (Opportunity opp : Trigger.new) {
        Vehicle__c v = vehiclesMap.get(opp.Vehicle_ID__c);
        if (v == null) {
            continue;
        }
        if (!updatesSeen.add(v.Id)) {
            opp.Vehicle_ID__c.addError('operation contains multiple assignments to vehicle ' + v.Id);
            continue;
        }
        updates.add(new Vehicle__c(Id = v.Id, Seller_Opportunity_ID__c = Trigger.isDelete ? null : opp.Id));
    }
    // now add to updates the clearing of Seller_Opportunity_ID__c for any
    // vehicles which are newly unreferenced
    if (Trigger.isUpdate) {
        for (Opportunity opp : Trigger.old) {
            Opportunity newOpp = Trigger.newMap.get(opp.Id);
            Id newVh = newOpp.Vehicle_ID__c;
            Id oldVh = Trigger.oldMap.get(opp.Id).Vehicle_ID__c;
            if (oldVh == null || oldVh.equals(newVh)) {
                continue;
            }
            if (!updatesSeen.add(oldVh)) {
                newOpp.Vehicle_ID__c.addError('operation had multiple references to vehicle ' + oldVh);
                continue;
            }
            updates.add(new Vehicle__c(Id = oldVh, Seller_Opportunity_ID__c = null));
        }
    }
    update updates;
}