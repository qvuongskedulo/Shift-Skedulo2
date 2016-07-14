@isTest
private class BluewolfOpportunityServiceTest {
    static final Integer TEST_NUM = /*Limits.getLimitQueries() + */1;
    
    static testMethod void testBeforeUpdate(){
        BluewolfOpportunityTriggerHandler.bypassTrigger = true;
        BluewolfVehicleTriggerHandler.bypassTrigger = true;
        List<Vehicle__c> testVehicles = new BluewolfSObjectBuilder(Vehicle__c.sObjectType)
            .put(Vehicle__c.Needs_Repairs__c, false)
            .put(Vehicle__c.In_Transit__c, false)
            .put(Vehicle__c.Paperwork_Missing__c, 'Yes - Vehicle Available')
            .put(Vehicle__c.Photos_Ready__c, true)
            .count(TEST_NUM).create().getRecords();

        List<Opportunity> testOpportunities = new BluewolfSObjectBuilder(Opportunity.sObjectType)
            .put(Opportunity.RecordTypeId, BluewolfOpportunityService.SELLER_OPP_ID)
            .put(Opportunity.Vehicle_Id__c, BluewolfFieldProviderFactory.provideList(Pluck.ids(testVehicles)))
            .put(Opportunity.StageName, 'Leads')
            .count(TEST_NUM).create().getRecords();
       
        Map<Id, Opportunity> oldOpp = new Map<Id, Opportunity>(testOpportunities.deepClone(true/*preserve Ids*/));

        for (Opportunity opp : testOpportunities) {
            opp.StageName = BluewolfOpportunityService.AVAILABLE_STAGE;
        }
        User testUser = (User)BluewolfSObjectFactory.create(User.sObjectType);
        BluewolfOpportunityService.caseOwnerId = testUser.Id;
        BluewolfVehicleTriggerHandler.bypassTrigger = false;
         BluewolfOpportunityTriggerHandler.bypassTrigger = false;
        Test.startTest();
            BluewolfOpportunityService.beforeUpdate(testOpportunities, oldOpp);
        Test.stopTest();
    }
    
        static testMethod void testCreateCases(){
        
        BluewolfOpportunityTriggerHandler.bypassTrigger = true;
        
        List<Opportunity> opps = new SObjectBuilder(Opportunity.SObjectType)
                                        .count(TEST_NUM).build().getRecords();
                                        
        BluewolfOpportunityTriggerHandler.bypassTrigger = false;
        
        Test.startTest();
            BluewolfOpportunityService.createCases(opps);
        Test.stopTest();
        
        List<Case> actual = [SELECT Case_Type__c, AccountId, OwnerId FROM Case];
        system.assertEquals(actual.size(), TEST_NUM, 'the size should be equal');
        
        for(Case aCase: actual){
            system.assertEquals(aCase.Case_Type__c, BluewolfOpportunityService.CASE_TYPE, 'the case type should be equal');
        }
    }
    
    static testMethod void testAfterInsert(){
        
        BluewolfOpportunityTriggerHandler.bypassTrigger = true;
        
        
        List<Opportunity> opps = new SObjectBuilder(Opportunity.SObjectType)
                                        .put(Opportunity.RecordTypeId, BluewolfOpportunityService.SELLER_OPP_ID)
                                        .put(Opportunity.StageName, 'Leads')
                                        .count(TEST_NUM).build().getRecords();
                                        
        BluewolfOpportunityTriggerHandler.bypassTrigger = false;
        
        Test.startTest();
            BluewolfOpportunityService.afterInsert(opps);
        Test.stopTest();
        
        List<Case> actual = [SELECT Case_Type__c, AccountId, OwnerId FROM Case];
        system.assertEquals(actual.size(), TEST_NUM, 'the size should be equal');
        
        for(Case aCase: actual){
            system.assertEquals(aCase.Case_Type__c, BluewolfOpportunityService.CASE_TYPE, 'the case type should be equal');
        }
    }
}