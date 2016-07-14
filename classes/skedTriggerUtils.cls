public class skedTriggerUtils {
    
    /*Update Job Shift Jobs*/
    public static void UpdateJobShiftNotes(Map<Id, Evaluation__c> mapEvaluations) {
        List<sked__Job__c> relatedJobs = [SELECT Id, Shift_Notes__c, Evaluation__c
                                          FROM sked__Job__c
                                          WHERE Evaluation__c IN :mapEvaluations.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        UpdateJobShiftNotes(mapEvaluations, relatedJobs, 'Evaluation__c', 'Inside_Sales_Calendar_Notes__c');
    }
    public static void UpdateJobShiftNotes(Map<Id, Test_Drive__c> mapTestDrives) {
        List<sked__Job__c> relatedJobs = [SELECT Id, Shift_Notes__c, Test_Drive__c
                                          FROM sked__Job__c
                                          WHERE Test_Drive__c IN :mapTestDrives.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        UpdateJobShiftNotes(mapTestDrives, relatedJobs, 'Test_Drive__c', 'Customer_Experience_Calendar_Notes__c');
    }
    public static void UpdateJobShiftNotes(Map<Id, Delivery__c> mapDeliveries) {
        List<sked__Job__c> relatedJobs = [SELECT Id, Shift_Notes__c, Delivery__c
                                          FROM sked__Job__c
                                          WHERE Delivery__c IN :mapDeliveries.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        UpdateJobShiftNotes(mapDeliveries, relatedJobs, 'Delivery__c', 'Notes__c');
    }
    public static void UpdateJobShiftNotes(Map<Id, Pick_Up__c> mapPickups) {
        List<sked__Job__c> relatedJobs = [SELECT Id, Shift_Notes__c, Pick_Up__c
                                          FROM sked__Job__c
                                          WHERE Pick_Up__c IN :mapPickups.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        UpdateJobShiftNotes(mapPickups, relatedJobs, 'Pick_Up__c', 'Notes__c');
    }
    public static void UpdateJobShiftNotes(Map<Id, sObject> mapTarget, List<sked__Job__c> inputJobs, string targetField, string notesField) {
        for (sked__Job__c inputJob : inputJobs) {
            string targetId = string.valueOf(inputJob.get(targetField));
            sObject target = mapTarget.get(targetId);
            inputJob.Shift_Notes__c = string.valueOf(target.get(notesField));
        }
        update inputJobs;
    }
    
    /*Cancel realted jobs*/
    public static void CancelRelatedJobs(Map<Id, Evaluation__c> mapEvaluations) {
        List<sked__Job__c> relatedJobs = [SELECT Id, sked__Job_Status__c, Evaluation__c,
                                          (SELECT sked__Status__c
                                           FROM sked__Job_Allocations__r
                                           WHERE sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED)
                                          FROM sked__Job__c
                                          WHERE Evaluation__c IN :mapEvaluations.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        CancelRelatedJobs(mapEvaluations, relatedJobs, 'Evaluation__c');
    }
    
    public static void CancelRelatedJobs(Map<Id, Test_Drive__c> mapTestDrives) {
        List<sked__Job__c> relatedJobs = [SELECT Id, sked__Job_Status__c, Test_Drive__c,
                                          (SELECT sked__Status__c
                                           FROM sked__Job_Allocations__r
                                           WHERE sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED)
                                          FROM sked__Job__c
                                          WHERE Test_Drive__c IN :mapTestDrives.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        CancelRelatedJobs(mapTestDrives, relatedJobs, 'Test_Drive__c');
    }
    
    public static void CancelRelatedJobs(Map<Id, Delivery__c> mapDeliveries) {
        List<sked__Job__c> relatedJobs = [SELECT Id, sked__Job_Status__c, Delivery__c,
                                          (SELECT sked__Status__c
                                           FROM sked__Job_Allocations__r
                                           WHERE sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED)
                                          FROM sked__Job__c
                                          WHERE Delivery__c IN :mapDeliveries.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        CancelRelatedJobs(mapDeliveries, relatedJobs, 'Delivery__c');
    }
    
    public static void CancelRelatedJobs(Map<Id, Pick_Up__c> mapPickups) {
        List<sked__Job__c> relatedJobs = [SELECT Id, sked__Job_Status__c, Pick_Up__c,
                                          (SELECT sked__Status__c
                                           FROM sked__Job_Allocations__r
                                           WHERE sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED)
                                          FROM sked__Job__c
                                          WHERE Pick_Up__c IN :mapPickups.keySet()
                                          AND sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        CancelRelatedJobs(mapPickups, relatedJobs, 'Pick_Up__c');
    }
    
    private static void CancelRelatedJobs(Map<Id, sObject> mapTarget, List<sked__Job__c> inputJobs, string targetField) {
        Set<Id> cannotCancelTargetIds = new Set<Id>();
        List<sked__Job__c> cancelledJobs = new List<sked__Job__c>();
        List<sked__Job_Allocation__c> deletedJobAllocations = new List<sked__Job_Allocation__c>();
        
        for (sked__Job__c inputJob : inputJobs) {
            string targetId = string.valueOf(inputJob.get(targetField));
            if (cannotCancelTargetIds.contains(targetId)) {
                continue;
            }
            sObject target = mapTarget.get(targetId);
            
            if (inputJob.sked__Job_Status__c == SkeduloConstants.JOB_STATUS_IN_PROGRESS || inputJob.sked__Job_Status__c == SkeduloConstants.JOB_STATUS_COMPLETE) {
                cannotCancelTargetIds.add(targetId);
            }
        }
        
        for (sked__Job__c inputJob : inputJobs) {
            string targetId = string.valueOf(inputJob.get(targetField));
            if (cannotCancelTargetIds.contains(targetId)) {
                continue;
            }
            inputJob.sked__Job_Status__c = SkeduloConstants.JOB_STATUS_CANCELLED;
            for (sked__Job_Allocation__c allocation : inputJob.sked__Job_Allocations__r) {
                allocation.sked__Status__c = SkeduloConstants.ALLOCATION_STATUS_DELETED;
                deletedJobAllocations.add(allocation);
            }
            cancelledJobs.add(inputJob);
        }
        
        for (Id cannotCancelTargetId : cannotCancelTargetIds) {
            sObject target = mapTarget.get(cannotCancelTargetId);
            target.addError('Cannot cancel In Progress/Complete job(s).');
        }
        
        if (cancelledJobs.size() > 0) {
            update cancelledJobs;
        }
        if (deletedJobAllocations.size() > 0) {
            update deletedJobAllocations;
        }
    }
}