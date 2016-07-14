trigger ShiftRegionTrigger on Region__c (before insert, before update, after delete) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftRegions.beforeInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftRegions.beforeUpdate(Trigger.oldMap, Trigger.new);
		}
	} else if (Trigger.isAfter) {
		if (Trigger.isDelete) {
			ShiftRegions.afterDelete(Trigger.old);
		}
	}
}