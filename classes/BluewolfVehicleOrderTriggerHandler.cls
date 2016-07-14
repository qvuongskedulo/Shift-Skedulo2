public with sharing class BluewolfVehicleOrderTriggerHandler{
    private final List<Vehicle_Order__c> vehicleOrders;
    private final Map<Id, Vehicle_Order__c> oldMap;
    @TestVisible
    private static Boolean bypassTrigger = false;

    public BluewolfVehicleOrderTriggerHandler(List<Vehicle_Order__c> vehicleOrders, Map<Id, Vehicle_Order__c> oldMap) {
        this.vehicleOrders= vehicleOrders;
        this.oldMap = oldMap;
    }

    public void afterUpdate() {
        if(bypassTrigger) return;
        BluewolfTestDriveRequestServices.requestDriveIfSoldOrReturned(vehicleOrders, oldMap);
    }
    
    public void afterInsert(){
        if(bypassTrigger) return;
        BluewolfTestDriveRequestServices.requestDriveIfSoldOrReturned(vehicleOrders);
    }
}