public without sharing class BluewolfRequestContExt{
    @TestVisible
    private static final String PICKUP_REQUEST_TYPE = 'Temporary Return';
    @TestVisible
    private static final String RETURN_REQUEST_TYPE = 'Permanent Return';
    @TestVisible
    private static final User ASSIGNED_USER = [SELECT Id FROM User WHERE Shift_Key__c = 'unowned'];
    
    public Vehicle_Order__c vehicleOrder {get; set;}
    private Contact contact {get; set;}
    
    public BluewolfRequestContExt(ApexPages.StandardController ctrl){
        vehicleOrder = [SELECT Buyer_Opportunity_ID__c, Buyer_Opportunity_ID__r.AccountId, Returned_Notes__c FROM Vehicle_Order__c WHERE Id =: ctrl.getRecord().Id];
        contact = [SELECT Id FROM Contact WHERE AccountId = :vehicleOrder.Buyer_Opportunity_ID__r.AccountId LIMIT 1];
    }
    
    public PageReference createPickupRequest(){
        return createNewCase(PICKUP_REQUEST_TYPE);
    }
    
    public PageReference createReturnRequest(){
        return createNewCase(RETURN_REQUEST_TYPE );
    }
    
    @TestVisible
    private PageReference createNewCase(String type){
        if(ASSIGNED_USER == null){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Unowned User not existed, please contact System Administrator'));
        }
        Case newCase = new Case(
                                 Opportunity_ID__c = vehicleOrder.Buyer_Opportunity_ID__c,
                                 Case_Type__c = type,
                                 Description = 'Returned Notes: ' + vehicleOrder.Returned_Notes__c,
                                 OwnerId = ASSIGNED_USER.Id,
                                 contactId = contact.Id
                               );
        
        try{
            insert newCase;
        }
        catch(DMLException ex){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, ex.getStackTraceString()));
        }
        
        PageReference oldPage = new ApexPages.StandardController(vehicleOrder).view();
        oldPage.setRedirect(true);
        return oldPage;

    }
}