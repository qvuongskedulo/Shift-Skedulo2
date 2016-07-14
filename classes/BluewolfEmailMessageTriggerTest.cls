@isTest
private class BluewolfEmailMessageTriggerTest {
    static final Integer TEST_SIZE = Limits.getLimitQueries() / 2;
    
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
        
        BluewolfEmailMessageService.bypassTrigger = false;
                                          
        Test.startTest();
            insert testEmails;
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