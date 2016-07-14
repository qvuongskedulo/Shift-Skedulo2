trigger ShiftOpportunityReferrerAnalyticsInsertUpdate on Opportunity (before insert, before update) {
    Map<Id, Opportunity> raToOpportunity = new Map<Id, Opportunity>();
    for (Opportunity opp : Trigger.new) {
        if (opp.Referrer_Analytics_ID__c != null) {
            raToOpportunity.put(opp.Referrer_Analytics_ID__c, opp);
        }
    }

    // Set promotion on opportunity for Uber referrals.
    List<Referrer_Analytics__c> ras = [
            SELECT Id, UTM_Campaign__c, UTM_Source__c FROM Referrer_Analytics__c
            WHERE Id IN :raToOpportunity.keySet()
    ];
    for (Referrer_Analytics__c ra : ras) {
        if (ra.UTM_Campaign__c == ShiftConstants.UTM_CODE_UBER_DEC_LA || ra.UTM_Source__c == ShiftConstants.UTM_CODE_UBER_DEC_LA) {
            raToOpportunity.get(ra.Id).Referral_Program_Or_Promotion__c =
                    ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_UBER_LA_2015;
        }
        if (ra.UTM_Campaign__c == ShiftConstants.UTM_CODE_UBER_DRIVERS_SOCAL_2016 || ra.UTM_Source__c == ShiftConstants.UTM_CODE_UBER_DRIVERS_SOCAL_2016) {
            raToOpportunity.get(ra.Id).Referral_Program_Or_Promotion__c =
                    ShiftConstants.REFERRAL_PROGRAM_OR_PROMOTION_UBER_DRIVERS_SOCAL_2016;
        }
    }
}