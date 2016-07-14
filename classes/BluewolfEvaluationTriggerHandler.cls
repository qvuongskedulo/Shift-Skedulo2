public with sharing class BluewolfEvaluationTriggerHandler {
    private final List<Evaluation__c> records;
    private final Map<Id, Evaluation__c> oldMap;
    
    @TestVisible
    private static Boolean bypassTrigger = false;
    
    public BluewolfEvaluationTriggerHandler(List<Evaluation__c> records,  Map<Id, Evaluation__c> oldMap){
        this.records = records;
        this.oldMap = oldMap;
    }
    
    public void afterInsert(){
        if(bypassTrigger) return;
        BluewolfEvaluationService.afterInsert(records);
    }
    
    public void afterUpdate(){
        if(bypassTrigger) return;
        BluewolfEvaluationService.afterUpdate(records, oldMap);
    }
}