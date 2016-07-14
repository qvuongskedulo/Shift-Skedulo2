@isTest public class ShiftSellerVehicleSyncTest {

	@testSetup private static void setup() { ShiftTesting.setup(); }

	private static Vehicle__c createTestVehicle() {
		return new Vehicle__c(
			Name = 'test vehicle',
			Year__c = 2001,
			Make__c = 'Toyota',
			Model__c = 'Corolla',
			Listing_Region_ID__r = new Region__c(Shift_Key__c = 'testing')
		);
	}

	private static Vehicle__c insertTestVehicle() {
		Vehicle__c res = createTestVehicle();
		insert res;
		return res;
	}

	private static Opportunity createSellerOpportunity(Id vehicleId) {
		Account acct = new Account(Name = 'Test Account');
		insert acct;
		List<RecordType> recTypes = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Seller'];
		return new Opportunity(
			Name = 'test seller',
			AccountId = acct.Id,
			RecordTypeId = recTypes.get(0).Id,
			StageName = 'Quote and Schedule',
			CloseDate = Date.today().addDays(60),
			Vehicle_ID__c = vehicleId,
			Region_ID__r = [SELECT Id FROM Region__c WHERE Shift_Key__c = 'testing']
		);
	}

	private static Opportunity insertSellerOpportunity(Id vehicleId) {
		Opportunity res = createSellerOpportunity(vehicleId);
		insert res;
		return res;
	}

	private static void expectVehicleSellerOpportunityID(Vehicle__c v, Opportunity seller) {
		Vehicle__c act = [SELECT Seller_Opportunity_ID__c FROM Vehicle__c WHERE Id = :v.Id];
		Id expctSellerId = null;
		if (seller != null) {
			expctSellerId = seller.Id;
		}
		System.assertEquals(expctSellerId, act.Seller_Opportunity_Id__c);
	}

	@isTest private static void testOneOpportunityOneVehicle() {
		// insert a vehicle v1 and a seller opp s1 and check that v1 points to s1
		Vehicle__c v1 = insertTestVehicle();
		System.assert(v1.Id != null);
		Opportunity s1 = insertSellerOpportunity(v1.Id);
		expectVehicleSellerOpportunityID(v1, s1);
	}

	@isTest private static void testOpportunityWithChangedVehicle() {
		Vehicle__c v1 = insertTestVehicle();
		Opportunity s1 = insertSellerOpportunity(v1.Id);
		// change s1 to point to a new vehicle v2, and check that v1 points
		// to no seller opp and and v2 points to s1
		Vehicle__c v2 = insertTestVehicle();
		s1.Vehicle_ID__c = v2.Id;
		update s1;
		expectVehicleSellerOpportunityID(v2, s1);
		expectVehicleSellerOpportunityID(v1, null);
	}

	@isTest private static void testMultipleOpportunitiesOneVehicle() {
		Vehicle__c v1 = insertTestVehicle();
		Opportunity s1 = insertSellerOpportunity(v1.Id);
		// attempt to insert opp s2 pointing at v1 and expect an error 
		try {
			Opportunity s2 = insertSellerOpportunity(v1.Id);
			System.assert(false, 'was able to insert multiple sellers for a single vehicle');
		} catch (DmlException dme) {
			System.assert(dme.getMessage().contains('attempt to reference vehicle from seller opportunity'), dme.getMessage());
		}
	}

	@isTest private static void testVehicleWithDeletedSeller() {
		Vehicle__c v1 = insertTestVehicle();
		Opportunity s1 = insertSellerOpportunity(v1.Id);
		// delete s1 and assert that v points nowhere
		delete s1;
		expectVehicleSellerOpportunityID(v1, null);
	}

	@isTest private static void testMutipleOpportunitiesOneVehicleInsertBatch() {
		// check that we get failure when two opps in the same insert batch
		// point to the same vehicle 
		Vehicle__c v1 = insertTestVehicle();
		List<Opportunity> opps = new List<Opportunity>();
		opps.add(createSellerOpportunity(v1.Id));
		opps.add(createSellerOpportunity(v1.Id));
		try {
			insert opps;
			System.assert(false, 'was able to insert multiple sellers for same vehicle in a single batch');
		} catch (DmlException dme) {
			System.assert(dme.getMessage().contains('operation contains multiple assignments to vehicle'), dme.getMessage());
		}
	}

	@isTest private static void testMutipleOpportunitiesOneVehicleUpdateBatch() {
		// check that we get failure when two opps in the same update batch
		// point to the same vehicle 
		Vehicle__c v1 = insertTestVehicle();
		Vehicle__c v2 = insertTestVehicle();
		Opportunity s1 = insertSellerOpportunity(v1.Id);
		Opportunity s2 = insertSellerOpportunity(v2.Id);
		List<Opportunity> opps = new List<Opportunity>{s1, s2};
		Vehicle__c v3 = insertTestVehicle();
		s1.Vehicle_ID__c = v3.Id;
		s2.Vehicle_ID__c = v3.Id;
		try {
			update opps;
			System.assert(false, 'was able to update multiple sellers for same vehicle in a single batch');
		} catch (DmlException dme) {
			System.assert(dme.getMessage().contains('operation contains multiple assignments to vehicle'), dme.getMessage());
		}
	}

	@isTest private static void testBatchOperationsNoErrors() {
		// (regression) check that batch deletes do not encounter errors
		Test.startTest();
		List<Opportunity> oppsToDel = new List<Opportunity>();
		List<Vehicle__c> vehiclesToDel = new List<Vehicle__c>();
		for (Integer i = 0; i < 2; i++) {
			Vehicle__c vhToDel = insertTestVehicle();
			vehiclesToDel.add(vhToDel);
			Opportunity oppToDel = insertSellerOpportunity(vhToDel.Id);
			oppsToDel.add(oppToDel);
		}
		Test.stopTest();
		delete oppsToDel;
		// (regression) check that batch inserts do not encounter errors
		List<Vehicle__c> vehiclesToIns = new List<Vehicle__c>();
		for (Integer i = 0; i < 2; i++) {
			vehiclesToIns.add(createTestVehicle());
		}
		insert vehiclesToIns;
		List<Opportunity> oppsToIns = new List<Opportunity>();
		for (Vehicle__c vh : vehiclesToIns) {
			oppsToIns.add(createSellerOpportunity(vh.Id));
		}
		insert oppsToIns;
	}
}