public with sharing class BluewolfEvaluationService {
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
    
    @TestVisible
    private final static String CASE_TYPE = 'Open Evaluation';
    private static Select.Filter notCanceled(){
        return Select.Field.isEqual(Evaluation__c.Canceled__c, false);
    }
    
    private static Select.Filter availableTime(){
        return Select.Field.greaterThan(Evaluation__c.Evaluated_At__c, Datetime.now());
    }
    
    
    private static Select.Filter canceledChanged(){
        return Select.Field.hasChanged(Evaluation__c.Canceled__c);
    }
    
    private static Select.Filter timeChanged(){
        return Select.Field.hasChanged(Evaluation__c.Evaluated_At__c);
    }
    
    public static void afterInsert(List<Evaluation__c> records){
        
        List<Evaluation__c> filteredRecords = notCanceled().andx(availableTime()).filter(records);
        
        Map<Id, List<Case>> oppIdToCaseMap = getOppToCaseMap(filteredRecords);
        
        upsertCases(oppIdToCaseMap, filteredRecords);
    } 
    
    public static void afterUpdate(List<Evaluation__c> records, Map<Id, Evaluation__c> oldMap){
        List<Evaluation__c> filteredRecords = canceledChanged().orx(timeChanged()).andx(notCanceled().andx(availableTime())).filter(records, oldMap);
        
        Map<Id, List<Case>> oppIdToCaseMap = getOppToCaseMap(filteredRecords);
        
        upsertCases(oppIdToCaseMap, filteredRecords);
    }
    private static void upsertCases(Map<Id, List<Case>> oppIdToCaseMap, List<Evaluation__c> filteredRecords){
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
    
    private static Map<Id, List<Case>> getOppToCaseMap(List<Evaluation__c> evaluations){
        Map<Id, List<Case>> resultMap = new  Map<Id, List<Case>>();
        
        Set<Id> oppIds = Pluck.ids('Seller_Opportunity_ID__c', evaluations);
        
        resultMap = GroupBy.ids('Opportunity_ID__c', [SELECT Opportunity_ID__c, Case_Type__c FROM Case WHERE Opportunity_ID__c =:oppIds AND Opportunity_Id__r.RecordType.DeveloperName = 'Seller' AND Case_Type__c != :getAvailableStatus('Evaluation')]);
        
        for(Id oppId : oppIds){
            if(!resultMap.containsKey(oppId)) resultMap.put(oppId, new List<Case>());
        }
        
        return resultMap;
    }
    
}