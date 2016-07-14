public class skedPickupHandler {

    public static void afterPickupsInsert(List<Pick_Up__c> newPickups) {
        string recordIds = '';
        
        for (Pick_Up__c pickup : newPickups) {
            recordIds += pickup.Id + ';';
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateGeoLocation(recordIds, 'pickup');
        }
    }
    
    public static void afterPickupsUpdate(Map<Id, Pick_Up__c> oldPickups, List<Pick_Up__c> newPickups) {
        string recordIds = '';
        Map<Id, Pick_Up__c> mapPickupToCancelJobs = new Map<Id, Pick_Up__c>();
        Map<Id, Pick_Up__c> mapPickupToUpdateJobNotes = new Map<Id, Pick_Up__c>();
        
        for (Pick_Up__c pickup : newPickups) {
            Pick_Up__c oldData = oldPickups.get(pickup.Id);
            if (pickup.Location__c != oldData.Location__c 
                && pickup.GeoLocation__Latitude__s == oldData.GeoLocation__Latitude__s 
                && pickup.GeoLocation__Longitude__s == oldData.GeoLocation__Longitude__s) {
                    recordIds += pickup.Id + ';';
                }
            if (pickup.Canceled__c && pickup.Canceled__c != oldData.Canceled__c) {
                mapPickupToCancelJobs.put(pickup.Id, pickup);
            }
            if (pickup.Notes__c != oldData.Notes__c) {
                mapPickupToUpdateJobNotes.put(pickup.Id, pickup);
            }
        }
        if (mapPickupToCancelJobs.size() > 0) {
            skedTriggerUtils.CancelRelatedJobs(mapPickupToCancelJobs);
        }
        if (mapPickupToUpdateJobNotes.size() > 0) {
            skedTriggerUtils.UpdateJobShiftNotes(mapPickupToUpdateJobNotes);
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateGeoLocation(recordIds, 'pickup');
        }
    }
    
}