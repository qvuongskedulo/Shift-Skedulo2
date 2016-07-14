public class ShiftIncentives {
  static void validateIncentives(Map<Id, Incentive__c> oldMap, List<Incentive__c> newList) {
    for (Incentive__c incentive : newList) {
      Incentive__c oldIncentive = oldMap.get(incentive.Id);
      if (oldIncentive.Token__c != null && incentive.Token__c != oldIncentive.Token__c) {
        incentive.addError('Attempt to change Token__c from ' + oldIncentive.Token__c + ' to ' + incentive.Token__c);
      }
      if (oldIncentive.Incentive_Program_ID__c != null && incentive.Incentive_Program_ID__c != oldIncentive.Incentive_Program_ID__c) {
        incentive.addError('Attempt to change Incentive_Program_ID__c from ' + oldIncentive.Incentive_Program_ID__c + ' to ' + incentive.Incentive_Program_ID__c);
      }
      if (oldIncentive.Visits__c != null && oldIncentive.Visits__c > incentive.Visits__c) {
        incentive.addError('Attempt to decrement number of incentive visits from ' + oldIncentive.Visits__c + ' to ' + incentive.Visits__c);
      }
    }
  }

  public static void beforeUpdate(Map<Id, Incentive__c> oldMap, List<Incentive__c> newList) {
    validateIncentives(oldMap, newList);
  }
}