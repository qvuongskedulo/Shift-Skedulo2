trigger ShiftVehicleOrderTrigger on Vehicle_Order__c (before insert, before update, after insert, after update) {
  if (Trigger.isBefore) {
    if (Trigger.isInsert) {
      ShiftVehicleOrders.beforeInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      ShiftVehicleOrders.beforeUpdate(Trigger.oldMap, Trigger.new);
    }
  } else if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      ShiftVehicleOrders.afterInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      ShiftVehicleOrders.afterUpdate(Trigger.oldMap, Trigger.new);
    }
  }
}