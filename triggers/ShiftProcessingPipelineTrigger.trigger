trigger ShiftProcessingPipelineTrigger on Processing_Pipeline__c (after update, before update) {
	ShiftWorkflow.processStateObjects(ShiftProcessingPipeline.WORKFLOW_IDENTIFIER);

	if (Trigger.isBefore) {
		if (Trigger.isUpdate) {
			ShiftProcessingPipeline.beforeUpdate(Trigger.oldMap, Trigger.newMap);
		}
	}
}