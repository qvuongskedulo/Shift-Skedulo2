@IsTest
class ShiftCasesTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	static ShiftTesting.BuyerTestContext setupOpportunity() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.opportunity.StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS;
		insert ctx.opportunity;
		return ctx;
	}

	static ShiftTesting.BuyerTestContext setupOpportunityWithCustomerExperienceRepresentative(User customerExperienceRepresentative) {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.prepareBuyerTestContext();
		ctx.opportunity.StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS;
		ctx.opportunity.Customer_Experience_Representative__c = customerExperienceRepresentative.Id;
		insert ctx.opportunity;
		return ctx;
	}

	static Case setupCase(Id opportunityId, Id caseOwnerId, String caseType) {
		Case c = new Case(
			OwnerId = caseOwnerId,
			Opportunity_ID__c = opportunityId,
			Case_Type__c = caseType
		);
		insert c;
		return c;
	}

	static void expectCustomerExperienceRepresentativeForCaseType (String caseType, User u, Id expectedUserId) {
		ShiftTesting.BuyerTestContext ctx = setupOpportunity();
		Case c = setupCase(ctx.opportunity.Id, ShiftUsers.unownedUserId(), caseType);
		c.OwnerId = u.id;
		update c;

		ShiftTesting.expectOpportunityCustomerExperienceRepresentatitve(ctx.opportunity.Id, expectedUserId);
	}

	static void expectCustomerExperienceRepresentativeForInvalidCaseType (String caseType) {
		User u1 = ShiftTesting.insertTestUser();
		expectCustomerExperienceRepresentativeForCaseType(caseType, u1, null);
	}

	static void expectCustomerExperienceRepresentativeForValidCaseType(String caseType) {
		User u1 = ShiftTesting.insertTestUser();
		expectCustomerExperienceRepresentativeForCaseType(caseType, u1, u1.id);
	}

	static Case setupDefaultCase(Id opportunityId, Id caseOwnerId) {
		return setupCase(opportunityId, caseOwnerId, ShiftConstants.CASE_TYPE_SHIFT_TEST_DRIVE_REQUEST);
	}

	@IsTest
	static void testNewCaseWithUnownedUserAndExisitngRepIsNull() {
		ShiftTesting.BuyerTestContext ctx = setupOpportunity();
		Case c = setupDefaultCase(ctx.opportunity.Id, ShiftUsers.unownedUserId());
		ShiftTesting.expectOpportunityCustomerExperienceRepresentatitve(ctx.opportunity.Id, null);
	}

	@IsTest
	static void testNewCaseWithKnownUserAndExistingRepIsNull() {
		ShiftTesting.BuyerTestContext ctx = setupOpportunity();
		User u = ShiftTesting.insertTestUser();
		Case c = setupDefaultCase(ctx.opportunity.Id, u.Id);
		ShiftTesting.expectOpportunityCustomerExperienceRepresentatitve(ctx.opportunity.Id, u.Id);
	}

	@IsTest
	static void testNewCaseWithKnownUserAndExistingRepIsNotNull() {
		User u1 = ShiftTesting.insertTestUser();
		ShiftTesting.BuyerTestContext ctx = setupOpportunityWithCustomerExperienceRepresentative(u1);
		Case c = setupDefaultCase(ctx.opportunity.Id, ShiftTesting.insertTestUser().Id);
		ShiftTesting.expectOpportunityCustomerExperienceRepresentatitve(ctx.opportunity.Id, u1.Id);
	}

	@IsTest
	static void testUpdateCaseFromUnknownUserToKnownAndExistingRepIsNull() {
		ShiftTesting.BuyerTestContext ctx = setupOpportunity();
		Case c = setupDefaultCase(ctx.opportunity.Id, ShiftUsers.unownedUserId());
		User u = ShiftTesting.insertTestUser();
		c.OwnerId = u.id;
		update c;

		ShiftTesting.expectOpportunityCustomerExperienceRepresentatitve(ctx.opportunity.Id, u.Id);
	}

	@IsTest
	static void testUpdateCaseFromUnknownUserToKnownAndExistingRepIsNotNull() {
		User u1 = ShiftTesting.insertTestUser();
		ShiftTesting.BuyerTestContext ctx = setupOpportunityWithCustomerExperienceRepresentative(u1);
		Case c = setupDefaultCase(ctx.opportunity.Id, ShiftUsers.unownedUserId());
		c.OwnerId = ShiftTesting.insertTestUser().id;
		update c;

		ShiftTesting.expectOpportunityCustomerExperienceRepresentatitve(ctx.opportunity.Id, u1.Id);
	}

	@IsTest
	static void testUpdateCaseFromKnownUserToKnownAndExistingRepIsNotNull() {
		ShiftTesting.BuyerTestContext ctx = setupOpportunity();
		User u1 = ShiftTesting.insertTestUser();
		Case c = setupDefaultCase(ctx.opportunity.Id, u1.Id);
		c.OwnerId = ShiftTesting.insertTestUser().id;
		update c;

		ShiftTesting.expectOpportunityCustomerExperienceRepresentatitve(ctx.opportunity.Id, u1.Id);
	}

	@IsTest
	static void testShiftTestDriveRequestRejectedCaseType() {
		expectCustomerExperienceRepresentativeForValidCaseType(ShiftConstants.CASE_TYPE_SHIFT_TEST_DRIVE_REQUEST_REJECTED);
	}

	@IsTest
	static void testShiftVehicleQuestionCaseType() {
		expectCustomerExperienceRepresentativeForValidCaseType(ShiftConstants.CASE_TYPE_SHIFT_VEHICLE_QUESTION);	
	}

	@IsTest
	static void testThirdPartyListingSiteVehicleQuestionCaseType() {
		expectCustomerExperienceRepresentativeForValidCaseType(ShiftConstants.CASE_TYPE_THIRD_PARTY_LISTING_SITE_VEHICLE_QUESTION);	
	}

	@IsTest
	static void testAutomatedPickupRequestCaseType() {
		expectCustomerExperienceRepresentativeForInvalidCaseType(ShiftConstants.CASE_TYPE_AUTOMATED_PICKUP_REQUEST);
	}

	@IsTest
	static void testCraigslistFollowUpCaseType() {
		expectCustomerExperienceRepresentativeForInvalidCaseType(ShiftConstants.CASE_TYPE_CRAIGSLIST_FOLLOW_UP);
	}
}