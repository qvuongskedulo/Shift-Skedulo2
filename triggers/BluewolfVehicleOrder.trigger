trigger BluewolfVehicleOrder on Vehicle_Order__c (after insert, after update) {
    BluewolfVehicleOrderTriggerHandler handler = new BluewolfVehicleOrderTriggerHandler(Trigger.new, Trigger.oldMap);

    if (Trigger.isBefore) {

    } else if(Trigger.isAfter){
        if (Trigger.isInsert) handler.afterInsert();
        else if (Trigger.isUpdate) handler.afterUpdate();
    }
}