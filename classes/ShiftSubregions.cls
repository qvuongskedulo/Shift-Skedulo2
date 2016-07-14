public class ShiftSubregions {
	static void setNameRegionIDUniqueKey(List<Subregion__c> subregions) {
		for (Subregion__c r : subregions) {
			r.Shift_UQ_Name_Region_ID__c = r.Region_ID__c + ':' + r.Name;
		}
	}

	public static void beforeInsert(List<Subregion__c> newSubregions) {
		setNameRegionIDUniqueKey(newSubregions);
	}

	public static void beforeUpdate(Map<Id, Subregion__c> oldSubregionMap, List<Subregion__c> newSubregions) {
		setNameRegionIDUniqueKey(newSubregions);
	}
}