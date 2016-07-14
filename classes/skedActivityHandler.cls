public class skedActivityHandler {

    public static void beforeActivitiesDelete(List<sked__Activity__c> oldActivities) {
        createGoogleEventsToDelete(oldActivities);
    }
    
    public static void afterActivitiesInsert(List<sked__Activity__c> newActivities) {
        createGoogleEventsToInsert(newActivities);
        updateGeoLocation(newActivities);
    }
    
    public static void afterActivitiesUpdate(Map<Id, sked__Activity__c> oldActivities, List<sked__Activity__c> newActivities) {
        
    }
    
    private static void updateGeoLocation(List<sked__Activity__c> newActivities) {
        string recordIds = '';
        
        for (sked__Activity__c activity : newActivities) {
            if (!string.isBlank(activity.sked__Address__c)) {
                if (activity.sked__GeoLocation__Latitude__s == NULL || activity.sked__GeoLocation__Longitude__s == NULL) {
                    recordIds += activity.Id + ';';
                }
            }
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateActivityGeoLocation(recordIds);
        }
    }
    
    private static void createGoogleEventsToDelete(List<sked__Activity__c> oldActivities) {
        List<sked_Google_Event__c> newGoogleEvents = new List<sked_Google_Event__c>();
        Set<Id> activityIdsToCancel = new Set<Id>();
        for (sked__Activity__c activity : oldActivities) {
            if (activity.Google_Event_Id__c != NULL) {
                sked_Google_Event__c googleEvent = new sked_Google_Event__c(
                	Related_Activity__c = activity.Id,
                    Related_Object_Type__c = 'sked__Activity__c',
                    Related_Object_Id__c = activity.Id,
                    Resource__c = activity.sked__Resource__c,
                    Event_Id__c = activity.Google_Event_Id__c,
                    Status__c = 'Queued',
                    Action__c = 'Delete'
                );
                newGoogleEvents.add(googleEvent);
            }
            else {
                activityIdsToCancel.add(activity.Id);
            }
        }
        if (newGoogleEvents.size() > 0) {
            insert newGoogleEvents;
        }
        if (activityIdsToCancel.size() > 0) {
            List<sked_Google_Event__c> googleEvents = [SELECT Id, Status__c 
                                                       FROM sked_Google_Event__c 
                                                       WHERE Related_Activity__c IN :activityIdsToCancel
                                                       AND Status__c = 'Queued'];
            for (sked_Google_Event__c googleEvent : googleEvents) {
                googleEvent.Status__c = 'Cancelled';
            }
            update googleEvents;
        }
    }
    
    private static void createGoogleEventsToInsert(List<sked__Activity__c> newActivities) {
        List<sked_Google_Event__c> newGoogleEvents = new List<sked_Google_Event__c>();
        for (sked__Activity__c activity : newActivities) {
            sked_Google_Event__c googleEvent = new sked_Google_Event__c(
                Related_Activity__c = activity.Id,
                Related_Object_Type__c = 'sked__Activity__c',
                Related_Object_Id__c = activity.Id,
            	Resource__c = activity.sked__Resource__c,
                Status__c = 'Queued',
                Action__c = 'Create'
            );
            string timezoneSidId = activity.sked__Timezone__c;
            if (string.isBlank(timezoneSidId)) {
                timezoneSidId = UserInfo.getTimeZone().getID();
            }
            googleEvent.Summary__c = '';
            googleEvent.Summary__c += activity.sked__Start__c.format('h:mma', timezoneSidId);
            googleEvent.Summary__c += ' - ' + activity.sked__Type__c;
            
            googleEvent.Location__c = activity.sked__Address__c;
            
            googleEvent.Start__c = activity.sked__Start__c;
            googleEvent.Finish__c = activity.sked__End__c;
            
            googleEvent.Description__c = '';
            googleEvent.Description__c += 'Start Time: ' + activity.sked__Start__c.format('h:mma', activity.sked__Timezone__c) + '\n';
            googleEvent.Description__c += 'End Time: ' + activity.sked__End__c.format('h:mma', activity.sked__Timezone__c) + '\n';
            googleEvent.Description__c += 'Type: ' + activity.sked__Type__c + '\n';
            googleEvent.Description__c += 'Notes: ' + activity.sked__Notes__c + '\n';
            if (activity.Related_Job__r != NULL) {
                googleEvent.Description__c += 'Related Job: ' + activity.Related_Job__r.Name + '\n';
            }
            newGoogleEvents.add(googleEvent);
        }
        if (newGoogleEvents.size() > 0) {
            insert newGoogleEvents;
        }
    }
    
}