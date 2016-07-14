@isTest
private class skedGoogleCalendarCallouts_Test {

    @isTest static void Test() {
        /*Initialize Data*/
        sked_Google_Api_Settings__c googleSetting = new sked_Google_Api_Settings__c(Name = 'Test Google Setting');
        googleSetting.Server_Key__c = 'serverkey';
        googleSetting.Client_Id__c = 'clientid';
        googleSetting.Client_Secret__c = 'clientsecret';
        insert googleSetting;
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact doctor1 = new Contact(LastName = 'Doctor1', AccountId = acc.Id);
        insert doctor1;
        
        sked__Region__c region = new sked__Region__c(Name = 'Lower Manhattan', sked__Timezone__c = 'America/New_York');
        insert region;
        
        sked__Resource__c resource = new sked__Resource__c(Name = 'Test Resource', sked__User__c = UserInfo.getUserId(), Google_Calendar_Id__c = 'calendarId',
                                                           Google_Refresh_Token__c = 'refreshToken', Google_Access_Token__c = 'accessToken', 
                                                           Google_Token_Expire_On__c = system.now().addHours(1));
        insert resource;
        
        sked__Job__C job1 = new sked__Job__C(sked__Account__c = acc.Id, sked__Contact__c = doctor1.Id, sked__Start__c = system.now().addDays(6), 
                                             sked__Finish__c = system.now().addDays(6).addMinutes(60), sked__duration__c = 60, 
                                             sked__Region__c = region.Id, sked__Address__c = '58 Ludlow Street, New York, 10002');
        insert job1;
        
        sked__job_allocation__c job1allocation1 = new sked__job_allocation__c(sked__job__c = job1.Id, sked__resource__c = resource.Id);
        insert job1allocation1;
        
        /*End - Initialize Data*/
        
        Test.startTest();
        
        skedGoogleCalendarCallouts_MockTest mockClass = new skedGoogleCalendarCallouts_MockTest();
        Test.setMock(HttpCalloutMock.class, mockClass);
        
        
        mockClass.calloutMethod = 'createEvent';
        skedGoogleCalendarCallouts.createEvent(job1.Id, resource.Id);
        mockClass.calloutMethod = 'updateEvent';
        skedGoogleCalendarCallouts.updateEvent(job1.Id, resource.Id);
        mockClass.calloutMethod = 'deleteEvent';
        skedGoogleCalendarCallouts.deleteEvent(job1.Id, resource.Id);
       
        mockClass.calloutMethod = 'createEvent_Error';
        skedGoogleCalendarCallouts.createEvent(job1.Id, resource.Id);
        mockClass.calloutMethod = 'updateEvent_Error';
        skedGoogleCalendarCallouts.updateEvent(job1.Id, resource.Id);
        mockClass.calloutMethod = 'deleteEvent_Error';
        skedGoogleCalendarCallouts.deleteEvent(job1.Id, resource.Id);
        
        mockClass.calloutMethod = 'getCalendar';
        skedGoogleCalendarCallouts.getCalendar(resource.Google_Calendar_Id__c, system.now(), system.now().addDays(7));
        
        mockClass.calloutMethod = 'getCalendarList';
        skedGoogleCalendarCallouts.getCalendarList(resource.Id);
        
        mockClass.calloutMethod = 'refreshToken';
        skedGoogleData.CalloutResult result = skedGoogleCalendarCallouts.refreshToken(resource);
        system.debug('#result Token#' + result);
        
        List<skedGoogleData.CalloutResult> resultList = new List<skedGoogleData.CalloutResult>();
        resultList.add(result);
        skedGoogleCalendarCallouts.UpdateTokenIfExpired(resultList);
        
        Test.stopTest();
    }
    
}