trigger skedDeliveryTrigger on Delivery__c (after insert, after update) {
    if (Trigger.IsAfter) {
        if (Trigger.IsInsert) {
            skedDeliveryHandler.afterDeliverysInsert(Trigger.New);
        }
        if (Trigger.IsUpdate) {
            skedDeliveryHandler.afterDeliverysUpdate(Trigger.OldMap, Trigger.New);
        }
    }
}