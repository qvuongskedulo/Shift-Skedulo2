global class skedGoogleSyncBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {

    global skedGoogleSyncBatch() {
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        integer timeInFuture = 60;
        
        List<string> fields = new List<string>();
        List<string> conditions = new List<string>();
        
        fields.add('Event_Id__c');
        fields.add('Summary__c');
        fields.add('Description__c');
        fields.add('Location__c');
        fields.add('Start__c');
        fields.add('Finish__c');
        fields.add('Notes__c');
        fields.add('Action__c');
        fields.add('Status__c');
        fields.add('Related_Object_Id__c');
        fields.add('Related_Object_Type__c');
        fields.add('Related_Job__r.Name');
        fields.add('Resource__c');
        fields.add('Resource__r.Name');
        fields.add('Resource__r.Google_Access_Token__c');
        fields.add('Resource__r.Google_Calendar_Id__c');
        fields.add('Resource__r.Google_Refresh_Token__c');
        fields.add('Resource__r.Google_Token_Expire_On__c');
        
        conditions.add('Status__c =\'Queued\'');
        
        string queryString = 'SELECT ' + string.join(fields, ',') + ' FROM sked_Google_Event__c WHERE ' +  string.join(conditions, ' AND ');
        return Database.getQueryLocator(queryString);
    }
    
    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        list<sked_Google_Event__c> skedGoogleEvents = (list<sked_Google_Event__c>)scope;
        List<skedGoogleData.CalloutResult> resultList = new List<skedGoogleData.CalloutResult>();
        List<sObject> rootRecords = new List<sObject>();
        
        for (sked_Google_Event__c skedGoogleEvent : skedGoogleEvents) {
            if (skedGoogleEvent.Resource__c == NULL || string.isBlank(skedGoogleEvent.Resource__r.Google_Calendar_Id__c)) {
                skedGoogleEvent.Status__c = 'Synced but error';
                skedGoogleEvent.Notes__c = 'Missing resource or resource\'google calendar Id';
                continue;
            }
            
            skedGoogleData.Item googleEvent = skedGoogleCalendarCallouts.createGoogleEventModel(skedGoogleEvent);
            skedGoogleData.CalloutResult result;
            if (skedGoogleEvent.Action__c == 'Create') {
                result = skedGoogleCalendarCallouts.createEvent(googleEvent, skedGoogleEvent.Resource__r);
            }
            else if (skedGoogleEvent.Action__c == 'Update') {
                result = skedGoogleCalendarCallouts.updateEvent(googleEvent, skedGoogleEvent.Resource__r);
            }
            else if (skedGoogleEvent.Action__c == 'Delete') {
                result = skedGoogleCalendarCallouts.deleteEvent(googleEvent, skedGoogleEvent.Resource__r);
            }
            if (result != NULL) {
                if (result.HasError) {
                    skedGoogleEvent.Status__c = 'Synced but error';
                    skedGoogleEvent.Notes__c = result.ErrorMessage;
                }
                else {
                    skedGoogleEvent.Status__c = 'Synced';
                    if (skedGoogleEvent.Action__c == 'Create') {
                        skedGoogleEvent.Event_Id__c = result.GoogleEvent.id;
                        sObject sObj = Schema.getGlobalDescribe().get(skedGoogleEvent.Related_Object_Type__c).newSObject();
                        sObj.put('Id', skedGoogleEvent.Related_Object_Id__c);
                        sObj.put('Google_Event_Id__c', result.GoogleEvent.id);
                        rootRecords.add(sObj);
                    }
                }
                resultList.add(result);
            }
        }
        update skedGoogleEvents;
        if (rootRecords.size() > 0) {
            update rootRecords;
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        
    }
    
}