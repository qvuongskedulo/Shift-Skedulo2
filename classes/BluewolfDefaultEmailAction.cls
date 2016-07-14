global class BluewolfDefaultEmailAction implements QuickAction.QuickActionDefaultsHandler {

    @TestVisible
    static final String SELLER_OPP = 'Seller';
    static final Set<String> SELLER_EMAIL_TYPE = new Set<String>{'8x8 Voicemail', 'Tesla Email', 'General Email', 'Automated Pickup Request', 'Pricing Update', 'Response to Drip Campaign'}; 
    
    global void onInitDefaults(List<QuickAction.QuickActionDefaults> defaults) {
        QuickAction.SendEmailQuickActionDefaults sendEmailDefaults = getCaseEmailAction(defaults);

        if(sendEmailDefaults == null) return;
        EmailMessage emailMessage = (EmailMessage)sendEmailDefaults.getTargetSObject();
        
        Id caseId = (Id) sendEmailDefaults.getContextId();
        system.debug(caseId);
        Case aCase;
        if(caseId != null)
            aCase = [SELECT Case_Type__c, Opportunity_ID__c, Opportunity_Id__r.RecordType.DeveloperName FROM Case WHERE Id =:caseId];
        if(aCase != null && aCase.Opportunity_Id__r.RecordType.DeveloperName == SELLER_OPP){
            emailMessage.FromAddress = Label.Seller_Case_Email;
        }
        else if(SELLER_EMAIL_TYPE.contains(aCase.Case_Type__c)){
            emailMessage.FromAddress = Label.Seller_Case_Email;
        }
        else{
            emailMessage.FromAddress = Label.Case_From_Email;
        } 
    }

    QuickAction.SendEmailQuickActionDefaults getCaseEmailAction(List<QuickAction.QuickActionDefaults> defaults) {
        for (QuickAction.QuickActionDefaults d : defaults) {
            if(d instanceof QuickAction.SendEmailQuickActionDefaults
                && d.getTargetSObject().getSObjectType() == EmailMessage.sObjectType
                && d.getActionName().equals('Case.Email')
                && d.getActionType().equals('Email')) {

                return (QuickAction.SendEmailQuickActionDefaults)d;
            }
        }

        return null;
    }
}