trigger ShiftStaffProfileTrigger on Staff_Profile__c (before insert, before update, after insert, after update, after delete) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftStaffProfiles.beforeStaffProfileInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftStaffProfiles.beforeStaffProfileUpdate(Trigger.oldMap, Trigger.new);
		}
	} else if (Trigger.isAfter) {
		if (Trigger.isInsert) {
			ShiftStaffProfiles.afterStaffProfileInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftStaffProfiles.afterStaffProfileUpdate(Trigger.oldMap, Trigger.new);
		} else if (Trigger.isDelete) {
			ShiftStaffProfiles.afterStaffProfileDelete(Trigger.old);
		}
	}
}