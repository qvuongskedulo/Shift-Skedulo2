public with sharing class BluewolfEmailMessageService {
    
    @testVisible private static String CASE_OWNER_NAME = 'unowned';
    @TestVisible
    private final static Id SELLER_OPP_ID = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Seller'].Id;
    @TestVisible
    private static Boolean bypassTrigger = false;
    @TestVisible
    private final static String INCOMING_STATUS = 'Needs Action';
    @TestVisible
    private final static String OUTGOING_STATUS = 'Awaiting Response';
    @TestVisible
    private static List<CaseTypePriority__c> priorityMap {
        get{
            if(priorityMap == null){
                priorityMap = CaseTypePriority__c.getAll().values();
            }
            return priorityMap;
        }
        private set;
    } 
    @testVisible
    private static Id caseOwnerId {
        get {
            if (caseOwnerId == null) {
                caseOwnerId = [SELECT Id FROM User WHERE Shift_Key__c = :CASE_OWNER_NAME].Id;
            }
            return caseOwnerId;
        }
        private set;
    }
    private static Map<String, Decimal> caseTypeToPriorityMap {
        get{
            if(caseTypeToPriorityMap == null){
                caseTypeToPriorityMap = new Map<String, Decimal>();
                for(CaseTypePriority__c value: priorityMap){
                    caseTypeToPriorityMap.put(value.CaseType__c, value.Priority__c);
                }
            }
            return caseTypeToPriorityMap;
        }
        private set;
    }
    
    private static Set<Case> emailPriorityCases = new Set<Case>();
    private static Map<Id, String> caseIdToFromAddressMap = new Map<Id, String>();
    private static Map<Id, String> caseIdToAddressMap = new Map<Id, String>();
    
    public static void afterInsert(List<EmailMessage> records){
        
        if(bypassTrigger) return;
        
        Map<Id, Case> emailToCaseMap = getEmailToCaseMap(records);
        
        List<Case> outgoingCases = getRelatedCases(emailToCaseMap, outgoingEmail().filter(records));
        List<Case> incomingCases = getRelatedCases(emailToCaseMap, incomingEmail().filter(records));
        
        List<Case> filteredIncomingCases = Select.Field.notIn(Case.Case_Type__c, getAvailableStatus('EmailMessage')).andx(Select.Field.notEqual('Opportunity_Id__r.RecordTypeId', SELLER_OPP_ID)).filter(incomingCases);
        setCaseToFromAddressMap(records, emailToCaseMap, filteredIncomingCases);
        setCaseToAddressMap(records, emailToCaseMap, filteredIncomingCases);
        changeCaseType(filteredIncomingCases);
        
        changeCaseStatus(outgoingCases, OUTGOING_STATUS);
        changeCaseStatus(incomingCases, INCOMING_STATUS);
        
        List<Case> cases = new List<Case>();
        cases.addAll(outgoingCases);
        cases.addAll(incomingCases);
        updateCases(cases, records);
    }
    
    private static Set<String> getAvailableStatus(String objectName){
        Set<String> results = new Set<String>();
        
        Decimal minPriority = 1000000;
        Decimal maxPriority = 0;
        
        for(CaseTypePriority__c value: priorityMap){
            if(value.ObjectName__c == objectName){
                if(value.Priority__c > maxPriority) maxPriority = value.Priority__c;
                if(value.Priority__c < minPriority) minPriority = value.Priority__c;
            }
        }
        
        if(maxPriority >= minPriority){
            for(CaseTypePriority__c value: priorityMap){
                if(value.Priority__c <= minPriority){
                    results.add(value.CaseType__c);
                }
            }
        }
        
        return results;
    }
    
    private static void setCaseToFromAddressMap(List<EmailMessage> records, Map<Id, Case> emailToCaseMap, List<Case> cases){
        for(Case aCase: cases){
            for(EmailMessage record: records){
                if(emailToCaseMap.get(record.Id) == aCase){
                    caseIdToFromAddressMap.put(aCase.Id, record.FromAddress);
                    break;
                }
            }
        }
    }
    
    private static void setCaseToAddressMap(List<EmailMessage> records, Map<Id, Case> emailToCaseMap, List<Case> cases){
        for(Case aCase: cases){
            for(EmailMessage record: records){
                if(emailToCaseMap.get(record.Id) == aCase){
                    caseIdToAddressMap.put(aCase.Id, record.ToAddress);
                    break;
                }
            }
        }
    }
    
    private static void changeCaseType(List<Case> cases){
        for(Case aCase: cases){
            Decimal currentPriority = caseTypeToPriorityMap.get(aCase.Case_Type__c);
            if(currentPriority != null){
                String newCaseType = getNewCaseType(aCase, currentPriority, 'EmailMessage');
                if(newCaseType != null){
                    aCase.Case_Type__c = newCaseType;
                    aCase.Status = 'New';
                    aCase.OwnerId = caseOwnerId;
                    emailPriorityCases.add(aCase);
                }
            }
        }
    }
    
    private static String getNewCaseType(Case aCase, Decimal currentPriority, String objectName){
        String result;
        String fromAddress = caseIdToFromAddressMap.get(aCase.Id);
        String toAddress = caseIdToAddressMap.get(aCase.Id);
        if(fromAddress != null && toAddress != null && toAddress.contains('sell')){
            for(CaseTypePriority__c value: priorityMap){
                if(value.ObjectName__c == objectName && value.Priority__c < currentPriority){
                    if(value.FromAddress__c == null){
                        currentPriority = value.Priority__c;
                        result = value.CaseType__c;
                    }
                    else{
                        for(String emailAddress: value.FromAddress__c.split(',')){
                            if(fromAddress.containsIgnoreCase(emailAddress.trim())){
                                currentPriority = value.Priority__c;
                                result = value.CaseType__c;
                                break;
                            }
                        }
                    }
                }
            }
        }
        return result;
    }
    
    private static void updateCases(List<Case> cases, List<EmailMessage> records){
        BluewolfDMLBox BluewolfDMLBox = new BluewolfDMLBox();
        BluewolfDMLBox.add(cases, records);
        BluewolfDMLBox.safeUpdate();
    }
    
    @TestVisible
    private static Map<Id, Case> getEmailToCaseMap(List<EmailMessage> records){
        Map<Id, Case> emailToCaseMap = new Map<Id, Case>();
        
        List<Case> relatedCases = [SELECT Status, Opportunity_Id__r.RecordTypeId, Case_Type__c FROM Case WHERE Id = :BluewolfPluck.ids('ParentId', records)];
        for(EmailMessage email: records){
            for(Case aCase: relatedCases){
                if(aCase.Id == email.ParentId){
                    emailToCaseMap.put(email.Id, aCase);
                    break;
                }
            }
        }
        return emailToCaseMap;
    }
 
    @TestVisible
    private static List<Case> getRelatedCases(Map<Id, Case> emailToCaseMap, List<EmailMessage> records){
        List<Case> cases = new List<Case>();
        
        Set<Id> filterIds = BluewolfPluck.ids('Id', records);
        for(Id emailId: emailToCaseMap.keySet()){
            if(filterIds.contains(emailId)){
                cases.add(emailToCaseMap.get(emailId));
            }
        }
        return cases;
    }
    
    @TestVisible
    private static void changeCaseStatus(List<Case> cases, String caseStatus){
        for(Case aCase: cases){
            if(!emailPriorityCases.contains(aCase)){
                aCase.status = caseStatus;
            }
        }
    }
    
    @TestVisible
    private static Select.Filter incomingEmail(){
        return Select.Field.isEqual(EmailMessage.Incoming, true);
    }
    
    @TestVisible
    private static Select.Filter outgoingEmail(){
        return Select.Field.isEqual(EmailMessage.Incoming, false);
    }
}