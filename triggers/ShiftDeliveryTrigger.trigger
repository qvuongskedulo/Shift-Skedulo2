trigger ShiftDeliveryTrigger on Delivery__c (after insert) {
	if (Trigger.isAfter) {
		if (Trigger.isInsert) {
			ShiftDelivery.afterInsert(Trigger.new);
		}
	}
}