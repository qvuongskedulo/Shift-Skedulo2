trigger ShiftIncentiveTrigger on Incentive__c (before update) {
  if (Trigger.isBefore) {
    if (Trigger.isUpdate) {
      ShiftIncentives.beforeUpdate(Trigger.oldMap, Trigger.new);
    }
  }
}