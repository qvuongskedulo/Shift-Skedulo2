trigger ShiftCasesTrigger on Case (after update, after insert) {
	if (Trigger.isAfter) {
		if (Trigger.isUpdate) {
			ShiftCases.afterUpdate(Trigger.oldmap, Trigger.new);
		}
		if (Trigger.isInsert) {
			ShiftCases.afterInsert(Trigger.new);
		}
	}
}