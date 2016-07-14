trigger ShiftParkingLotTrigger on Parking_Lot__c (before insert, before update) {
	if (Trigger.isBefore) {
		if (Trigger.isInsert) {
			ShiftParkingLots.beforeInsert(Trigger.new);
		} else if (Trigger.isUpdate) {
			ShiftParkingLots.beforeUpdate(Trigger.oldMap, Trigger.new);
		}
	}
}