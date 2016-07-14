public with sharing class BluewolfOpportunityService {

    @testVisible private static String CASE_OWNER_NAME = 'unowned';
    @testVisible private static String AVAILABLE_TYPE = 'Vehicle Available - Schedule Test Drives';
    @testVisible private static String UNAVAILABLE_TYPE = 'Vehicle Unavailable - Cancel Test Drives';
    @testVisible private static String AVAILABLE_STAGE = 'Prepare Car for Sale';
    @testVisible private static Id SELLER_OPP_ID{
        get{
            if(SELLER_OPP_ID == null){
                SELLER_OPP_ID = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Seller'].Id;
            }
            return SELLER_OPP_ID;
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
    @TestVisible
    private final static String CRAIGSLIST = 'Craigslist';
    @TestVisible
    private static final User ASSIGNED_USER = [SELECT Id FROM User WHERE Shift_Key__c = 'unowned'];
    @TestVisible
    private static final String CASE_TYPE = 'New Inbound Seller Opportunity';
    private static final Set<String> VALID_STAGES = new Set<String>{'Leads', 'Quote and Schedule'};
    private static Map<Id, List<Vehicle__c>> oppToVehicleMap;
    private static Map<Id, Id> oppToContactMap;
    private static List<CaseTypePriority__c> priorityMap {
        get{
            if(priorityMap == null){
                priorityMap = CaseTypePriority__c.getAll().values();
            }
            return priorityMap;
        }
        private set;
    } 
    private static Select.Filter validStage(){
        return Select.Field.isIn(Opportunity.StageName, VALID_STAGES);
    }
    private static Select.Filter stageChanged(){
        return Select.Field.hasChanged(Opportunity.StageName);
    }
    private static Select.Filter isSellerOpportunity(){
        return Select.Field.isEqual(Opportunity.RecordTypeId, SELLER_OPP_ID);
    }
    
    private static Select.Filter recordTypeChanged(){
        return Select.Field.hasChanged(Opportunity.RecordTypeId);
    }
    
    private static Select.Filter isNotFromCraigsList(){
        return Select.Field.notEqual(Opportunity.LeadSource, CRAIGSLIST);
    }
    
    private static Select.Filter leadSourceChanged(){
        return Select.Field.hasChanged(Opportunity.LeadSource);
    }
    
    public static void afterInsert(List<Opportunity> records){
        List<Opportunity> filteredRecords = validStage().andx(isSellerOpportunity()).andx(isNotFromCraigsList()).filter(records);
        createCases(filteredRecords);
    }
    
    public static void afterUpdate(List<Opportunity> records, Map<Id, Opportunity> oldMap){
        List<Opportunity> filteredRecords = stageChanged().orx(recordTypeChanged()).orx(leadSourceChanged()).andx(validStage()).andx(isSellerOpportunity().andx(isNotFromCraigsList())).filter(records, oldMap);
        Map<Id, List<Case>> resultMap = getOppToCaseMap(filteredRecords);
        upsertCases(resultMap, filteredRecords);
    }
    private static void upsertCases(Map<Id, List<Case>> oppIdToCaseMap, List<Opportunity> filteredRecords){
        BluewolfDMLBox insertDMLBox = new BluewolfDMLBox();
        BluewolfDMLBox updateDMLBox = new BluewolfDMLBox();
        
        List<Case> updateCases = new List<Case>();
        List<Case> insertCases = new List<Case>();
        for(Id oppId : oppIdToCaseMap.keySet()){
            List<Case> cases = oppIdToCaseMap.get(oppId);
            if(cases != null && !cases.isEmpty()){
               for(Case aCase: cases){
                   aCase.Case_Type__c = CASE_TYPE;
               }
               updateCases.addAll(cases);
            }
            else{
                insertCases.add(new Case(Opportunity_ID__c = oppId, Case_Type__c = CASE_TYPE));
            }
        }
        
        insertDMLBox.add(insertCases, filteredRecords);
        updateDMLBox.add(updateCases, filteredRecords);
        
        insertDMLBox.safeInsert();
        updateDMLBox.safeUpdate();
    }
    
    private static Map<Id, List<Case>> getOppToCaseMap(List<Opportunity> opps){
        Map<Id, List<Case>> resultMap = new  Map<Id, List<Case>>();
        
        Set<Id> oppIds = Pluck.ids(opps);
        
        resultMap = GroupBy.ids('Opportunity_ID__c', [SELECT Opportunity_ID__c, Case_Type__c FROM Case WHERE Opportunity_ID__c =:oppIds AND Case_Type__c != :getAvailableStatus('Opportunity')]);
        
        for(Id oppId : oppIds){
            if(!resultMap.containsKey(oppId)) resultMap.put(oppId, new List<Case>());
        }
        
        return resultMap;
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
    
    @TestVisible
    private static void createCases(List<Opportunity> opps){
        BluewolfDMLBox dmlBox = new BluewolfDMLBox();
        List<Case> newCases = new List<Case>();
        if(oppToContactMap == null) oppToContactMap = getOppToContactIdMap(opps);
        for(Opportunity opp: opps){
            Case newCase = new Case(Opportunity_Id__c = opp.Id,
                                    Case_Type__c = CASE_TYPE,
                                    AccountId = opp.AccountId,
                                    ContactId = oppToContactMap.get(opp.Id),
                                    OwnerId = ASSIGNED_USER.Id);
            newCases.add(newCase);
        }
        
        dmlBox.add(newCases, opps);
        dmlBox.safeInsert();
    }
    public static void beforeUpdate(List<Opportunity> opps, Map<Id, Opportunity> oldMap){
        
        BluewolfDMLBox dmlBox = new BluewolfDMLBox();
        List<Opportunity> filteredOpps = stageChanged().filter(opps, oldMap);
        if(oppToVehicleMap == null) oppToVehicleMap = getVehicleMap(filteredOpps);
        List<Case> createdCases = new List<Case>();
        
        for(Opportunity opp: filteredOpps){
            List<Vehicle__c> vehicles = oppToVehicleMap.get(opp.Id);
            if(vehicles == null || vehicles.isEmpty()) continue;
            
            Vehicle__c vehicle = vehicles[0];
            
            if(opp.StageName == AVAILABLE_STAGE && !getComingSoon(vehicle)){
                createdCases.add(new Case(
                    OwnerId = caseOwnerId,
                    Vehicle_ID__c = vehicle.Id,
                    Case_Type__c = UNAVAILABLE_TYPE
                ));
            }
            else if(oldMap.get(opp.Id).stageName == AVAILABLE_STAGE && !getComingSoon(vehicle)){
                createdCases.add(new Case(
                    OwnerId = caseOwnerId,
                    Vehicle_ID__c = vehicle.Id,
                    Case_Type__c = AVAILABLE_TYPE
                ));
            }
        }
        
        dmlBox.add(createdCases, filteredOpps);
        dmlBox.safeInsert();
    }
    
    private static Map<Id, List<Vehicle__c>> getVehicleMap(List<Opportunity> opps){
        
        Map<Id, List<Vehicle__c>> resultMap = new Map<Id, List<Vehicle__c>>();
        
        resultMap = GroupBy.ids('Seller_Opportunity_ID__c', [SELECT Seller_Opportunity_Id__r.StageName, Seller_Opportunity_ID__c, Needs_Repairs__c, In_Transit__c, Paperwork_Missing__c, Photos_Ready__c, Id FROM Vehicle__c WHERE Seller_Opportunity_ID__c =:opps]);
        
        return resultMap;
    }
    
    private static Map<Id, Id> getOppToContactIdMap(List<Opportunity> opps){
        Map<Id, Id> resultMap = new Map<Id, Id>();
        
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE AccountId = :Pluck.ids('AccountId', opps)];
        for(Opportunity opp: opps){
            for(Contact contact: contacts){
                if(opp.AccountId == contact.AccountId){
                    resultMap.put(opp.Id, contact.Id);
                    break;
                }
            } 
        }
        
        return resultMap;    
    }
    
    private static Boolean getComingSoon(Vehicle__c vehicle){
        Boolean result = vehicle.Needs_Repairs__c || vehicle.In_Transit__c || vehicle.Paperwork_Missing__c ==  'Yes - Less Than 7 Days Unavailable' || vehicle.Paperwork_Missing__c == 'Yes - More Than 7 Days Unavailable' || !vehicle.Photos_Ready__c;
        return result;
    }
}