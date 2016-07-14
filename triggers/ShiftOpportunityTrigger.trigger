trigger ShiftOpportunityTrigger on Opportunity (before insert, before update, after insert, after update) {
  if (Trigger.isBefore) {
    if (Trigger.isInsert) {
      ShiftOpportunities.beforeInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      ShiftOpportunities.beforeUpdate(Trigger.oldMap, Trigger.new);
    }
  } else if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      ShiftOpportunities.afterInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      ShiftOpportunities.afterUpdate(Trigger.oldMap, Trigger.new);
    }
  }
}