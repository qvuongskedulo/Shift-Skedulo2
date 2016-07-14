trigger BluewolfEvaluation on Evaluation__c (after insert, after update) {
    BluewolfEvaluationTriggerHandler handle = new BluewolfEvaluationTriggerHandler(trigger.new, trigger.oldMap);
    
    if(trigger.isAfter){
        if(trigger.isInsert){handle.afterInsert();}
        else if (trigger.isUpdate){handle.afterUpdate();}
    }
}