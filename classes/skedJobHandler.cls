public class skedJobHandler {
    
    public static void beforeJobsInsert(List<sked__Job__c> newJobs) {
        populateJobFields(newJobs);
    }

    public static void beforeJobsUpdate(Map<Id, sked__Job__c> oldJobs, List<sked__Job__c> newJobs) {
        validatePublicIds(oldJobs, newJobs);
    }
    
    public static void beforeJobsDelete(List<sked__Job__c> oldJobs) {
        deleteRelatedActivities(oldJobs);
        createGoogleEventsToDelete(oldJobs);
    }
    
    public static void afterJobsInsert(List<sked__Job__c> newJobs) {
        Map<string, sked__Job__c> map_relatedEvaluationId_Job = new Map<string, sked__Job__c>();
        Map<string, sked__Job__c> map_relatedTestDriveId_Job = new Map<string, sked__Job__c>();
        Map<string, sked__Job__c> map_relatedPickupId_Job = new Map<string, sked__Job__c>();
        Map<string, sked__Job__c> map_relatedDeliveryId_Job = new Map<string, sked__Job__c>();
        
        for (sked__Job__c job : newJobs) {
            if (!string.isBlank(job.Evaluation__c)) {
                map_relatedEvaluationId_Job.put(job.Evaluation__c, job);
            } else if (!string.isBlank(job.Test_Drive__c)) {
                map_relatedTestDriveId_Job.put(job.Test_Drive__c, job);
            } else if (!string.isBlank(job.Pick_Up__c)) {
                map_relatedPickupId_Job.put(job.Pick_Up__c, job);
            } else if (!string.isBlank(job.Delivery__c)) {
                map_relatedDeliveryId_Job.put(job.Delivery__c, job);
            }
        }
        if (!map_relatedEvaluationId_Job.isEmpty()) {
            updateRelatedEvaluations(map_relatedEvaluationId_Job);
        }
        if (!map_relatedTestDriveId_Job.isEmpty()) {
            updateRelatedTestDrives(map_relatedTestDriveId_Job);
        }
        if (!map_relatedPickupId_Job.isEmpty()) {
            updateRelatedPickups(map_relatedPickupId_Job);
        }
        if (!map_relatedDeliveryId_Job.isEmpty()) {
            updateRelatedDeliveries(map_relatedDeliveryId_Job);
        }
    }
    
    public static void afterJobsUpdate(Map<Id, sked__Job__c> oldJobs, List<sked__Job__c> newJobs) {
        notifyCancel(oldJobs, newJobs);
        deleteRelatedActivities(oldJobs, newJobs);
    }
    
    static void validatePublicIds(Map<Id, sked__Job__c> oldMap, List<sked__Job__c> newList) {
        for (sked__Job__c job : newList) {
            if (oldMap.get(job.Id) != null && oldMap.get(job.Id).Public_ID__c != null && job.Public_ID__c != oldMap.get(job.Id).Public_ID__c) {
                job.addError('Attempt to change Public_ID__c from ' + oldMap.get(job.Id).Public_ID__c + ' to ' + job.Public_ID__c);
            }
        }
    }
    
    private static void createGoogleEventsToDelete(List<sked__Job__c> inputJobs) {
        Set<Id> jobIds = new Set<Id>();
        for (sked__Job__c job : inputJobs) {
            jobIds.add(job.Id);
        }
        List<sked__Job_Allocation__c> allocations = [SELECT sked__Job__c, sked__Resource__c
                                                     FROM sked__Job_Allocation__c
                                                     WHERE sked__Job__c IN :jobIds];
        Map<Id, Id> map_JobId_ResourceId = new Map<Id, Id>();
        for (sked__Job_Allocation__c allocation : allocations) {
            map_JobId_ResourceId.put(allocation.sked__Job__c, allocation.sked__Resource__c);
        }
        
        List<sked_Google_Event__c> newGoogleEvents = new List<sked_Google_Event__c>();
        Set<Id> jobIdsToCancel = new Set<Id>();
        for (sked__Job__c job : inputJobs) {
            if (job.Google_Event_Id__c != NULL) {
                Id resourceId = map_JobId_ResourceId.get(job.Id);
                if (resourceId != NULL) {
                    sked_Google_Event__c googleEvent = new sked_Google_Event__c(
                        Related_Job__c = job.Id,
                        Related_Object_Type__c = 'sked__Job__c',
                        Related_Object_Id__c = job.Id,
                        Resource__c = resourceId,
                        Event_Id__c = job.Google_Event_Id__c,
                        Status__c = 'Queued',
                        Action__c = 'Delete'
                    );
                    newGoogleEvents.add(googleEvent);
                }
            }
            else {
                jobIdsToCancel.add(job.Id);
            }
        }
        if (!newGoogleEvents.isEmpty()) {
            insert newGoogleEvents;
        }
        if (!jobIdsToCancel.isEmpty()) {
            List<sked_Google_Event__c> googleEvents = [SELECT Id, Status__c 
                                                       FROM sked_Google_Event__c 
                                                       WHERE Related_Job__c IN :jobIdsToCancel
                                                       AND Status__c = 'Queued'];
            for (sked_Google_Event__c googleEvent : googleEvents) {
                googleEvent.Status__c = 'Cancelled';
            }
            update googleEvents;
        }
    }
    
    private static void deleteRelatedActivities(List<sked__Job__c> oldJobs) {
        Set<Id> jobIdsToDeleteActivities = new Set<Id>();
        for (sked__Job__c job : oldJobs) {
            jobIdsToDeleteActivities.add(job.Id);
        }
        deleteRelatedActivities(jobIdsToDeleteActivities);
    }
    
    private static void deleteRelatedActivities(Map<Id, sked__Job__c> oldJobs, List<sked__Job__c> newJobs) {
        Set<Id> jobIdsToDeleteActivities = new Set<Id>();
        for (sked__Job__c job : newJobs) {
            sked__Job__c oldData = oldJobs.get(job.Id);
            if (job.sked__Job_Status__c == SkeduloConstants.JOB_STATUS_CANCELLED && job.sked__Job_Status__c != oldData.sked__Job_Status__c) {
                jobIdsToDeleteActivities.add(job.Id);
            }
        }
        deleteRelatedActivities(jobIdsToDeleteActivities);
    }
    
    private static void deleteRelatedActivities(Set<Id> jobIds) {
        if (!jobIds.isEmpty()) {
            List<sked__Activity__c> relatedActivities = [SELECT Id
                                                         FROM sked__Activity__c
                                                         WHERE Related_Job__c IN :jobIds];
            if (relatedActivities != NULL && !relatedActivities.isEmpty()) {
                delete relatedActivities;
            }
        }
    }
    
    private static void notifyCancel(Map<Id, sked__Job__c> oldJobs, List<sked__Job__c> newJobs) {
        List<sked__Job__c> jobsToDeleteGoogleEvents = new List<sked__Job__c>();
        for (sked__Job__c job : newJobs) {
            sked__Job__c oldData = oldJobs.get(job.Id);
            if (job.sked__Job_Status__c == SkeduloConstants.JOB_STATUS_CANCELLED && job.sked__Job_Status__c != oldData.sked__Job_Status__c) {
                jobsToDeleteGoogleEvents.add(job);
                skedSkeduloApiManager.sendCancelNotification(job.Id);
            }
        }
        if (jobsToDeleteGoogleEvents.size() > 0) {
            createGoogleEventsToDelete(jobsToDeleteGoogleEvents);
        }
    }
    
    //update Schedule info of Job's realted Evaluation
    private static void updateRelatedEvaluations(Map<string, sked__Job__c> map_relatedId_Job) {
        List<Evaluation__c> evaluations = [SELECT Id FROM Evaluation__c WHERE Id IN :map_relatedId_Job.keySet()];
        Set<Id> setOpportunitiesToMoveToEvaluateStage = new Set<Id>();
 
        for (Evaluation__c evaluation : evaluations) {
            sked__Job__c job = map_relatedId_Job.get(evaluation.Id);
            evaluation.Scheduled_By_ID__c = job.CreatedById;
            evaluation.Evaluated_At__c = job.sked__Start__c;
            setOpportunitiesToMoveToEvaluateStage.add(evaluation.Seller_Opportunity_ID__c);
        }
        update evaluations;
    }
    
    //update Schedule info of Job's realted TestDrive
    private static void updateRelatedTestDrives(Map<string, sked__Job__c> map_relatedId_Job) {
        List<Test_Drive__c> testDrives = [SELECT Id, Original_Time_Requested__c FROM Test_Drive__c WHERE Id IN :map_relatedId_Job.keySet()];
        
        for (Test_Drive__c testDrive : testDrives) {
            sked__Job__c job = map_relatedId_Job.get(testDrive.Id);
            if (job.sked__Type__c == SkeduloConstants.JOB_TYPE_TEST_DRIVE) {
                testDrive.Scheduled_By_ID__c = job.CreatedById;
                testDrive.Scheduled_For__c = job.sked__Start__c;
                if (testDrive.Original_Time_Requested__c != NULL && testDrive.Original_Time_Requested__c != job.sked__Start__c) {
                    testDrive.Test_Drive_Pushed__c = true;
                }
                testDrive.Departs_At__c = job.Departure_Time__c;
            }
        }
        update testDrives;
    }
    
    //update Schedule info of Job's realted Pickup
    private static void updateRelatedPickups(Map<string, sked__Job__c> map_relatedId_Job) {
        List<Pick_Up__c> pickups = [SELECT Id FROM Pick_Up__c WHERE Id IN :map_relatedId_Job.keySet()];
        
        for (Pick_Up__c pickup : pickups) {
            sked__Job__c job = map_relatedId_Job.get(pickup.Id);
            pickup.Scheduled_By__c = job.CreatedById;
            pickup.Scheduled_For__c = job.sked__Start__c;
            pickup.Departs_At__c = job.Departure_Time__c;
        }
        update pickups;
    }
    
    //update Schedule info of Job's realted Delivery
    private static void updateRelatedDeliveries(Map<string, sked__Job__c> map_relatedId_Job) {
        List<Delivery__c> deliveries = [SELECT Id FROM Delivery__c WHERE Id IN :map_relatedId_Job.keySet()];
        
        for (Delivery__c delivery : deliveries) {
            sked__Job__c job = map_relatedId_Job.get(delivery.Id);
            delivery.Scheduled_By__c = job.CreatedById;
            delivery.Scheduled_For__c = job.sked__Start__c;
            delivery.Departs_At__c = job.Departure_Time__c;
        }
        update deliveries;
    }
    
    private static void populateJobFields(List<sked__Job__c> inputJobs) {
        Set<Id> testDriveIds = new Set<Id>();
        Set<Id> evaluationIds = new Set<Id>();
        Set<Id> deliveryIds = new Set<Id>();
        Set<Id> pickupIds = new Set<Id>();
        
        for (sked__Job__c job : inputJobs) {
            if (!string.isBlank(job.Evaluation__c)) {
                evaluationIds.add(job.Evaluation__c);
            }
            else if (!string.isBlank(job.Test_Drive__c)) {
                testDriveIds.add(job.Test_Drive__c);
            }
            else if (!string.isBlank(job.Delivery__c)) {
                deliveryIds.add(job.Delivery__c);
            }
            else if (!string.isBlank(job.Pick_Up__c)) {
                pickupIds.add(job.Pick_Up__c);
            }
        }
        Map<Id, Evaluation__c> mapEvaluations = new Map<Id, EValuation__c>([SELECT Id, Inside_Sales_Calendar_Notes__c
                                                                            FROM Evaluation__c
                                                                            WHERE Id IN :evaluationIds]);
        Map<Id, Test_Drive__c> mapTestDrives = new Map<Id, Test_Drive__c>([SELECT Id, Customer_Experience_Calendar_Notes__c
                                                                           FROM Test_Drive__c
                                                                           WHERE Id IN :testDriveIds]);
        Map<Id, Delivery__c> mapDeliveries = new Map<Id, Delivery__c>([SELECT Id, Notes__c, Payment_Method__c, Payment_Details__c
                                                                       FROM Delivery__c
                                                                       WHERE Id IN :deliveryIds]);
        Map<Id, Pick_Up__c> mapPickups = new Map<Id, Pick_Up__c>([SELECT Id, Notes__c
                                                                  FROM Pick_Up__c
                                                                  WHERE Id IN :pickupIds]);
        for (sked__Job__c job : inputJobs) {
            if (mapEvaluations.containsKey(job.Evaluation__c)) {
                Evaluation__c evaluation = mapEvaluations.get(job.Evaluation__c);
                job.Shift_Notes__c = evaluation.Inside_Sales_Calendar_Notes__c;
            }
            else if (mapTestDrives.containsKey(job.Test_Drive__c)) {
                Test_Drive__c testDrive = mapTestDrives.get(job.Test_Drive__c);
                job.Shift_Notes__c = testDrive.Customer_Experience_Calendar_Notes__c;
            }
            else if (mapDeliveries.containsKey(job.Delivery__c)) {
                Delivery__c delivery = mapDeliveries.get(job.Delivery__c);
                job.Shift_Notes__c = delivery.Notes__c;
                job.Payment_Method__c = delivery.Payment_Method__c;
                job.Payment_Details__c = delivery.Payment_Details__c;
            }
            else if (mapPickups.containsKey(job.Pick_Up__c)) {
                Pick_Up__c pickup = mapPickups.get(job.Pick_Up__c);
                job.Shift_Notes__c = pickup.Notes__c;          
            }
 
            job.Scheduling_Token__c = ShiftUtil.randomStringLowercaseAlphanum(20);
        }
    }
}