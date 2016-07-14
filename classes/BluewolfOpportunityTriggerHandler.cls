public with sharing class BluewolfOpportunityTriggerHandler {
    
    private final List<Opportunity> records;
    private final Map<Id, Opportunity> oldMap;

    @TestVisible
    private static Boolean bypassTrigger = false;
    
    public BluewolfOpportunityTriggerHandler(List<Opportunity> records, Map<Id,Opportunity> oldMap){
        this.records = records;
        this.oldMap = oldMap;
    }
    
    public void beforeUpdate(){
        if(bypassTrigger) return;
        BluewolfOpportunityService.beforeUpdate(records, oldMap);
    }
    
    public void afterUpdate(){
        if(bypassTrigger) return;    
        BluewolfOpportunityService.afterUpdate(records, oldMap);
    }
    
    public void afterInsert(){
        if(bypassTrigger) return;  
        BluewolfOpportunityService.afterInsert(records);
    }
}