public class skedJobAllocationHandler {

    public static void afterJobAllocationsInsert(List<sked__Job_Allocation__c> newJobAllocations) {
        createGoogleEventsToInsert(newJobAllocations);
        
        updateEvaluateBy_TestDriveBy(newJobAllocations);
        
        sked_Booking_Email_Setting__c emailSetting = sked_Booking_Email_Setting__c.getOrgDefaults();
        if (emailSetting.Activated__c == TRUE) {
            skedEmailUtil.sendBookingEmails(newJobAllocations);
        }
    }
    
    private static void createGoogleEventsToInsert(List<sked__Job_Allocation__c> newJobAllocations) {
        Set<Id> jobIds = new Set<Id>();
        for (sked__Job_Allocation__c allocation : newJobAllocations) {
            jobIds.add(allocation.sked__Job__c);
        }
        Map<Id, sked__Job__c> mapJob = new Map<Id, sked__Job__c>([SELECT Id, Name, sked__Account__r.Name, sked__Address__c, sked__Contact__r.Name, 
                                                                  sked__Contact__r.MailingCity, sked__Contact__r.Phone, sked__Contact__r.Email,
                                                                  sked__Duration__c, sked__Finish__c, sked__Job_Status__c, sked__Start__c, sked__Timezone__c, 
                                                                  sked__Type__c, Departure_Time__c, Return_Time__c, Vehicle_Name__c, Vehicle_Link__c, 
                                                                  Opportunity_Name__c, Salesforce_Link__c, Manual__c, Number_of_Owners__c, Number_of_Accidents__c, 
                                                                  Guaranteed_Price__c, Quoted_Sale_Price__c, Quoted_Projected_In_Pocket__c, Pick_up_probability__c, 
                                                                  Is_Aware_Of_Advance_Funds_Qualification__c, Advance_Funds_Status__c, Google_Event_Id__c
                                                                  FROM sked__Job__c
                                                                  WHERE Id IN :jobIds]);
        
        List<sked_Google_Event__c> newGoogleEvents = new List<sked_Google_Event__c>();
        for (sked__Job_Allocation__c allocation : newJobAllocations) {
            sked__Job__c job = mapJob.get(allocation.sked__Job__c);
            
            sked_Google_Event__c googleEvent = new sked_Google_Event__c(
                Related_Job__c = job.Id,
                Related_Object_Type__c = 'sked__Job__c',
                Related_Object_Id__c = job.Id,
            	Resource__c = allocation.sked__Resource__c,
                Status__c = 'Queued',
                Action__c = 'Create'
            );
            googleEvent.Summary__c = '';
            googleEvent.Summary__c += job.sked__Start__c.format('h:mma', job.sked__Timezone__c);
            googleEvent.Summary__c += ' - ' + job.sked__Type__c;
            googleEvent.Summary__c += ' - ' + job.Vehicle_Name__c;
            googleEvent.Summary__c += ' - ' + job.sked__Contact__r.Name;   
            googleEvent.Summary__c += ' - ' + job.sked__Contact__r.MailingCity;
            
            googleEvent.Location__c = job.sked__Address__c;
            
            googleEvent.Start__c = job.Departure_Time__c;
            googleEvent.Finish__c = job.Return_Time__c;
            
            googleEvent.Description__c = '';
            googleEvent.Description__c += 'Vehicle Name: ' + job.Vehicle_Name__c + '\n';
            googleEvent.Description__c += 'Opportunity Name: ' + job.Opportunity_Name__c + '\n';
            googleEvent.Description__c += 'Customer Contact Name: ' + job.sked__Contact__r.Name + '\n';
            googleEvent.Description__c += 'Customer Phone Number: ' + job.sked__Contact__r.Phone + '\n';
            googleEvent.Description__c += 'Customer Email Address: ' + job.sked__Contact__r.Email + '\n';
            googleEvent.Description__c += 'Start Time: ' + job.sked__Start__c.format('h:mma', job.sked__Timezone__c) + '\n';
            googleEvent.Description__c += 'Duration: ' + job.sked__Duration__c + '\n';
            googleEvent.Description__c += 'Transmission: ' + job.Manual__c + '\n';
            googleEvent.Description__c += 'Number Of Owners: ' + job.Number_of_Owners__c + '\n';
            googleEvent.Description__c += 'Number Of Accidents: ' + job.Number_of_Accidents__c + '\n';
            googleEvent.Description__c += 'Guaranteed Price: ' + job.Guaranteed_Price__c + '\n';
            googleEvent.Description__c += 'Quoted Sale Price: ' + job.Quoted_Sale_Price__c + '\n';
            googleEvent.Description__c += 'Quoted Projected In Pocket: ' + job.Quoted_Projected_In_Pocket__c + '\n';
            googleEvent.Description__c += 'Pickup Probability: ' + job.Pick_up_probability__c + '\n';
            googleEvent.Description__c += 'Is Aware Of Advance Funds Qualification: ' + job.Is_Aware_Of_Advance_Funds_Qualification__c + '\n';
            googleEvent.Description__c += 'Advance Funds Status: ' + job.Advance_Funds_Status__c;
            newGoogleEvents.add(googleEvent);
        }
        if (newGoogleEvents.size() > 0) {
            insert newGoogleEvents;
        }
    }
    
