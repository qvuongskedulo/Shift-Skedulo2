@IsTest
class ShiftCxCarSearchControllerTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	static List<Id> insertTestVehicles() {
		Region__c region1 = new Region__c(
			Name = 'Testing Region One',
			Shift_Key__c = 'testing/ShiftCxCarSearchControllerTest/region1',
			Timezone__c = 'America/Los_Angeles'
		);
		Region__c region2 = new Region__c(
			Name = 'Testing Region Two',
			Shift_Key__c = 'testing/ShiftCxCarSearchControllerTest/region2',
			Timezone__c = 'America/Toronto'
		);
		insert new List<Region__c>{region1, region2};
		insert new List<Parking_Lot__c>{
			ShiftTesting.createRandomParkingLot(region1.Id, true),
			ShiftTesting.createRandomParkingLot(region2.Id, true)
		};
		List<Id> out = new List<Id>();

		Account acct = new Account(Name = 'account name');
		insert acct;

		Vehicle__c bmw = new Vehicle__c(
			Year__c = 2010,
			Make__c = 'BMW',
			Model__c = '328i',
			Body_Style__c = 'Sedan',
			Mileage__c = 52000,
			List_Price__c = 20,
			Listing_Region_ID__c = region1.ID
		);
		insert bmw;
		out.add(bmw.Id);

		Vehicle__c toyota = new Vehicle__c(
			Year__c = 2012,
			Make__c = 'Toyota',
			Model__c = '4Runner',
			Body_Style__c = 'SUV',
			Mileage__c = 50000,
			List_Price__c = 30,
			Listing_Region_ID__c = region2.ID
		);
		insert toyota;
		out.add(toyota.Id);

		RecordType recordTypeSeller = [SELECT Id FROM RecordType WHERE DeveloperName = 'Seller' AND SObjectType = 'Opportunity'];
		insert new Opportunity(
			CloseDate = Date.parse('01/02/3000'),
			StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE,
			RecordTypeId = recordTypeSeller.Id,
			AccountId = acct.Id,
			Region_ID__r = new Region__c(Shift_Key__c = ShiftTesting.REGION_SHIFT_KEY_TESTING),
			Vehicle_ID__c = bmw.Id
		);
		insert new Opportunity(
			CloseDate = Date.parse('01/02/3000'),
			StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE,
			RecordTypeId = recordTypeSeller.Id,
			AccountId = acct.Id,
			Region_ID__r = new Region__c(Shift_Key__c = ShiftTesting.REGION_SHIFT_KEY_TESTING),
			Vehicle_ID__c = toyota.Id
		);

		return out;
	}

	static List<Vehicle__c> searchCarsInPrepare(String query, Integer limt) {
		Set<String> selectedStages = new Set<String>();
		selectedStages.add(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE);
		return ShiftCxCarSearchController.doSearch(selectedStages, query, limt).carsInStage.get(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE);
	}

	@IsTest
	static void testSearch() {
		List<Id> vehicleIds = insertTestVehicles();

		System.debug('opportunities: ' + [SELECT Id, Name, StageName, RecordType.Id, RecordType.DeveloperName, Vehicle_ID__r.Name FROM Opportunity]);
		System.debug('opportunity 0 record type developer name: ' + [SELECT Id, Name, RecordType.Id, RecordType.DeveloperName FROM Opportunity][0].RecordType.DeveloperName);
		System.debug('record types: ' + [SELECT Id, DeveloperName FROM RecordType]);

		// some sanity checks -- these test our test fixture, not the class under test
		System.assertEquals(2, vehicleIds.size());
		System.assertEquals(2, [SELECT Id FROM Opportunity].size());
		System.assertEquals(2, [SELECT Id FROM Opportunity WHERE RecordType.DeveloperName = 'Seller'].size());
		System.assertEquals(2, [SELECT Id FROM Opportunity WHERE StageName = :ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE].size());

		System.assertEquals(2, searchCarsInPrepare('', 100).size());

		System.assertEquals(2, searchCarsInPrepare('201', 100).size());

		// Test limit
		System.assertEquals(1, searchCarsInPrepare('201', 1).size());
		System.assertEquals(0, searchCarsInPrepare('201', 0).size());

		{
			List<Vehicle__c> results = searchCarsInPrepare('2012 To', 100);
			System.assertEquals(1, results.size());
			System.assertEquals('2012 Toyota 4Runner', results[0].Name);
			System.assertEquals('SUV', results[0].Body_Style__c);
			System.assertEquals(50000, results[0].Mileage__c);
			System.assertEquals(30, results[0].List_Price__c);
			System.assertEquals('Testing Region Two', results[0].Listing_Region_Name__c);
		}

		{
			List<Vehicle__c> results = searchCarsInPrepare(vehicleIds[1], 100);
			System.assertEquals(1, results.size());
			System.assertEquals('2012 Toyota 4Runner', results[0].Name);
		}

		{
			List<Vehicle__c> results = searchCarsInPrepare('BMW Sedan', 100);
			System.assertEquals(1, results.size());
			System.assertEquals('2010 BMW 328i', results[0].Name);
		}

		{
			List<Vehicle__c> results = searchCarsInPrepare('BMW Convertible', 100);
			System.assertEquals(0, results.size());
		}

		{
			List<Vehicle__c> results = searchCarsInPrepare('region2', 100);
			System.assertEquals(1, results.size());
			System.assertEquals('2012 Toyota 4Runner', results[0].Name);
		}

		{
			List<Vehicle__c> results = searchCarsInPrepare('Region One', 100);
			System.assertEquals(1, results.size());
			System.assertEquals('2010 BMW 328i', results[0].Name);
		}
	}

}