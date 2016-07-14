@isTest
private class BluewolfEvaluationServiceTest {
    
    private final static Id SELLER_OPP_ID = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Seller'].Id;
    
    static testMethod void testAfterInsert(){
        BluewolfOpportunityTriggerHandler.bypassTrigger = true;
        BluewolfEvaluationTriggerHandler.bypassTrigger = true;
        Vehicle__c vehicle = (Vehicle__c) new BluewolfSObjectBuilder(Vehicle__c.SObjectType).create().getRecord();
        Opportunity opp = (Opportunity) new BluewolfSObjectBuilder(Opportunity.SObjectType)
                                            .put(Opportunity.RecordTypeId, SELLER_OPP_ID)
                                            .put(Opportunity.Vehicle_Id__c, vehicle.Id)
                                            .create().getRecord();
        Evaluation__c testEva = (Evaluation__c) new BluewolfSObjectBuilder(Evaluation__c.SObjectType)
                                                .put(Evaluation__c.Seller_Opportunity_ID__c, opp.Id)
                                                .put(Evaluation__c.Evaluated_At__c, Datetime.now().addDays(1))
                                                .put(Evaluation__c.Canceled__c, false)
                                                .create().getRecord();
                                                
        BluewolfOpportunityTriggerHandler.bypassTrigger = false;
        BluewolfEvaluationTriggerHandler.bypassTrigger = false;
        
        Test.startTest();
            BluewolfEvaluationService.afterInsert(new List<Evaluation__c>{testEva});
        Test.stopTest();
        
        List<Case> cases = [SELECT Case_Type__c, Opportunity_ID__c FROM Case];
        
        system.assertEquals(1, cases.size(), 'the case size should be equal');
        system.assertEquals(BluewolfEvaluationService.CASE_TYPE, cases[0].Case_Type__c, 'the case size should be equal');
        system.assertEquals(opp.Id, cases[0].Opportunity_ID__c, 'the case size should be equal');
    }
    
    static testMethod void testAfterInsert_trigger(){
        BluewolfOpportunityTriggerHandler.bypassTrigger = true;
        BluewolfEvaluationTriggerHandler.bypassTrigger = true;
        Vehicle__c vehicle = (Vehicle__c) new BluewolfSObjectBuilder(Vehicle__c.SObjectType).create().getRecord();
        Opportunity opp = (Opportunity) new BluewolfSObjectBuilder(Opportunity.SObjectType)
                                            .put(Opportunity.RecordTypeId, SELLER_OPP_ID)
                                            .put(Opportunity.Vehicle_Id__c, vehicle.Id)
                                            .create().getRecord();
        Evaluation__c testEva = (Evaluation__c) new BluewolfSObjectBuilder(Evaluation__c.SObjectType)
                                                .put(Evaluation__c.Seller_Opportunity_ID__c, opp.Id)
                                                .put(Evaluation__c.Evaluated_At__c, Datetime.now().addDays(1))
                                                .put(Evaluation__c.Canceled__c, false)
                                                .build().getRecord();
                                                
        BluewolfOpportunityTriggerHandler.bypassTrigger = false;
        BluewolfEvaluationTriggerHandler.bypassTrigger = false;
        
        Test.startTest();
            insert testEva;
        Test.stopTest();
        
        List<Case> cases = [SELECT Case_Type__c, Opportunity_ID__c FROM Case];
        
        system.assertEquals(1, cases.size(), 'the case size should be equal');
        system.assertEquals(BluewolfEvaluationService.CASE_TYPE, cases[0].Case_Type__c, 'the case size should be equal');
        system.assertEquals(opp.Id, cases[0].Opportunity_ID__c, 'the case size should be equal');
    }
    
