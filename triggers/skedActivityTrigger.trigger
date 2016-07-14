trigger skedActivityTrigger on sked__Activity__c (after insert, after update, before delete) {
    if (Trigger.IsBefore) {
        if (Trigger.IsDelete) {
            skedActivityHandler.beforeActivitiesDelete(Trigger.Old);
        }
    } 
    else if (Trigger.IsAfter) {
        if (Trigger.IsInsert) {
            skedActivityHandler.afterActivitiesInsert(Trigger.New);
        }
        if (Trigger.IsUpdate) {
            skedActivityHandler.afterActivitiesUpdate(Trigger.OldMap, Trigger.New);
        }
    }
}