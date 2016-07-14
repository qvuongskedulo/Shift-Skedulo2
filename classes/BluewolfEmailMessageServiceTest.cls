@isTest
private class BluewolfEmailMessageServiceTest {

    static final Integer TEST_SIZE = 10;
    
    static testMethod void testChangeCaseStatus(){
        final String INIT_STATUS = 'INIT';
        final String FINAL_STATUS = 'FINAL';
        
        List<Case> testCases = new BluewolfSObjectBuilder(Case.SobjectType)
                                   .put(Case.Status, INIT_STATUS)
                                   .put(Case.Case_Type__c, INIT_STATUS)
                                   .count(TEST_SIZE).build().getRecords();
                                   
        Test.startTest();
            BluewolfEmailMessageService.changeCaseStatus(testCases, FINAL_STATUS);
        Test.stopTest();
        
        system.assertEquals(testCases.size(), TEST_SIZE, 'the case size should not be changed');
        for(Case aCase: testCases){
            system.assertEquals(aCase.Status, FINAL_STATUS, 'the case status should be changed');
        }
    }
    
    static testMethod void testGetEmailToCaseMap(){
                                            
        BluewolfEmailMessageService.bypassTrigger = true;
        
        List<Case> testCases = new BluewolfSObjectBuilder(Case.SobjectType).count(TEST_SIZE).create().getRecords();
        
        List<EmailMessage> testEmails = new BluewolfSObjectBuilder(EmailMessage.SobjectType)
                                            .put(EmailMessage.ParentId, BluewolfFieldProviderFactory.provideList(BluewolfPluck.ids(testCases)))
                                            .count(TEST_SIZE).create().getRecords();
                                            
        BluewolfEmailMessageService.bypassTrigger = false;
                                            
        Test.startTest();
            Map<Id, Case> result = BluewolfEmailMessageService.getEmailToCaseMap(testEmails);
        Test.stopTest();
        
        system.assertEquals(result.size(), TEST_SIZE, 'the map size should be correct');
        
        for(Id emailId: result.keySet()){
            for(EmailMessage email: testEmails){
                if(email.Id == emailId){
                    system.assertEquals(email.ParentId, result.get(emailId).Id, 'the map should be populated correctly');
                    break;
                }
            }
        }
    }
    
    static testMethod void testGetRelatedCases(){
        
        BluewolfEmailMessageService.bypassTrigger = true;
        
        List<Case> testCases = new BluewolfSObjectBuilder(Case.SobjectType).count(TEST_SIZE * 2).create().getRecords();
        
        
        List<EmailMessage> testEmails = new BluewolfSObjectBuilder(EmailMessage.SobjectType)
                                            .put(EmailMessage.ParentId, BluewolfFieldProviderFactory.provideList(BluewolfPluck.ids(testCases)))
                                            .count(TEST_SIZE * 2).build().getRecords();
        
        List<EmailMessage> outgoingEmails = new List<EmailMessage>();
        List<EmailMessage> incomingEmails = new List<EmailMessage>();
        Set<Id> outgoingCaseIds = new Set<Id>();
        Set<Id> incomingCaseIds = new Set<Id>();
        
        for(Integer i = 0; i < TEST_SIZE; i++){
            testEmails[i].Incoming = false;
            outgoingEmails.add(testEmails[i]);
            outgoingCaseIds.add(testEmails[i].ParentId);
        }
        
        for(Integer i = TEST_SIZE; i < TEST_SIZE * 2; i++){
            testEmails[i].Incoming = true;
            incomingEmails.add(testEmails[i]);
            incomingCaseIds.add(testEmails[i].ParentId);
        }
                                          
        insert testEmails;
        
        BluewolfEmailMessageService.bypassTrigger = false;
        
        Map<Id, Case> emailToCaseMap = BluewolfEmailMessageService.getEmailToCaseMap(testEmails);
        
        Test.startTest();
            List<Case> incomingCases = BluewolfEmailMessageService.getRelatedCases(emailToCaseMap, incomingEmails);
            List<Case> outgoingCases = BluewolfEmailMessageService.getRelatedCases(emailToCaseMap, outgoingEmails);
        Test.stopTest();
        
        system.assertEquals(incomingCases.size(), TEST_SIZE, 'the size should be correct');
        for(Case aCase: incomingCases){
            system.assert(incomingCaseIds.contains(aCase.Id), 'the incoming related case should populated correctly');
        }
        system.assertEquals(outgoingCases.size(), TEST_SIZE, 'the size should be correct');
        for(Case aCase: outgoingCases){
            system.assert(outgoingCaseIds.contains(aCase.Id), 'the outgoing related case should populated correctly');
        }
    }
    
    static testMethod void testAfterInsert(){
        BluewolfEmailMessageService.bypassTrigger = true;
        
        List<Case> testCases = new BluewolfSObjectBuilder(Case.SobjectType).count(TEST_SIZE * 2).create().getRecords();
        
        
        List<EmailMessage> testEmails = new BluewolfSObjectBuilder(EmailMessage.SobjectType)
                                            .put(EmailMessage.ParentId, BluewolfFieldProviderFactory.provideList(BluewolfPluck.ids(testCases)))
                                            .count(TEST_SIZE * 2).build().getRecords();
        
        Set<Id> outgoingCaseIds = new Set<Id>();
        Set<Id> incomingCaseIds = new Set<Id>();
        
        for(Integer i = 0; i < TEST_SIZE; i++){
            testEmails[i].Incoming = false;
            outgoingCaseIds.add(testEmails[i].ParentId);
        }
        
        for(Integer i = TEST_SIZE; i < TEST_SIZE * 2; i++){
            testEmails[i].Incoming = true;
            incomingCaseIds.add(testEmails[i].ParentId);
        }
                                          
        insert testEmails;
        
        BluewolfEmailMessageService.bypassTrigger = false;
        
        Test.startTest();
            BluewolfEmailMessageService.afterInsert(testEmails);
        Test.stopTest();
        
        List<Case> actual = [SELECT Status FROM Case];
        
        system.assertEquals(actual.size(), TEST_SIZE * 2, 'the size should be equal');
        
        for(Case aCase: actual){
            if(aCase.Status == BluewolfEmailMessageService.INCOMING_STATUS){
                system.assert(incomingCaseIds.contains(aCase.Id), 'the incoming related case should populated correctly');
            }
            else if(aCase.Status == BluewolfEmailMessageService.OUTGOING_STATUS){
                system.assert(outgoingCaseIds.contains(aCase.Id), 'the outgoing related case should populated correctly');
            }
            else{
                system.assert(false, 'there is an error in function, returned invalid case');
            }
        }
    }
}