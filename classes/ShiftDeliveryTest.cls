@IsTest
class ShiftDeliveryTest {
	@TestSetup
	static void setup() { ShiftTesting.setup(); }

	static final String TEST_LOCATION = 'TestLocation';
	static final String TEST_NOTES = 'TestNotes';

	//Class to store Delivery and related Objects so that we can refer to
	//fields in related Objects without any additional query.
	//We need to verify fields on the related Opportunity.
	class TestDeliveryContext {
		Delivery__c delivery;
		Vehicle_Interest__c vehicleInterest;
		Opportunity buyerOpportunity;
		Vehicle__c vehicle;

		public TestDeliveryContext(Delivery__c d, Vehicle_Interest__c vi, Opportunity bo, Vehicle__c veh) {
			delivery = d;
			vehicleInterest = vi;
			buyerOpportunity = bo;
			vehicle = veh;
		}
	}

	static TestDeliveryContext createTestDelivery() {
		Account account = ShiftTesting.createAccount();
		insert account;
		Opportunity buyerOpportunity = ShiftTesting.createBuyerOpportunity();
		buyerOpportunity.AccountId = account.Id;
		insert buyerOpportunity;
		Vehicle__c vehicle = ShiftTesting.createVehicle();
		insert vehicle;
		Vehicle_Interest__c vehicleInterest = new Vehicle_Interest__c(
				Buyer_Opportunity_ID__c = buyerOpportunity.Id,
				Vehicle_ID__c = vehicle.Id
		);
		insert vehicleInterest;
		User testUser1 = ShiftTesting.insertTestUser();
		User testUser2 = ShiftTesting.insertTestUser();
		Delivery__c delivery = new Delivery__c(
			Delivery_By__c = testUser1.Id,
			Vehicle_Interest__c = vehicleInterest.id,
			Notes__c = TEST_NOTES,
			Scheduled_By__c = testUser2.Id,
			Scheduled_For__c = DateTime.now().addDays(2)
		);

		return new TestDeliveryContext(delivery, vehicleInterest, buyerOpportunity, vehicle);
	}

	static void assertCaseValues(TestDeliveryContext testDeliveryCtx) {
		Delivery__c delivery = testDeliveryCtx.delivery;
		Case newCase = [
				SELECT Case_Type__c, Delivery_By__c, Delivery_Notes__c, Delivery_Scheduled_By__c,
						Delivery_Scheduled_For__c, Location__c, Opportunity_ID__c, OwnerId,
						Status, Vehicle_Interest__c
				FROM Case
				WHERE Delivery__c =:delivery.Id
		];

		System.assertEquals(ShiftConstants.CASE_TYPE_DELIVERY_REQUEST, newCase.Case_Type__c);
		System.assertEquals(delivery.Delivery_By__c, newCase.Delivery_By__c);
		System.assertEquals(delivery.Notes__c, newCase.Delivery_Notes__c);
		System.assertEquals(delivery.Scheduled_For__c, newCase.Delivery_Scheduled_For__c);
		System.assertEquals(delivery.Location__c, newCase.Location__c);
		System.assertEquals(ShiftUsers.unownedUserId(), newCase.OwnerId);
		System.assertEquals(ShiftConstants.CASE_STATUS_NEW, newCase.Status);
		System.assertEquals(delivery.Vehicle_Interest__c, newCase.Vehicle_Interest__c);
		System.assertEquals(testDeliveryCtx.buyerOpportunity.Id, newCase.Opportunity_ID__c);
	}

	@IsTest
	static void testAutoConversionWithAllFields() {
		TestDeliveryContext testDeliveryCtx = createTestDelivery();
		Delivery__c delivery = testDeliveryCtx.delivery;
		delivery.Location__c = TEST_LOCATION;
		delivery.Original_Time_Requested__c = DateTime.now();

		Test.startTest();
		insert delivery;
		assertCaseValues(testDeliveryCtx);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionMissingLocation() {
		TestDeliveryContext testDeliveryCtx = createTestDelivery();
		Delivery__c delivery = testDeliveryCtx.delivery;
		delivery.Original_Time_Requested__c = DateTime.now();

		Test.startTest();
		insert delivery;
		assertCaseValues(testDeliveryCtx);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionMissingRequestTime() {
		TestDeliveryContext testDeliveryCtx = createTestDelivery();
		Delivery__c delivery = testDeliveryCtx.delivery;
		delivery.Location__c = TEST_LOCATION;

		Test.startTest();
		insert delivery;
		assertCaseValues(testDeliveryCtx);
		Test.stopTest();
	}

}