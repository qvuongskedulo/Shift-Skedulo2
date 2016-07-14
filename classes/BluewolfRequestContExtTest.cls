@isTest
private class BluewolfRequestContExtTest {
    
    private static Id buyerOppId = [SELECT Id FROM RecordType WHERE DeveloperName = 'Buyer' AND SobjectType = 'Opportunity' LIMIT 1].Id;
    
    static Vehicle_Order__c setupVehicleOrder(String notes){
        BluewolfVehicleTriggerHandler.bypassTrigger = true;
        Region__c region = (Region__c) new BluewolfSObjectBuilder(Region__c.SobjectType).put(Region__c.Timezone__c, 'GMT 8').create().getRecord();
        Vehicle__c vehicle = (Vehicle__c) new BluewolfSObjectBuilder(Vehicle__c.SobjectType).put(Vehicle__c.Listing_Region_ID__c, region.Id).create().getRecord();
        Account acc = (Account) new BluewolfSObjectBuilder(Account.SobjectType).create().getRecord();
        Contact con = (Contact) new BluewolfSObjectBuilder(Contact.SobjectType).put(Contact.AccountId, acc.Id)
                                                                       .put(Contact.LastName, 'Test Name')
                                                                       .create().getRecord();
        Opportunity opp = (Opportunity) new BluewolfSObjectBuilder(Opportunity.SobjectType).put(Opportunity.AccountId, acc.Id).put(Opportunity.RecordTypeId, buyerOppId).create().getRecord(); 
        return (Vehicle_Order__c) new BluewolfSObjectBuilder(Vehicle_Order__c.SobjectType).put(Vehicle_Order__c.Buyer_Opportunity_ID__c, opp.Id)
                                                                                  .put(Vehicle_Order__c.Returned_Notes__c, notes)
                                                                                  .create().getRecord();                                                                         
    }
    
    static testMethod void testConstructor(){
        final String TEST_NOTES = 'some notes';
        BluewolfVehicleOrderTriggerHandler.bypassTrigger = true;
        Vehicle_Order__c vehicleOrder = setupVehicleOrder(TEST_NOTES);
         BluewolfVehicleOrderTriggerHandler.bypassTrigger = false;
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(vehicleOrder);
        
        Test.startTest();
            BluewolfRequestContExt ext = new BluewolfRequestContExt(stdCtrl);
        Test.stopTest();
        
        system.assertNotEquals(ext.vehicleOrder, null, 'the vehicle order should not be null');
        system.assertEquals(ext.vehicleOrder.Returned_Notes__c, TEST_NOTES, 'the notes should be equal');
    }
    
    static testMethod void testCreateNewCase(){
        final String TEST_NOTES = 'a note';
        final String TEST_TYPES = 'some type';
        BluewolfVehicleOrderTriggerHandler.bypassTrigger = true;
        Vehicle_Order__c vehicleOrder = setupVehicleOrder(TEST_NOTES);
        BluewolfVehicleOrderTriggerHandler.bypassTrigger = false;
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(vehicleOrder);
        BluewolfRequestContExt ext = new BluewolfRequestContExt(stdCtrl);
        
        Test.startTest();
            PageReference ref = ext.createNewCase(TEST_TYPES);
        Test.stopTest();
        
        system.assertNotEquals(ref, null, 'the page reference should not be null');
        system.assert(!ApexPages.hasMessages(),'the page should not show any errors');
        
        Case actual = [SELECT Vehicle_Order__c, Case_Type__c, OwnerId FROM Case LIMIT 1];
        
        system.assertNotEquals(actual, null, 'the case should not be null');
        system.assertEquals(actual.Case_Type__c, TEST_TYPES, 'the type should be set correctly');
        system.assertEquals(actual.OwnerId, BluewolfRequestContExt.ASSIGNED_USER.Id, 'the owner should be set correctly');
    }
    
    static testMethod void testCreatePickupRequest(){
        final String TEST_NOTES = 'a note';
         BluewolfVehicleOrderTriggerHandler.bypassTrigger = true;
        Vehicle_Order__c vehicleOrder = setupVehicleOrder(TEST_NOTES);
         BluewolfVehicleOrderTriggerHandler.bypassTrigger = false;
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(vehicleOrder);
        BluewolfRequestContExt ext = new BluewolfRequestContExt(stdCtrl);
        
        Test.startTest();
            PageReference ref = ext.createPickupRequest();
        Test.stopTest();
        
        system.assertNotEquals(ref, null, 'the page reference should not be null');
        system.assert(!ApexPages.hasMessages(),'the page should not show any errors');
        
        Case actual = [SELECT Vehicle_Order__c, Case_Type__c, OwnerId FROM Case LIMIT 1];
        
        system.assertNotEquals(actual, null, 'the case should not be null');
        system.assertEquals(actual.Case_Type__c, BluewolfRequestContExt.PICKUP_REQUEST_TYPE, 'the type should be set correctly');
        system.assertEquals(actual.OwnerId, BluewolfRequestContExt.ASSIGNED_USER.Id, 'the owner should be set correctly');
    }
    
    static testMethod void testCreateReturnRequest(){
        final String TEST_NOTES = 'a note';
        Vehicle_Order__c vehicleOrder = setupVehicleOrder(TEST_NOTES);
        ApexPages.StandardController stdCtrl = new ApexPages.StandardController(vehicleOrder);
        BluewolfRequestContExt ext = new BluewolfRequestContExt(stdCtrl);
        
        Test.startTest();
            PageReference ref = ext.createReturnRequest();
        Test.stopTest();
        
        system.assertNotEquals(ref, null, 'the page reference should not be null');
        system.assert(!ApexPages.hasMessages(),'the page should not show any errors');
        
        Case actual = [SELECT Vehicle_Order__c, Case_Type__c, OwnerId FROM Case LIMIT 1];
        
        system.assertNotEquals(actual, null, 'the case should not be null');
        system.assertEquals(actual.Case_Type__c, BluewolfRequestContExt.RETURN_REQUEST_TYPE, 'the type should be set correctly');
        system.assertEquals(actual.OwnerId, BluewolfRequestContExt.ASSIGNED_USER.Id, 'the owner should be set correctly');
    }
}