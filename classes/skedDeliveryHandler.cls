public class skedDeliveryHandler {

    public static void afterDeliverysInsert(List<Delivery__c> newDeliverys) {
        string recordIds = '';
        
        for (Delivery__c delivery : newDeliverys) {
            recordIds += delivery.Id + ';';
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateGeoLocation(recordIds, 'delivery');
        }
    }
    
    public static void afterDeliverysUpdate(Map<Id, Delivery__c> oldDeliverys, List<Delivery__c> newDeliverys) {
        string recordIds = '';
        Map<Id, Delivery__c> mapDeliveryToCancelJobs = new Map<Id, Delivery__c>();
        Map<Id, Delivery__c> mapDeliveryToUpdateJobFields = new Map<Id, Delivery__c>();
        
        for (Delivery__c delivery : newDeliverys) {
            Delivery__c oldData = oldDeliverys.get(delivery.Id);
            if (delivery.Location__c != oldData.Location__c 
                && delivery.GeoLocation__Latitude__s == oldData.GeoLocation__Latitude__s 
                && delivery.GeoLocation__Longitude__s == oldData.GeoLocation__Longitude__s) {
                    recordIds += delivery.Id + ';';
                }
            if (delivery.Canceled__c && delivery.Canceled__c != oldData.Canceled__c) {
                mapDeliveryToCancelJobs.put(delivery.Id, delivery);
            }
            if (delivery.Notes__c != oldData.Notes__c || delivery.Payment_Details__c != oldData.Payment_Details__c
                || delivery.Payment_Method__c != oldData.Payment_Method__c) {
                mapDeliveryToUpdateJobFields.put(delivery.Id, delivery);
            }
        }
        if (mapDeliveryToCancelJobs.size() > 0) {
            skedTriggerUtils.CancelRelatedJobs(mapDeliveryToCancelJobs);
        }
        if (mapDeliveryToUpdateJobFields.size() > 0) {
            UpdateJobFields(mapDeliveryToUpdateJobFields);
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateGeoLocation(recordIds, 'delivery');
        }
    }
    
    
    public static void UpdateJobFields(Map<Id, Delivery__c> mapDeliveries) {
        List<sked__Job__c> relatedJobs = [SELECT Id, Shift_Notes__c, Delivery__c, Payment_Details__c, Payment_Method__c
                                          FROM sked__Job__c
                                          WHERE Delivery__c IN :mapDeliveries.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        for (sked__Job__c job : relatedJobs) {
            Delivery__c delivery = mapDeliveries.get(job.Delivery__c);
            job.Shift_Notes__c = delivery.Notes__c;
            job.Payment_Details__c = delivery.Payment_Details__c;
            job.Payment_Method__c = delivery.Payment_Method__c;
        }
        update relatedJobs;
    }
    
}