@IsTest
class ShiftParkingLotsTest {
  static final String ERROR_STRING_DUPLICATES_VALUE = 'duplicates value on record';

	@TestSetup static void setup() { ShiftTesting.setup(); }

	@IsTest
	static void testDuplicateNameRegionIds() {
		Region__c regionA = ShiftTesting.createRandomRegion('regionA');
		Region__c regionB = ShiftTesting.createRandomRegion('regionB');

		insert new List<Region__c> {regionA, regionB};

		//Verify insertion of new none duplicate items
		Parking_Lot__c parkingLotA = ShiftTesting.createRandomParkingLot(regionA.Id, false);
		Parking_Lot__c parkingLotB = ShiftTesting.createRandomParkingLot(regionB.Id, false);
		Parking_Lot__c parkingLotDA = ShiftTesting.createRandomParkingLot(regionA.Id, false);
		Parking_Lot__c parkingLotDB = ShiftTesting.createParkingLot(parkingLotDA.Name, ShiftUtil.randomStringLowercaseAlphanum(8), regionB.Id, false);
		Parking_Lot__c parkingLotEA = ShiftTesting.createRandomParkingLot(regionA.Id, false);
		insert new List<Parking_Lot__c> {parkingLotA, parkingLotB, parkingLotDA, parkingLotDB, parkingLotEA};

		//Verify insertion of duplicate fails
		Parking_Lot__c duplicateParkingLotA = ShiftTesting.createParkingLot(parkingLotA.Name, ShiftUtil.randomStringLowercaseAlphanum(8), regionA.Id, false);
		ShiftTesting.expectInsertExceptionContains(duplicateParkingLotA, ERROR_STRING_DUPLICATES_VALUE);

		//Verify insertion of two duplicate records, one succeeds and one fails
		Parking_Lot__c parkingLotC = ShiftTesting.createRandomParkingLot(regionA.Id, false);
		Parking_Lot__c parkingLotCDuplicate = ShiftTesting.createParkingLot(parkingLotC.Name, ShiftUtil.randomStringLowercaseAlphanum(8), regionA.Id, false);
		ShiftTesting.insertBulkAndVerifyFailures(
				new List<Parking_Lot__c> { parkingLotC, parkingLotCDuplicate },
				new List<String> { null, ERROR_STRING_DUPLICATES_VALUE }
		);
	}

	@IsTest
	static void testErrorOnPrimaryParkingLotDuplicate() {
		Region__c parkingLotTestRegion = ShiftTesting.createRandomRegion('parking-lot-test-region');
		insert parkingLotTestRegion;
		insert ShiftTesting.createRandomParkingLot(parkingLotTestRegion.Id, true);

		// Verify that the insertion of a primary parking lot (above) doesn't
		// prevent the insertion of a non-primary parking lot in the same region.
		insert ShiftTesting.createRandomParkingLot(parkingLotTestRegion.Id, false);

		// Verify that the insertion of a primary parking lot (above) *does*
		// prevent the insertion of another primary parking lot in the same region.
		ShiftTesting.expectInsertExceptionContains(ShiftTesting.createRandomParkingLot(parkingLotTestRegion.Id, true), ERROR_STRING_DUPLICATES_VALUE);
	}

	@IsTest
	static void testErrorOnSimultaneousPrimaryParkingLotInsertion() {
		Region__c parkingLotTestRegion = ShiftTesting.createRandomRegion('parking-lot-test-region');
		insert parkingLotTestRegion;
		List<Parking_Lot__c> parkingLotsToInsert = new List<Parking_Lot__c>();
		parkingLotsToInsert.add(ShiftTesting.createRandomParkingLot(parkingLotTestRegion.Id, true));
		parkingLotsToInsert.add(ShiftTesting.createRandomParkingLot(parkingLotTestRegion.Id, true));
		ShiftTesting.expectInsertExceptionContains(parkingLotsToInsert, ERROR_STRING_DUPLICATES_VALUE);
	}
}