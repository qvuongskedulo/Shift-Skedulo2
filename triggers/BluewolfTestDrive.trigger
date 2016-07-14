trigger BluewolfTestDrive on Test_Drive__c (after update) {
    BluewolfTestDriveTriggerHandler handler = new BluewolfTestDriveTriggerHandler(Trigger.new, Trigger.oldMap);

    if (Trigger.isBefore) {

    } else {
        if (Trigger.isUpdate) handler.afterUpdate();
    }
}