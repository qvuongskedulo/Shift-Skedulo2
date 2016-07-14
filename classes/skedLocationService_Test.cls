@isTest
public class skedLocationService_Test {

    static testmethod void testLocationService() {
        Skedulo_API_Setting__c skeduloApiSetting = Skedulo_API_Setting__c.getOrgDefaults();
        skeduloApiSetting.API_Token__c = 'apiToken';
        upsert skeduloApiSetting;
        
        Test.startTest();
        
        skedLocationService_MockTest mockClass = new skedLocationService_MockTest();
        Test.setMock(HttpCalloutMock.class, mockClass);
        
        skedLocationService.getAddressGeoLocation('test address');
        
        Test.stopTest();
    }
    
}