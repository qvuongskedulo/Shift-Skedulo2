trigger ShiftVehicleTrigger on Vehicle__c (before insert, before update, after insert, after update) {
  if (Trigger.isBefore) {
    if (Trigger.isInsert) {
      ShiftVehicles.beforeInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      ShiftVehicles.beforeUpdate(Trigger.oldMap, Trigger.new);
    }
  } else if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      ShiftVehicles.afterInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      ShiftVehicles.afterUpdate(Trigger.oldMap, Trigger.new);
    }
  }
}