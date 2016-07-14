trigger ShiftTestObject1Trigger on Test_Object1__c (after insert, after update) {
	ShiftWorkflow.processStateObjects(ShiftWorkflowTesting.TEST_IDENTIFIER);
}