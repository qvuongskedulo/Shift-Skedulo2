trigger ShiftAccountTrigger on Account (before update, after update) {
	if(Trigger.isBefore){
		if(Trigger.isUpdate){
			ShiftAccounts.beforeUpdate(Trigger.new, Trigger.newMap);
		}
	}
	if(Trigger.isAfter){
		if(Trigger.isUpdate){
			ShiftAccounts.afterUpdate(Trigger.new, Trigger.newMap);
		}
	}
}