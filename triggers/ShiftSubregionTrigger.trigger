trigger ShiftSubregionTrigger on Subregion__c (before insert, before update) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftSubregions.beforeInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftSubregions.beforeUpdate(Trigger.oldMap, Trigger.new);
		}
	}
}