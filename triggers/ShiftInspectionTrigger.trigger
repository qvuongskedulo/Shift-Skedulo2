trigger ShiftInspectionTrigger on Inspection__c (after update) {
	ShiftProcessingPipeline.processInspectionChanges(Trigger.oldMap, Trigger.new);
}