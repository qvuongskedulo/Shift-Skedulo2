trigger ShiftTaskTrigger on Task (before update, before insert, after update, after insert) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftTasks.beforeInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftTasks.beforeUpdate(Trigger.oldMap, Trigger.new);
		}
	}
	if (Trigger.isAfter) {
		if (Trigger.isInsert) {
			ShiftTasks.afterInsert(Trigger.new);
		}
		if (Trigger.isUpdate) {
			ShiftTasks.afterUpdate(Trigger.oldMap, Trigger.new);
		}
	}
}