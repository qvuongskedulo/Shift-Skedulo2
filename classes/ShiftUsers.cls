public class ShiftUsers {
	private static User lazyUserUnowned;
	private static User lazyUserVehicleValuation;

	public static Id unownedUserId() {
		if (lazyUserUnowned == null) {
			lazyUserUnowned = [
				SELECT Id 
				FROM User 
				WHERE Shift_Key__c = :ShiftConstants.USER_SHIFT_KEY_UNOWNED
			];
		}
		return lazyUserUnowned.Id;
	}

	public static Id vehicleValuationUserId() {
		if (lazyUserVehicleValuation == null) {
			lazyUserVehicleValuation = [
					SELECT Id
					FROM User
					WHERE Shift_Key__c = :ShiftConstants.USER_SHIFT_KEY_VEHICLE_VALUATION
			];
		}
		return lazyUserVehicleValuation.Id;
	}
}