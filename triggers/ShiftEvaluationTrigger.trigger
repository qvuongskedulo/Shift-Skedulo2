trigger ShiftEvaluationTrigger on Evaluation__c (before insert, before update) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftEvaluations.beforeInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftEvaluations.beforeUpdate(Trigger.oldMap, Trigger.new);
		}
	}
}