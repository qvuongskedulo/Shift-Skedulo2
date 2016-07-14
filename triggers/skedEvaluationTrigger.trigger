trigger skedEvaluationTrigger on Evaluation__c (after insert, after update) {
    if (Trigger.IsAfter) {
        if (Trigger.IsInsert) {
            skedEvaluationHandler.afterEvaluationsInsert(Trigger.New);
        }
        if (Trigger.IsUpdate) {
            skedEvaluationHandler.afterEvaluationsUpdate(Trigger.OldMap, Trigger.New);
        }
    }
}