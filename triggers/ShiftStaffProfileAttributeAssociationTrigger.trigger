trigger ShiftStaffProfileAttributeAssociationTrigger on Staff_Profile_Attribute_Association__c (before insert, after insert, before update, after update, after delete) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftStaffProfiles.beforeStaffProfileAttributeAssociationInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftStaffProfiles.beforeStaffProfileAttributeAssociationUpdate(Trigger.oldMap, Trigger.new);
		}
	}

	if (Trigger.isAfter) {
		if (Trigger.isInsert) {
			ShiftStaffProfiles.afterStaffProfileAttributeAssociationInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftStaffProfiles.afterStaffProfileAttributeAssociationUpdate(Trigger.oldMap, Trigger.new);
		} else if (Trigger.isDelete) {
			ShiftStaffProfiles.afterStaffProfileAttributeAssociationDelete(Trigger.old);
		}
	}
}