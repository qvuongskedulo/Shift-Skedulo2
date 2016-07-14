trigger BluewolfOpportunity on Opportunity (before update, after insert, after update) {
    
    BluewolfOpportunityTriggerHandler handle = new BluewolfOpportunityTriggerHandler(trigger.new, trigger.oldMap);
    if(trigger.isBefore){
        if(trigger.isUpdate){
            handle.beforeUpdate();
        }
    }
    else if(Trigger.isAfter){
        if(Trigger.isInsert){
            handle.afterInsert();
        }
        else if (Trigger.isUpdate){
            handle.afterUpdate();
        }
    }
}