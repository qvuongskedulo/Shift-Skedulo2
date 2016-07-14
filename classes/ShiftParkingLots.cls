public class ShiftParkingLots {
	public static Map<Id, Id> getRegionIdToPrimaryParkingLotIdMap(Set<Id> regionIds) {
		List<Parking_Lot__c> primaryParkingLots = [
			SELECT Id, Region_ID__c
			FROM Parking_Lot__c
			WHERE
				Region_ID__c IN :regionIds AND
				Is_Region_Primary__c = TRUE
		];
		Map<Id, Id> regionIdToPrimaryParkingLotId = new Map<Id, Id>();
		for (Parking_Lot__c primaryParkingLot : primaryParkingLots) {
			regionIdToPrimaryParkingLotId.put(primaryParkingLot.Region_ID__c, primaryParkingLot.Id);
		}
		return regionIdToPrimaryParkingLotId;
	}

	static void setNameRegionIDUniqueKey(List<Parking_Lot__c> parkingLots) {
		for (Parking_Lot__c p : parkingLots) {
			p.Shift_UQ_Name_Region_ID__c = p.Region_ID__c + ':' + p.Name;
		}
	}

	static void setRegionPrimaryUniqueKey(List<Parking_Lot__c> parkingLots) {
		for (Parking_Lot__c p : parkingLots) {
			if (p.Is_Region_Primary__c) {
				p.Shift_UQ_Region_Primary__c = p.Region_ID__c + ':primary';
			}
		}
	}

	public static void beforeInsert(List<Parking_Lot__c> newParkingLots) {
		setNameRegionIDUniqueKey(newParkingLots);
		setRegionPrimaryUniqueKey(newParkingLots);
	}

	public static void beforeUpdate(Map<Id, Parking_Lot__c> oldParkingLotMap, List<Parking_Lot__c> newParkingLots) {
		setNameRegionIDUniqueKey(newParkingLots);
		setRegionPrimaryUniqueKey(newParkingLots);
	}
}