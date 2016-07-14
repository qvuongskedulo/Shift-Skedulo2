@isTest
public class skedGoogleAuth_Test {
	
    static testmethod void testGoogleAuth() {
        sked__Resource__c skedResource1 = new sked__Resource__c(
        	Name = 'Skedulo Team',
            sked__User__c = UserInfo.getUserId(),
            sked__Email__c = 'testResource@email.com'
        );
        insert skedResource1;
        
        Test.setCurrentPageReference(new PageReference('skedGoogleAuth'));
        
        Test.startTest();
        
        skedGoogleAuth_MockTest mockClass = new skedGoogleAuth_MockTest();
        Test.setMock(HttpCalloutMock.class, mockClass);
        
        skedGoogleAuthController googleAuthCon = new skedGoogleAuthController();
        googleAuthCon.Cmd_ConnectToGoogle();
        
        System.currentPageReference().getParameters().put('mode', 'token');
        System.currentPageReference().getParameters().put('code', 'googleAuthCode');
        mockClass.calloutMethod = 'Cmd_GetTokens';
        googleAuthCon.Cmd_GetTokens();
        
        System.currentPageReference().getParameters().put('mode', null);
        System.currentPageReference().getParameters().put('code', null);
        googleAuthCon.Cmd_GetTokens();
        
        googleAuthCon.Cmd_SaveCalendar();
        
        googleAuthCon.Cmd_Revoke();
        
        Test.stopTest();
    }
    
}