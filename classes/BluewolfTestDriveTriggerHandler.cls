public with sharing class BluewolfTestDriveTriggerHandler {
    private final List<Test_Drive__c> testDrives;
    private final Map<Id, Test_Drive__c> oldMap;

    public BluewolfTestDriveTriggerHandler(List<Test_Drive__c> testDrives, Map<Id, Test_Drive__c> oldMap) {
        this.testDrives = testDrives;
        this.oldMap = oldMap;
    }

    public void afterUpdate() {
        BluewolfTestDriveRequestServices.requestDriveIfCanceled(testDrives, oldMap);
    }
}