    private static void updateEvaluateBy_TestDriveBy(List<sked__Job_Allocation__c> jobAllocations) {
        Set<Id> allocationIds = new Set<Id>();
        for (sked__Job_Allocation__c allocation : jobAllocations) {
            allocationIds.add(allocation.Id);
        }
        updateEvaluateBy_TestDriveBy(allocationIds);
    }
    
    //update test drive by/evaluated by/pickup by/delivery by on root records
    private static void updateEvaluateBy_TestDriveBy(Set<Id> allocationIds) {
        List<sked__Job_Allocation__c> allocations = [SELECT Id, sked__Resource__c, sked__Resource__r.sked__User__c, sked__Job__c, 
                                                     sked__Job__r.Evaluation__c, sked__Job__r.Test_Drive__c, sked__Job__r.Delivery__c, sked__Job__r.Pick_Up__c,
                                                     sked__Job__r.sked__Job_Status__c, sked__Job__r.sked__Type__c, sked__Status__c
                                                     FROM sked__Job_Allocation__c
                                                     WHERE Id IN :allocationIds
                                                     AND (sked__Job__r.Test_Drive__c != NULL OR sked__Job__r.Evaluation__c != NULL
                                                         OR sked__Job__r.Pick_Up__c != NULL OR sked__Job__r.Delivery__c != NULL)];
        
        Set<Id> evaluationIds = new Set<Id>();
        Set<Id> testDriveIds = new Set<Id>();
        Set<Id> pickupIds = new Set<Id>();
        Set<Id> deliveryIds = new Set<Id>();
        Set<Id> resourceIds = new Set<Id>();
        
        for (sked__Job_Allocation__c allocation : allocations) {
            if (!string.isBlank(allocation.sked__Job__r.Evaluation__c)) {
                evaluationIds.add(allocation.sked__Job__r.Evaluation__c);
            } 
            else if (!string.isBlank(allocation.sked__Job__r.Test_Drive__c)) {
                testDriveIds.add(allocation.sked__Job__r.Test_Drive__c);
            }
            else if (!string.isBlank(allocation.sked__Job__r.Pick_Up__c)) {
                pickupIds.add(allocation.sked__Job__r.Pick_Up__c);
            }
            else if (!string.isBlank(allocation.sked__Job__r.Delivery__c)) {
                deliveryIds.add(allocation.sked__Job__r.Delivery__c);
            }
            else {
                continue;
            }
            resourceIds.add(allocation.sked__Resource__c);
        }
        if (evaluationIds.size() == 0 && testDriveIds.size() == 0 && pickupIds.size() == 0 && deliveryIds.size() == 0) {
            return;
        }
        
        Map<Id, Evaluation__c> mapEvaluation = new Map<Id, Evaluation__c>([SELECT Id
                                                                           FROM Evaluation__c
                                                                           WHERE Id IN :evaluationIds]);
        Map<Id, Test_Drive__c> mapTestDrive = new Map<Id, Test_Drive__c>([SELECT Id
                                                                          FROM Test_Drive__c
                                                                          WHERE Id IN :testDriveIds]);
        Map<Id, Pick_Up__c> mapPickup = new Map<Id, Pick_Up__c>([SELECT Id
                                                                 FROM Pick_Up__c
                                                                 WHERE Id IN :pickupIds]);
        Map<Id, Delivery__c> mapDelivery = new Map<Id, Delivery__c>([SELECT Id
                                                                     FROM Delivery__c
                                                                     WHERE Id IN :deliveryIds]);
        
        List<sked__Resource__c> resources = [SELECT Id, Name, sked__User__c,
                                             (SELECT sked__Tag__c, sked__Tag__r.Name
                                              FROM sked__ResourceTags__r
                                              WHERE sked__Expiry_Date__c = NULL OR sked__Expiry_Date__c>= :system.now().date())
                                             FROM sked__Resource__c
                                             WHERE Id IN :resourceIds];
        
        List<sObject> updateRecords = new List<sObject>();
        for (sked__Job_Allocation__c allocation : allocations) {
            if (!string.isBlank(allocation.sked__Job__r.Evaluation__c)) {
                Evaluation__c evaluation = mapEvaluation.get(allocation.sked__Job__r.Evaluation__c);
                if (allocation.sked__Status__c == SkeduloConstants.ALLOCATION_STATUS_DELETED) {
                    evaluation.Evaluated_By_ID__c = null;
                }
                else {
                    evaluation.Evaluated_By_ID__c = allocation.sked__Resource__r.sked__User__c;
                }
                updateRecords.add(evaluation);
            } 
            else if (!string.isBlank(allocation.sked__Job__r.Test_Drive__c)) {
                Test_Drive__c testDrive = mapTestDrive.get(allocation.sked__Job__r.Test_Drive__c);
                if (allocation.sked__Status__c == SkeduloConstants.ALLOCATION_STATUS_DELETED) {
                    if (allocation.sked__Job__r.sked__Type__c == SkeduloConstants.JOB_TYPE_TEST_DRIVE) {
                        testDrive.Test_Drive_By_ID__c = null;
                    } 
                    else if (allocation.sked__Job__r.sked__Type__c == SkeduloConstants.JOB_TYPE_DRIVERS_ASSIST) {
                        testDrive.Driver_Assist_By_ID__c = null;
                    }
                }
                else {
                    if (allocation.sked__Job__r.sked__Type__c == SkeduloConstants.JOB_TYPE_TEST_DRIVE) {
                        testDrive.Test_Drive_By_ID__c = allocation.sked__Resource__r.sked__User__c;
                    } 
                    else if (allocation.sked__Job__r.sked__Type__c == SkeduloConstants.JOB_TYPE_DRIVERS_ASSIST) {
                        testDrive.Driver_Assist_By_ID__c = allocation.sked__Resource__r.sked__User__c;
                    }
                }
                updateRecords.add(testDrive);
            }
            else if (!string.isBlank(allocation.sked__Job__r.Pick_Up__c)) {
                Pick_Up__c pickup = mapPickup.get(allocation.sked__Job__r.Pick_Up__c);
                if (allocation.sked__Status__c == SkeduloConstants.ALLOCATION_STATUS_DELETED) {
                    pickup.Pick_Up_By__c = null;
                }
                else {
                    pickup.Pick_Up_By__c = allocation.sked__Resource__r.sked__User__c;
                }
                updateRecords.add(pickup);
            } 
            else if (!string.isBlank(allocation.sked__Job__r.Delivery__c)) {
                Delivery__c delivery = mapDelivery.get(allocation.sked__Job__r.Delivery__c);
                if (allocation.sked__Status__c == SkeduloConstants.ALLOCATION_STATUS_DELETED) {
                    delivery.Delivery_By__c = null;
                }
                else {
                    delivery.Delivery_By__c = allocation.sked__Resource__r.sked__User__c;
                }
                updateRecords.add(delivery);
            } 
        }
        update updateRecords;
    }
}