    static testMethod void testAfterUpdate(){
        BluewolfOpportunityTriggerHandler.bypassTrigger = true;
        BluewolfEvaluationTriggerHandler.bypassTrigger = true;
        Vehicle__c vehicle = (Vehicle__c) new BluewolfSObjectBuilder(Vehicle__c.SObjectType).create().getRecord();
        Opportunity opp = (Opportunity) new BluewolfSObjectBuilder(Opportunity.SObjectType)
                                            .put(Opportunity.RecordTypeId, SELLER_OPP_ID)
                                            .put(Opportunity.Vehicle_Id__c, vehicle.Id)
                                            .create().getRecord();
        Case aCase = (Case) new BluewolfSObjectBuilder(Case.SObjectType)
                                .put(Case.Opportunity_Id__c, opp.Id)
                                .create().getRecord();
        Evaluation__c testEva = (Evaluation__c) new BluewolfSObjectBuilder(Evaluation__c.SObjectType)
                                                .put(Evaluation__c.Seller_Opportunity_ID__c, opp.Id)
                                                .put(Evaluation__c.Evaluated_At__c, Datetime.now().addDays(1))
                                                .put(Evaluation__c.Canceled__c, true)
                                                .create().getRecord();
                                                
        Map<Id, Evaluation__c> oldMap = new Map<Id, Evaluation__c>{testEva.Id => testEva};
        
        Evaluation__c newEva = testEva.clone(true, true, true ,true);
        newEva.Canceled__c = false;
        BluewolfOpportunityTriggerHandler.bypassTrigger = false;
        BluewolfEvaluationTriggerHandler.bypassTrigger = false;
        
        Test.startTest();
            BluewolfEvaluationService.afterUpdate(new List<Evaluation__c>{newEva}, oldMap);
        Test.stopTest();
        
        List<Case> cases = [SELECT Case_Type__c, Opportunity_ID__c FROM Case];
        
        system.assertEquals(1, cases.size(), 'the case size should be equal');
        system.assertEquals(BluewolfEvaluationService.CASE_TYPE, cases[0].Case_Type__c, 'the case size should be equal');
        system.assertEquals(opp.Id, cases[0].Opportunity_ID__c, 'the case size should be equal');
    }
    
    static testMethod void testAfterUpdate_trigger(){
        BluewolfOpportunityTriggerHandler.bypassTrigger = true;
        BluewolfEvaluationTriggerHandler.bypassTrigger = true;
        Vehicle__c vehicle = (Vehicle__c) new BluewolfSObjectBuilder(Vehicle__c.SObjectType).create().getRecord();
        Opportunity opp = (Opportunity) new BluewolfSObjectBuilder(Opportunity.SObjectType)
                                            .put(Opportunity.RecordTypeId, SELLER_OPP_ID)
                                            .put(Opportunity.Vehicle_Id__c, vehicle.Id)
                                            .create().getRecord();
        Case aCase = (Case) new BluewolfSObjectBuilder(Case.SObjectType)
                                .put(Case.Opportunity_Id__c, opp.Id)
                                .create().getRecord();
        Evaluation__c testEva = (Evaluation__c) new BluewolfSObjectBuilder(Evaluation__c.SObjectType)
                                                .put(Evaluation__c.Seller_Opportunity_ID__c, opp.Id)
                                                .put(Evaluation__c.Evaluated_At__c, Datetime.now().addDays(1))
                                                .put(Evaluation__c.Canceled__c, true)
                                                .create().getRecord();
                                                
        Evaluation__c newEva = testEva.clone(true, true, true ,true);
        newEva.Canceled__c = false;
        BluewolfOpportunityTriggerHandler.bypassTrigger = false;
        BluewolfEvaluationTriggerHandler.bypassTrigger = false;
        
        Test.startTest();
            update newEva;
        Test.stopTest();
        
        List<Case> cases = [SELECT Case_Type__c, Opportunity_ID__c FROM Case];
        
        system.assertEquals(1, cases.size(), 'the case size should be equal');
        system.assertEquals(BluewolfEvaluationService.CASE_TYPE, cases[0].Case_Type__c, 'the case size should be equal');
        system.assertEquals(opp.Id, cases[0].Opportunity_ID__c, 'the case size should be equal');
    }
}