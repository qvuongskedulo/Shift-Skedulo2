public class ShiftRegions {
	public static sked__Region__c skeduloRegionForShiftRegion(Region__c region) {
		return new sked__Region__c(
			Id = region.Skedulo_Region_ID__c,
			Name = region.Name,
			sked__Timezone__c = region.Timezone__c
		);
	}

	private static void insertSkeduloRegions(List<Region__c> newRegions) {
		List<sked__Region__c> skeduloRegionsToInsert = new List<sked__Region__c>();
		for (Region__c region : newRegions) {
			skeduloRegionsToInsert.add(ShiftRegions.skeduloRegionForShiftRegion(region));
		}
		insert skeduloRegionsToInsert;

		for (Integer i = 0; i < newRegions.size(); i++) {
			newRegions[i].Skedulo_Region_ID__c = skeduloRegionsToInsert[i].Id;
		}
	}

	private static void updateSkeduloRegions(List<Region__c> newRegions) {
		List<sked__Region__c> skeduloRegionsToUpdate = new List<sked__Region__c>();
		for (Region__c region : newRegions) {
			if (region.Skedulo_Region_ID__c == null) {
				region.Skedulo_Region_ID__c.addError('"Skedulo Region" cannot be NULL');
				continue;
			}
			skeduloRegionsToUpdate.add(ShiftRegions.skeduloRegionForShiftRegion(region));
		}
		update skeduloRegionsToUpdate;
	}

	private static void deleteSkeduloRegions(List<Region__c> oldRegions) {
		List<sked__Region__c> skeduloRegionsToDelete = new List<sked__Region__c>();
		for (Region__c region : oldRegions) {
			skeduloRegionsToDelete.add(new sked__Region__c(Id = region.Skedulo_Region_ID__c));
		}
		delete skeduloRegionsToDelete;
	}

	public static void beforeInsert(List<Region__c> newRegions) {
		insertSkeduloRegions(newRegions);
	}

	public static void beforeUpdate(Map<Id, Region__c> oldRegionMap, List<Region__c> newRegions) {
		updateSkeduloRegions(newRegions);
	}

	public static void afterDelete(List<Region__c> oldRegions) {
		deleteSkeduloRegions(oldRegions);
	}

	// In order to bootstrap a system which has pre-existing Shift Regions
	// that do not correspond to Skedulo Regions, run the following as anonymous Apex.
	//
	// List<sked__Region__c> skeduloRegionsToUpsert = new List<sked__Region__c>();
	// List<Region__c> regions = [SELECT Name, Timezone__c, Skedulo_Region_ID__c FROM Region__c];
	// for (Region__c region : regions) {
	//	 skeduloRegionsToUpsert.add(ShiftRegions.skeduloRegionForShiftRegion(region));
	// }
	// upsert skeduloRegionsToUpsert;
	// for (Integer i = 0; i < regions.size(); i++) {
	//	 regions[i].Skedulo_Region_ID__c = skeduloRegionsToUpsert[i].Id;
	// }
	// update regions;
}