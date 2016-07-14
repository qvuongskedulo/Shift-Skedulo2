@isTest
private class BluewolfDefaultEmailActionTest {
    static testMethod void onInitDefaults_noSellerOpportunity() {
        Case aCase = (Case) new BluewolfSObjectBuilder(Case.SobjectType).create().getRecord();
        String defaultsAsJSON = '[{"targetSObject":{"attributes":{"type":"EmailMessage"},"TextBody":"",'
        + '"FromName":"Test","FromAddress":"test@example.com","HtmlBody":"<html><body></body></html>","BccAddress":"test@example.com",'
        + '"CcAddress":"","ToAddress":"test@example.com","Subject":"Testing"},"contextId": "' + String.valueOf(aCase.Id) + '","actionType":"Email",'
        + '"actionName":"Case.Email","fromAddressList":["salesforce@test.com"]}]';
        List<QuickAction.SendEmailQuickActionDefaults> defaultsSettings =
            (List<QuickAction.SendEmailQuickActionDefaults>)JSON.deserialize(defaultsAsJSON, List<QuickAction.SendEmailQuickActionDefaults>.class);

        Test.startTest();
            new BluewolfDefaultEmailAction().onInitDefaults(defaultsSettings);
        Test.stopTest();

        EmailMessage actualEmail = (EmailMessage)defaultsSettings[0].getTargetSObject();
        system.assertEquals(Label.Case_From_Email, actualEmail.FromAddress, 'the from address should be set');
    }
    
    static testMethod void onInitDefaults_sellerOpportunity(){
        Id recordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Seller'].Id;
        Vehicle__c veh = (Vehicle__c) new BluewolfSObjectBuilder(Vehicle__c.SobjectType).create().getRecord();
        Opportunity opp = (Opportunity) new BluewolfSObjectBuilder(Opportunity.SobjectType)
                                                    .put(Opportunity.RecordTypeId, recordTypeId)
                                                    .put(Opportunity.Vehicle_Id__c, veh.Id)
                                                    .create().getRecord();
        
        Case aCase = (Case) new BluewolfSObjectBuilder(Case.SobjectType)
                                .put(Case.Opportunity_Id__c, opp.Id).create().getRecord();
                                
        String defaultsAsJSON = '[{"targetSObject":{"attributes":{"type":"EmailMessage"},"TextBody":"",'
        + '"FromName":"Test","FromAddress":"test@example.com","HtmlBody":"<html><body></body></html>","BccAddress":"test@example.com",'
        + '"CcAddress":"","ToAddress":"test@example.com","Subject":"Testing"},"contextId": "' + String.valueOf(aCase.Id) + '","actionType":"Email",'
        + '"actionName":"Case.Email","fromAddressList":["salesforce@test.com"]}]';
        List<QuickAction.SendEmailQuickActionDefaults> defaultsSettings =
            (List<QuickAction.SendEmailQuickActionDefaults>)JSON.deserialize(defaultsAsJSON, List<QuickAction.SendEmailQuickActionDefaults>.class);

        Test.startTest();
            new BluewolfDefaultEmailAction().onInitDefaults(defaultsSettings);
        Test.stopTest();

        EmailMessage actualEmail = (EmailMessage)defaultsSettings[0].getTargetSObject();
        system.assertEquals(Label.Seller_Case_Email, actualEmail.FromAddress, 'the from address should be set');                                          
    }
}