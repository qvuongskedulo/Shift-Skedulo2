public without sharing class skedEmailUtil { 
    
    public static Messaging.SingleEmailMessage setTemplatedEmail(String[] toRecipients, String[] ccRecipients, String[] bccRecipients, string fromAddress, String templateApiName, ID targetObjId, Id whatId, ID orgWideEmailId, Boolean saveAsActivity, Attachment[] attachList ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        Id templateId;  
        try {
            templateId = [SELECT id, name FROM EmailTemplate WHERE developername = :templateApiName].id;
        }
        catch (Exception e) {
            return NULL;
        }
        
        email.setToAddresses(toRecipients);
        if (ccRecipients != NULL && ccRecipients.size() > 0) {
            email.setCcAddresses(ccRecipients);
        }
        if (bccRecipients != NULL && bccRecipients.size() > 0) {
            email.setBccAddresses(bccRecipients);
        }
        email.setTargetObjectId(targetObjId);
        if (whatId != NULL) {
            email.setWhatId(whatId);
        }
        
        email.setorgWideEmailAddressId(null);
        
        if (!string.isBlank(fromAddress)) {
            List<OrgWideEmailAddress> orgEmailResult = [SELECT Id, Address 
                                                        FROM OrgWideEmailAddress
                                                        WHERE Address =: fromAddress];
            if (orgEmailResult != NULL && orgEmailResult.size() > 0) {
                OrgWideEmailAddress fromAddressEmail = orgEmailResult.get(0);
                email.setorgWideEmailAddressId(fromAddressEmail.Id);
            }
        }
        
        email.setTemplateId(templateId);
        
        email.setSaveAsActivity(saveAsActivity);
        System.debug(LoggingLevel.INFO,'** entered sendTemplatedEmail, to:' + toRecipients + ' cc:' + ccRecipients +  ' templateId:' + templateId + ' tagetObjId:' + targetObjId +
                     ' whatId:' + whatId + ' orgWideEmailId: ' + orgWideEmailId);
        try {
            return email;
        }
        catch (EmailException e) {
            return null;
        }
    }
    
    public static void sendBookingEmails(List<sked__Job_Allocation__c> inputAllocations) {
        Set<Id> inputAllocationIds = new Set<Id>();
        
        for (sked__Job_Allocation__c allocation : inputAllocations) {
            inputAllocationIds.add(allocation.Id);
        }
        
        List<sked__Job_Allocation__c> allocations = [SELECT Id, sked__Resource__r.sked__Email__c, 
                                                     sked__Job__c, sked__Job__r.sked__Contact__c, sked__Job__r.sked__Contact__r.Email, 
                                                     sked__Job__r.sked__Type__c,
                                                     sked__Job__r.Pick_Up__c, sked__Job__r.Pick_Up__r.Evaluation_ID__c,
                                                     sked__Job__r.Pick_Up__r.Vehicle_Interest_ID__c,
                                                     sked__Job__r.Delivery__c, sked__Job__r.Delivery__r.Vehicle_Interest__c,
                                                     sked__Job__r.CreatedBy.Profile.Name,
                                                     sked__Job__r.Trigger_Email__c
                                                     FROM sked__Job_Allocation__c
                                                     WHERE Id IN :inputAllocationIds
                                                     AND sked__Job__r.Trigger_Email__c = TRUE];
        
        Set<Id> pickupEvaluationIds = new Set<Id>();
        Set<Id> vehicleInterestIds = new Set<Id>();
        for (sked__Job_Allocation__c allocItem : allocations) {
            if (allocItem.sked__Job__r.Pick_Up__r != NULL ) {
                if (!string.isBlank(allocItem.sked__Job__r.Pick_Up__r.Evaluation_ID__c)) {
                    pickupEvaluationIds.add(allocItem.sked__Job__r.Pick_Up__r.Evaluation_ID__c);
                }
                else if (!string.isBlank(allocItem.sked__Job__r.Pick_Up__r.Vehicle_Interest_ID__c)) {
                    vehicleInterestIds.add(allocItem.sked__Job__r.Pick_Up__r.Vehicle_Interest_ID__c);
                }
            }
            if (allocItem.sked__Job__r.Delivery__r != NULL) {
                vehicleInterestIds.add(allocItem.sked__Job__r.Delivery__r.Vehicle_Interest__c);
            }
        }
        
        Map<Id, sked__Job_Allocation__c> map_EvaluationId_Allocation = new Map<Id, sked__Job_Allocation__c>();
        Map<Id, sked__Job_Allocation__c> map_VehicleInterestId_Allocation = new Map<Id, sked__Job_Allocation__c>();
        
        List<sked__Job_Allocation__c> evaluationAllocations = [SELECT Id, sked__Resource__c, sked__Resource__r.sked__Email__c,
                                                               sked__Job__r.Evaluation__c
                                                               FROM sked__Job_Allocation__c
                                                               WHERE sked__Job__r.Evaluation__c != NULL
                                                               AND sked__Job__r.Evaluation__c IN :pickupEvaluationIds
                                                               AND sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED
                                                               AND sked__Job__r.sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        
        for (sked__Job_Allocation__c allocItem : evaluationAllocations) {
            map_EvaluationId_Allocation.put(allocItem.sked__Job__r.Evaluation__c, allocItem);
        }
        List<sked__Job_Allocation__c> vehicleInterestAllocations = [SELECT Id, sked__Resource__c, sked__Resource__r.sked__Email__c,
                                                                    sked__Job__r.Test_Drive__r.Vehicle_Interest_ID__c
                                                                    FROM sked__Job_Allocation__c
                                                                    WHERE sked__Job__r.Test_Drive__c != NULL
                                                                    AND sked__Job__r.Test_Drive__r.Vehicle_Interest_ID__c IN :vehicleInterestIds
                                                                    AND sked__Status__c != :SkeduloConstants.ALLOCATION_STATUS_DELETED
                                                                    AND sked__Job__r.sked__Job_Status__c != :SkeduloConstants.JOB_STATUS_CANCELLED];
        for (sked__Job_Allocation__c allocItem : vehicleInterestAllocations) {
            map_VehicleInterestId_Allocation.put(allocItem.sked__Job__r.Test_Drive__r.Vehicle_Interest_ID__c, allocItem);
        }
        
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();
        
        for (sked__Job_Allocation__c allocation : allocations) {
            string templateName = '';
            string jobType = allocation.sked__Job__r.sked__Type__c.toLowerCase();
            if (jobType.contains('evaluation')) {
                templateName = 'sked_Evaluation_Confirmation';
            } 
            else if (jobType.contains('test drive')) {
                templateName = 'sked_Test_Drive_Confirmation';
            } 
            else if (jobType.contains('delivery')) {
                templateName = 'sked_Delivery_Notification';
            } 
            else if (jobType.contains('pickup')) {
                if (jobType.contains('buyer')) {
                    templateName = 'sked_Pickup_Backflow_Notification';
                }
                else {
                    templateName = 'sked_Pickup_Notification';
                }
            } 
            else {
                continue;
            }
                
            List<string> toList = new List<string>();
            List<string> ccList = new List<string>();
            List<string> bccList = new List<string>();
            if (allocation.sked__Job__r.sked__Contact__r != NULL && !string.isBlank(allocation.sked__Job__r.sked__Contact__r.Email)) {
                toList.add(allocation.sked__Job__r.sked__Contact__r.Email);
            }
            else {
                continue;
            }
            if (!string.isBlank(allocation.sked__Resource__r.sked__Email__c)) {
                ccList.add(allocation.sked__Resource__r.sked__Email__c);
            }
            if (allocation.sked__Job__r.Pick_Up__r != NULL) {
                if (!string.isBlank(allocation.sked__Job__r.Pick_Up__r.Evaluation_ID__c)) {
                    if (map_EvaluationId_Allocation.containsKey(allocation.sked__Job__r.Pick_Up__r.Evaluation_ID__c)) {
                        sked__Job_Allocation__c carConciergeAlloc = map_EvaluationId_Allocation.get(allocation.sked__Job__r.Pick_Up__r.Evaluation_ID__c);
                        if (!string.isBlank(carConciergeAlloc.sked__Resource__r.sked__Email__c)) {
                            ccList.add(carConciergeAlloc.sked__Resource__r.sked__Email__c);
                        }
                    }
                }
                else if (!string.isBlank(allocation.sked__Job__r.Pick_Up__r.Vehicle_Interest_ID__c)) {
                    if (map_VehicleInterestId_Allocation.containsKey(allocation.sked__Job__r.Pick_Up__r.Vehicle_Interest_ID__c)) {
                        sked__Job_Allocation__c carEnthusiastAlloc = map_VehicleInterestId_Allocation.get(allocation.sked__Job__r.Pick_Up__r.Vehicle_Interest_ID__c);
                        if (!string.isBlank(carEnthusiastAlloc.sked__Resource__r.sked__Email__c)) {
                            ccList.add(carEnthusiastAlloc.sked__Resource__r.sked__Email__c);
                        }
                    }
                }
            }
            if (allocation.sked__Job__r.Delivery__r != NULL && !string.isBlank(allocation.sked__Job__r.Delivery__r.Vehicle_Interest__c)) {
                if (map_VehicleInterestId_Allocation.containsKey(allocation.sked__Job__r.Delivery__r.Vehicle_Interest__c)) {
                    sked__Job_Allocation__c carEnthusiastAlloc = map_VehicleInterestId_Allocation.get(allocation.sked__Job__r.Delivery__r.Vehicle_Interest__c);
                    if (!string.isBlank(carEnthusiastAlloc.sked__Resource__r.sked__Email__c)) {
                        ccList.add(carEnthusiastAlloc.sked__Resource__r.sked__Email__c);
                    }
                }
            }
            string fromAddress = '';
            sked_Booking_Email_Setting__c emailSetting = sked_Booking_Email_Setting__c.getOrgDefaults();
            if (jobType.contains('test drive') || jobType.contains('delivery')) {
                if (!string.isBlank(emailSetting.Buyer_Opportunity_CC_List__c)) {
                    string[] temp = emailSetting.Buyer_Opportunity_CC_List__c.split(';');
                    ccList.addAll(temp);
                }
                fromAddress = emailSetting.Customer_Experience_Email__c;
            } 
            if (jobType.contains('evaluation')) {
                if (!string.isBlank(emailSetting.Seller_Opportunity_CC_List__c)) {
                    string[] temp = emailSetting.Seller_Opportunity_CC_List__c.split(';');
                    ccList.addAll(temp);
                }
                if (allocation.sked__Job__r.CreatedBy.Profile.Name == SkeduloConstants.PROFILE_INBOUND_SALES) {
                    fromAddress = emailSetting.Inside_Sales_Inbound_Email__c;
                }
            } 
            if (jobType.contains('pickup')) {
                if (allocation.sked__Job__r.Pick_Up__r != NULL) {
                    if (!string.isBlank(allocation.sked__Job__r.Pick_Up__r.Evaluation_ID__c)) {
                        if (!string.isBlank(emailSetting.Seller_Opportunity_CC_List__c)) {
                            string[] temp = emailSetting.Seller_Opportunity_CC_List__c.split(';');
                            ccList.addAll(temp);
                        }
                        if (allocation.sked__Job__r.CreatedBy.Profile.Name == SkeduloConstants.PROFILE_INBOUND_SALES) {
                            fromAddress = emailSetting.Inside_Sales_Inbound_Email__c;
                        }
                    } 
                    else if (!string.isBlank(allocation.sked__Job__r.Pick_Up__r.Vehicle_Interest_ID__c)) {
                        if (!string.isBlank(emailSetting.Buyer_Opportunity_CC_List__c)) {
                            string[] temp = emailSetting.Buyer_Opportunity_CC_List__c.split(';');
                            ccList.addAll(temp);
                        }
                        fromAddress = emailSetting.Customer_Experience_Email__c;
                    }
                }
            } 
            if (!string.isBlank(fromAddress)) {
                if (fromAddress != emailSetting.Customer_Experience_Email__c) {
                    bccList.add(fromAddress);
                }
            } else {
                string currentUserEmail = UserInfo.getUserEmail();
                if (!string.isBlank(currentUserEmail)) {
                    bccList.add(currentUserEmail);
                }
            }
            Messaging.SingleEmailMessage email = setTemplatedEmail(toList, ccList, bccList, fromAddress, templateName, allocation.sked__Job__r.sked__Contact__c, 
                                                                   allocation.sked__Job__c, null, false, null);
            if (email != NULL) {
                emailList.add(email);
            }
        }
        if (emailList.size() > 0) {
            Messaging.sendEmail(emailList);
        }
    }
    
}