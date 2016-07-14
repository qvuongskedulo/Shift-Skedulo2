trigger BluewolfVehicle on Vehicle__c (after update) {
    BluewolfVehicleTriggerHandler handler = new BluewolfVehicleTriggerHandler(Trigger.new, Trigger.oldMap);

    if (Trigger.isBefore) {

    } else {
        if (Trigger.isUpdate) handler.afterUpdate();
    }
}