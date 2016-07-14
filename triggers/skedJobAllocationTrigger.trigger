trigger skedJobAllocationTrigger on sked__Job_Allocation__c (after insert) {
    if (Trigger.IsAfter) {
        if (Trigger.IsInsert) {
            skedJobAllocationHandler.afterJobAllocationsInsert(Trigger.New);
        }
    }
}