trigger skedJobTrigger on sked__Job__c (before insert, before update, after insert, after update, before delete) {
    if (Trigger.IsBefore) {
        if (Trigger.IsInsert) {
            skedJobHandler.beforeJobsInsert(Trigger.New);
        }
        if (Trigger.IsUpdate) {
            skedJobHandler.beforeJobsUpdate(Trigger.OldMap, Trigger.New);
        }
        if (Trigger.IsDelete) {
            skedJobHandler.beforeJobsDelete(Trigger.Old);
        }
    } 
    else if (Trigger.IsAfter) {
        if (Trigger.IsInsert) {
            skedJobHandler.afterJobsInsert(Trigger.New);
        }
        if (Trigger.IsUpdate) {
            skedJobHandler.afterJobsUpdate(Trigger.OldMap, Trigger.New);
        }
    }
}