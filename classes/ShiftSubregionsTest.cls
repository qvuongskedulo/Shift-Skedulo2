@IsTest
private with sharing class ShiftSubregionsTest {
	static Subregion__c createSubregion(String name, Id regionId) {
		return new Subregion__c(
				Name = name,
				Region_ID__c = regionId
		);
	}

	@IsTest
	static void testDuplicateNameRegionIDs() {
		String expectedErrorMessage = 'duplicates value on record';

		Region__c regionA = ShiftTesting.createRandomRegion('regionA');
		Region__c regionB = ShiftTesting.createRandomRegion('regionB');

		insert new List<Region__c> {regionA, regionB};

		//Verify insertion of new none duplicate items
		Subregion__c subRegionA = createSubregion('subRegionA', regionA.Id);
		Subregion__c subRegionB = createSubregion('subRegionB', regionB.Id);
		Subregion__c subRegionDA = createSubregion('subRegionD', regionA.Id);
		Subregion__c subRegionDB = createSubregion('subRegionD', regionB.Id);
		Subregion__c subRegionEA = createSubregion('subRegionE', regionA.Id);

		insert new List<Subregion__c> {subRegionA, subRegionB, subRegionDA, subRegionDB, subRegionEA};

		//Verify insertion of duplicate fails
		Subregion__c duplicateSubRegionA = createSubregion(subRegionA.name, regionA.Id);
		ShiftTesting.expectInsertExceptionContains(duplicateSubRegionA, expectedErrorMessage);

		//Verify insertion of two duplicate records, one succeeds and one fails
		Subregion__c subRegionC = createSubregion('subRegionC', regionA.Id);
		Subregion__c subRegionCDuplicate = createSubregion('subRegionC', regionA.Id);
		ShiftTesting.insertBulkAndVerifyFailures(
				new List<Subregion__c> { subRegionC, subRegionCDuplicate },
				new List<String> { null, expectedErrorMessage }
		);
	}
}