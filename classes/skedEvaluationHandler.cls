public class skedEvaluationHandler {

    public static void afterEvaluationsInsert(List<Evaluation__c> newEvaluations) {
        string recordIds = '';
        
        for (Evaluation__c evaluation : newEvaluations) {
            recordIds += evaluation.Id + ';';
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateGeoLocation(recordIds, 'evaluation');
        }
    }
    
    public static void afterEvaluationsUpdate(Map<Id, Evaluation__c> oldEvaluations, List<Evaluation__c> newEvaluations) {
        string recordIds = '';
        Map<Id, Evaluation__c> mapEvaluationToCancelJobs = new Map<Id, Evaluation__c>();
        Map<Id, Evaluation__c> mapEvaluationToUpdateJobNotes = new Map<Id, Evaluation__c>();
        
        for (Evaluation__c evaluation : newEvaluations) {
            Evaluation__c oldData = oldEvaluations.get(evaluation.Id);
            if (evaluation.Location__c != oldData.Location__c 
                && evaluation.GeoLocation__Latitude__s == oldData.GeoLocation__Latitude__s 
                && evaluation.GeoLocation__Longitude__s == oldData.GeoLocation__Longitude__s) {
                    recordIds += evaluation.Id + ';';
                }
            if (evaluation.Canceled__c && evaluation.Canceled__c != oldData.Canceled__c) {
                mapEvaluationToCancelJobs.put(evaluation.Id, evaluation);
            }
            if (evaluation.Inside_Sales_Calendar_Notes__c != oldData.Inside_Sales_Calendar_Notes__c) {
                mapEvaluationToUpdateJobNotes.put(evaluation.Id, evaluation);
            }
        }
        if (mapEvaluationToCancelJobs.size() > 0) {
            skedTriggerUtils.CancelRelatedJobs(mapEvaluationToCancelJobs);
        }
        if (mapEvaluationToUpdateJobNotes.size() > 0) {
            skedTriggerUtils.UpdateJobShiftNotes(mapEvaluationToUpdateJobNotes);
        }
        if (recordIds.length() > 0) {
            recordIds = recordIds.substring(0, recordIds.length() - 1);
            skedLocationService.updateGeoLocation(recordIds, 'evaluation');
        }
    }
    
}