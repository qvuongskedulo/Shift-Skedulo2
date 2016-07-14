trigger skedPickupTrigger on Pick_Up__c (after insert, after update) {
    if (Trigger.IsAfter) {
        if (Trigger.IsInsert) {
            skedPickupHandler.afterPickupsInsert(Trigger.New);
        }
        if (Trigger.IsUpdate) {
            skedPickupHandler.afterPickupsUpdate(Trigger.OldMap, Trigger.New);
        }
    }
}