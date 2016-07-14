@isTest
public class skedSkeduloApiManager_Test {
	
    static testmethod void testSkeduloApi() {
        Skedulo_API_Setting__c skeduloApiSetting = Skedulo_API_Setting__c.getOrgDefaults();
        skeduloApiSetting.API_Token__c = 'apiToken';
        upsert skeduloApiSetting;
        
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '158 Ludlow Street, New York, NY 10002',
            BillingPostalCode = '10002'
        );
        insert acc;
        
        Contact con = new Contact(
            LastName = 'Last',
            AccountId = acc.Id,
            MailingStreet = '158 Ludlow Street, New York, NY 10002',
            MailingPostalCode = '10002'
        );        
        insert con;
        
        sked__Region__c region = new sked__Region__c(Name = 'Lower Manhattan', sked__Timezone__c = 'America/New_York');
        insert region;
        
        sked__Resource__c resource = new sked__Resource__c(Name = 'Test Resource', sked__User__c = UserInfo.getUserId());
        insert resource;
        
        sked__Job__C job1 = new sked__Job__C(sked__Account__c = acc.Id, sked__Contact__c = con.Id, sked__Start__c = system.now().addDays(6), 
                                             sked__Finish__c = system.now().addDays(6).addMinutes(60), sked__duration__c = 60, 
                                             sked__Region__c = region.Id, sked__Address__c = '58 Ludlow Street, New York, 10002');
        insert job1;
        
        sked__job_allocation__c job1allocation1 = new sked__job_allocation__c(sked__job__c = job1.Id, sked__resource__c = resource.Id);
        insert job1allocation1;
        
        Test.startTest();
        
        skedSkeduloApiManager_MockTest mockClass = new skedSkeduloApiManager_MockTest();
        mockClass.resourceId = resource.Id;
        Test.setMock(HttpCalloutMock.class, mockClass);
        
        mockClass.calloutMethod = 'dispatch';
        skedSkeduloApiManager.sendDispatchNotification('', resource.Id);
        skedSkeduloApiManager.sendDispatchNotification(job1.Id, resource.Id);
        
        mockClass.calloutMethod = 'dispatch_error';
        skedSkeduloApiManager.sendDispatchNotification(job1.Id, resource.Id);
        
        Test.stopTest();
    }
    
}