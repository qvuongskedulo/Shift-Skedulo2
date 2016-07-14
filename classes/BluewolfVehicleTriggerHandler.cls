public with sharing class BluewolfVehicleTriggerHandler {
    private final List<Vehicle__c> vehicles;
    private final Map<Id, Vehicle__c> oldMap;
    @TestVisible
    private static Boolean bypassTrigger = false;

    public BluewolfVehicleTriggerHandler(List<Vehicle__c> vehicles, Map<Id, Vehicle__c> oldMap) {
        this.vehicles = vehicles;
        this.oldMap = oldMap;
    }

    public void afterUpdate() {
        if(bypassTrigger) return;
        BluewolfTestDriveRequestServices.requestDriveIfAvailabilityChanges(vehicles, oldMap);
    }   
}