trigger ShiftStageChangeEntry on Opportunity (before insert, before update) {
    Map<String, Schema.SObjectField> fldMap = new Map<String, Schema.SObjectField>{
        'Evaluate and Pickup' => Schema.Opportunity.Entered_Stage_Evaluate_And_Pickup__c,
        'Handover' => Schema.Opportunity.Entered_Stage_Handover__c,
        'Leads' => Schema.Opportunity.Entered_Stage_Leads__c,
        'Lost' => Schema.Opportunity.Entered_Stage_Lost__c,
        'Prepare Car for Sale' => Schema.Opportunity.Entered_Stage_Prepare_Car_For_Sale__c,
        'Quote and Schedule' => Schema.Opportunity.Entered_Stage_Quote_And_Schedule__c,
        'Sell Car' => Schema.Opportunity.Entered_Stage_Sell_Car__c,
        'Sold' => Schema.Opportunity.Entered_Stage_Sold__c
    };
    for (Opportunity opp : Trigger.new) {
        String stage = opp.StageName;
        Schema.SObjectField dstFld = fldMap.get(stage);
        if (dstFld == null) {
            continue;
        }
        if (opp.get(dstFld) != null) {
            continue;
        }
        opp.put(dstFld, Datetime.now());
    }
}