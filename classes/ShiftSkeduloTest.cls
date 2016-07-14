@IsTest(SeeAllData = true)
class ShiftSkeduloTest {
	// This test ensures that we have code coverage for ShiftSkeduloTesting,
	// as mandated by Salesforce, even though that class is intended for use
	// only via anonymous Apex execution.
	@IsTest
	static void testShiftSkeduloTesting() {
		Subregion__c subregion = [SELECT Id, Name, Region_ID__c FROM Subregion__c LIMIT 1];
		Region__c region = [SELECT Id, Shift_Key__c FROM Region__c WHERE Id = :subregion.Region_ID__c];

		ShiftSkeduloTesting.StaffProfileCreator spCreator = new ShiftSkeduloTesting.StaffProfileCreator('FirstName', 'LastName', 'CC');
		spCreator.regionShiftKey = region.Shift_Key__c;
		spCreator.subregionName = subregion.Name;
		spCreator.create();

		ShiftSkeduloTesting.SellerOpportunityCreator soCreator = new ShiftSkeduloTesting.SellerOpportunityCreator('FirstName', 'LastName');
		soCreator.regionShiftKey = region.Shift_Key__c;
		soCreator.create();

		ShiftSkeduloTesting.BuyerOpportunityCreator boCreator = new ShiftSkeduloTesting.BuyerOpportunityCreator('FirstName', 'LastName');
		boCreator.regionShiftKey = region.Shift_Key__c;
		boCreator.create();
		boCreator.addVehicleInterest(soCreator.getVehicleId());
	}
}