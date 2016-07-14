trigger ShiftStaffProfileAttributeTrigger on Staff_Profile_Attribute__c (before insert, before update, after update, after delete) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftStaffProfiles.beforeStaffProfileAttributeInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftStaffProfiles.beforeStaffProfileAttributeUpdate(Trigger.oldMap, Trigger.new);
		}
	} else if (Trigger.isAfter) {
		if (Trigger.isUpdate) {
			ShiftStaffProfiles.afterStaffProfileAttributeUpdate(Trigger.oldMap, Trigger.new);
		} else if (Trigger.isDelete) {
			ShiftStaffProfiles.afterStaffProfileAttributeDelete(Trigger.old);
		}
	}
}