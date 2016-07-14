global class skedGoogleEventCleanupBatch implements Database.Batchable<sObject> {

    global skedGoogleEventCleanupBatch() {
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        List<string> fields = new List<string>();
        List<string> conditions = new List<string>();
        
        integer keepDataDuration = 30;
        sked_Google_Api_Settings__c settings = sked_Google_Api_Settings__c.getOrgDefaults();
        if (settings.Keep_Data_Duration__c != NULL) {
            keepDataDuration = integer.valueOf(settings.Keep_Data_Duration__c);
        }
        DateTime timeToDelete = system.now().addDays(-1 * keepDataDuration);
        
        fields.add('Id');
        
        conditions.add('Status__c !=\'Queued\'');
        conditions.add('CreatedDate < :timeToDelete');
        
        string queryString = 'SELECT ' + string.join(fields, ',') + ' FROM sked_Google_Event__c WHERE ' +  string.join(conditions, ' AND ');
        return Database.getQueryLocator(queryString);
    }
    
    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        list<sked_Google_Event__c> skedGoogleEvents = (list<sked_Google_Event__c>)scope;
        delete skedGoogleEvents;
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
    
}