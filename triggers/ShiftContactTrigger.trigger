trigger ShiftContactTrigger on Contact (before insert, before update, after update, after insert, after delete) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftContacts.beforeInsert(Trigger.new);
		}
		if (Trigger.isUpdate) {
			ShiftContacts.beforeUpdate(Trigger.oldMap, Trigger.newMap);
		}
	}
	if (Trigger.isAfter) {
		if (Trigger.isUpdate) {
			ShiftContacts.afterUpdate(Trigger.new, Trigger.oldmap);
		}
		if (Trigger.isInsert) {
			ShiftContacts.afterInsert(Trigger.new);
		}
		if (Trigger.isDelete) {
			ShiftContacts.afterDelete(Trigger.old);
		}
	}
}