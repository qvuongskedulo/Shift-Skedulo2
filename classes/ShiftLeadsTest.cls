@IsTest
class ShiftLeadsTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	// These are random VINs generated using randomvin.com.
	static final String TEST_VIN = '1FDUF5HT9BEA85529';
	static final String TEST_VIN_ALT = '5TDJKRFH7FS329509';

	static final String TEST_EMAIL = 'test@email.com';
	static final String TEST_PHONE = '123-456-7890';
	static final String TEST_EMAIL_ALT = 'alternative@email.com';
	static final String TEST_PHONE_ALT = '987-654-3210';
	static final String TEST_CONTACT_METHOD = 'Chat';
	static final String TEST_REQUESTED_TEST_DRIVE_LOCATION = 'TestLocation';
	static final String TEST_INITIAL_BUYER_OUTREACH = 'TestInitialBuyerOutreach';
	static final String TEST_HTTP_REFERRER = 'TestReferrer';
	static final String TEST_UTM_CAMPAIGN = 'TestUTMCampaign';
	static final String TEST_UTM_CONTENT = 'TestUTMContent';
	static final String TEST_UTM_SOURCE = 'TestUTMSource';
	static final String TEST_UTM_TERM = 'TestUTMTerm';
	static final String TEST_UTM_MEDIUM = 'TestUTMMedium';
	static final String TEST_INITIAL_BUYER_OUTREACH_ALT = TEST_INITIAL_BUYER_OUTREACH + 'Alternative';
	static final String TEST_HTTP_REFERRER_ALT = TEST_HTTP_REFERRER + 'Alternative';
	static final String TEST_UTM_CAMPAIGN_ALT = TEST_UTM_CAMPAIGN + 'Alternative';
	static final String TEST_UTM_CONTENT_ALT = TEST_UTM_CONTENT + 'Alternative';
	static final String TEST_UTM_SOURCE_ALT = TEST_UTM_SOURCE + 'Alternative';
	static final String TEST_UTM_TERM_ALT = TEST_UTM_TERM + 'Alternative';
	static final String TEST_UTM_MEDIUM_ALT = TEST_UTM_MEDIUM + 'Alternative';

	static final List<String> STAGE_NAMES_LEADS = new List<String>{
		ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS
	};
	static final List<String> STAGE_NAMES_LEADS_QUALIFIED = new List<String>{
		ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS,
		ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED
	};
	static final List<String> STAGE_NAMES_LEADS_QUALIFIED_LEADS = new List<String>{
		ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS,
		ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED,
		ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS
	};

	static ShiftTesting.SellerTestContext createVehicleWithOpportunity(String stageName, String vin) {
		ShiftTesting.SellerTestContext ctx = ShiftTesting.prepareSellerTestContext();
		ctx.opportunity.StageName = stageName;
		ctx.insertOpportunity();
		ctx.vehicle.VIN__c = vin;
		ctx.vehicle.Craigslist_Listing_Email__c = TEST_EMAIL;
		ctx.vehicle.Listing_Phone_Number__c = TEST_PHONE;
		ctx.vehicle.Needs_Repairs__c  = FALSE;
		ctx.vehicle.In_Transit__c = FALSE;
		ctx.vehicle.Paperwork_Missing__c = ShiftConstants.PAPERWORK_MISSING_NO;
		ctx.vehicle.Photos_Ready__c = TRUE;
		update ctx.vehicle;
		return ctx;
	}

	static ShiftTesting.SellerTestContext createVehicleWithOpportunity(String stageName) {
		return createVehicleWithOpportunity(stageName, TEST_VIN);
	}

	static ShiftTesting.SellerTestContext createVehicleWithOpportunity() {
		return createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE, TEST_VIN);
	}

	static ShiftTesting.SellerTestContext createAlternateVehicleWithOpportunity() {
		return createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE, TEST_VIN_ALT);
	}

	static Lead createLeadWithTestVINInquiry() {
		Lead l = ShiftTesting.createLead();
		l.VIN_Inquiry__c = TEST_VIN;
		return l;
	}

	static Lead createLeadWithTestCraigslistEmailInquiry() {
		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_CRAIGSLIST;
		l.Craigslist_Listing_Email_Inquiry__c = TEST_EMAIL;
		return l;
	}

	static Lead createLeadWithTestCraigslistPhoneNumberInquiry() {
		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_CRAIGSLIST;
		l.Craigslist_Listing_Phone_Number_Inquiry__c = TEST_PHONE;
		return l;
	}

	static Opportunity expectConvertedOpportunity(Lead l, Contact expectedContact) {
		Opportunity o = [SELECT Id, LeadSource, StageName, AccountId FROM Opportunity WHERE RecordType.Name = 'Buyer'];
		System.assertEquals(l.LeadSource, o.LeadSource);
		System.assert(o.AccountId != null);
		Contact c = [SELECT Id, FirstName, LastName FROM Contact WHERE AccountId = :o.AccountId];
		if (expectedContact == null) {
			System.assertEquals(l.FirstName, c.FirstName);
			System.assertEquals(l.LastName, c.LastName);
		} else {
			System.assertEquals(expectedContact.Id, c.Id);
		}
		return o;
	}

	static void expectTrackingData(Lead l, Opportunity o) {
		System.assertEquals(l.HTTP_Referrer__c, o.HTTP_Referrer__c);
		System.assertEquals(l.UTM_Campaign__c, o.UTM_Campaign__c);
		System.assertEquals(l.UTM_Content__c, o.UTM_Content__c);
		System.assertEquals(l.UTM_Source__c, o.UTM_Source__c);
		System.assertEquals(l.UTM_Term__c, o.UTM_Term__c);
		System.assertEquals(l.UTM_Medium__c, o.UTM_Medium__c);
	}

	static void expectTestDrive(Lead l, Test_Drive__c td) {
		System.assertEquals(l.Requested_Test_Drive_Time__c, td.Original_Time_Requested__c);
		System.assertEquals(l.Requested_Test_Drive_Location__c, td.Location__c);
		System.assertEquals(l.Requested_Test_Drive_Geolocation__latitude__s, td.Selected_Geolocation__latitude__s);
		System.assertEquals(l.Requested_Test_Drive_Geolocation__longitude__s, td.Selected_Geolocation__longitude__s);
	}

	static void expectCase(Boolean caseExpected, Opportunity o) {
		if (caseExpected) {
			Case supportCase = [SELECT AccountId, Status, OwnerId FROM Case WHERE Opportunity_ID__c = :o.Id];
			System.assertEquals(o.AccountId, supportCase.AccountId);
			System.assertEquals(ShiftConstants.CASE_STATUS_NEW, supportCase.Status);
			System.assertEquals(ShiftUsers.unownedUserId(), supportCase.OwnerId);
		} else {
			System.assertEquals(0, [SELECT COUNT() FROM Case WHERE Opportunity_ID__c = :o.Id]);
		}
	}

	static void expectCaseHasVehicle(Vehicle__c v, Opportunity o) {
		Case supportCase = [SELECT Vehicle_ID__c FROM Case WHERE Opportunity_ID__c = :o.Id];
		if (v == null) { 
			System.assertEquals(null, supportCase.Vehicle_ID__c);
		} else {
			System.assertEquals(v.Id, supportCase.Vehicle_ID__c);
		}
	}

	static void expectLeadCaseMatch(Lead l, Case c) {
		System.assertEquals(l.LeadSource, c.Source__c);
		System.assertEquals(l.Inquiry_Type__c, c.Inquiry_Type__c);
		System.assertEquals(l.Contact_Method__c, c.Origin);
		System.assertEquals(l.VIN_Inquiry__c, c.VIN_Inquiry__c);
		System.assertEquals(l.Requested_Test_Drive_Time__c, c.Requested_Test_Drive_Time__c);
		System.assertEquals(l.Requested_Test_Drive_Location__c, c.Requested_Test_Drive_Location__c);
		System.assertEquals(l.Craigslist_Listing_Email_Inquiry__c, c.Craigslist_Listing_Email_Inquiry__c);
		System.assertEquals(l.Craigslist_Listing_Phone_Number_Inquiry__c, c.Craigslist_Listing_Phone_Number_Inquiry__c);
		System.assert(c.Initial_Buyer_Outreach__c.contains(l.Initial_Email_Content__c));
		System.assert(c.Initial_Buyer_Outreach__c.contains(l.LeadSource));
	}

	@IsTest
	static void testAutoConversionWithNoVINInquiry() {
		createVehicleWithOpportunity();
		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_WORD_OF_MOUTH;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS);
		System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Interest__c]);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(true, o);
		expectCaseHasVehicle(null, o);
	}

	@IsTest
	static void testAutoConversionWithVINInquiry() {
		ShiftTesting.SellerTestContext ctx = createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_WORD_OF_MOUTH;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS);
		Vehicle_Interest__c vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(true, o);
		expectCaseHasVehicle(ctx.vehicle, o);
	}

	@IsTest
	static void testAutoConversionWithCraigslistEmail() {
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestCraigslistEmailInquiry();
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS);
		Vehicle_Interest__c vi = [
			SELECT
				Contact_When_Available_For_Sale__c,
				Contact_If_Deposit_Falls_Through__c,
				Contact_On_Price_Drop__c,
				Vehicle_ID__r.Craigslist_Listing_Email__c
			FROM Vehicle_Interest__c
		];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		System.assertEquals(l.Craigslist_Listing_Email_Inquiry__c, vi.Vehicle_ID__r.Craigslist_Listing_Email__c);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(true, o);
	}

	@IsTest
	static void testAutoConversionWithCraigslistPhoneNumber() {
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestCraigslistPhoneNumberInquiry();
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS);
		Vehicle_Interest__c vi = [
			SELECT
				Contact_When_Available_For_Sale__c,
				Contact_If_Deposit_Falls_Through__c,
				Contact_On_Price_Drop__c,
				Vehicle_ID__r.Listing_Phone_Number__c
			FROM Vehicle_Interest__c
		];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		System.assertEquals(l.Craigslist_Listing_Phone_Number_Inquiry__c, vi.Vehicle_ID__r.Listing_Phone_Number__c);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(true, o);
	}

	@IsTest
	static void testAutoConversionInquiryTypeHotBuyer() {
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED);
		Vehicle_Interest__c vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(false, o);
	}

	@IsTest
	static void testAutoConversionInquiryTypeVehicleQuestion() {
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED_LEADS);
		Vehicle_Interest__c vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(true, o);
	}

	@IsTest
	static void testAutoConversionInquiryTypeOffComingSoon() {
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_OFF_COMING_SOON;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED_LEADS);
		Vehicle_Interest__c vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(false, o);
	}

	@IsTest
	static void testAutoConversionInquiryTypeOffSalePending() {
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_OFF_SALE_PENDING;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED_LEADS);
		Vehicle_Interest__c vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(false, o);
	}

	@IsTest
	static void testAutoConversionInquiryTypeTestDrive() {
		createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL);
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_TEST_DRIVE;
		l.Requested_Test_Drive_Time__c = DateTime.now();
		l.Requested_Test_Drive_Location__c = TEST_REQUESTED_TEST_DRIVE_LOCATION;
		l.Requested_Test_Drive_Geolocation__latitude__s = 3.1415926;
		l.Requested_Test_Drive_Geolocation__longitude__s = 10.1234567;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED);
		Vehicle_Interest__c vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		Test_Drive__c td = [SELECT Original_Time_Requested__c, Location__c, Selected_Geolocation__latitude__s, Selected_Geolocation__longitude__s FROM Test_Drive__c];
		expectTestDrive(l, td);
		expectCase(true, o);
	}

	@IsTest
	static void testAutoConversionInquiryTypeTestDriveRejected() {
		createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL);
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_TEST_DRIVE_REJECTED;
		l.Requested_Test_Drive_Time__c = DateTime.now();
		l.Requested_Test_Drive_Location__c = TEST_REQUESTED_TEST_DRIVE_LOCATION;
		l.Requested_Test_Drive_Geolocation__latitude__s = 3.1415926;
		l.Requested_Test_Drive_Geolocation__longitude__s = 10.1234567;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED);
		Vehicle_Interest__c vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		Test_Drive__c td = [SELECT Original_Time_Requested__c, Location__c, Selected_Geolocation__latitude__s, Selected_Geolocation__longitude__s FROM Test_Drive__c];
		expectTestDrive(l, td);
		expectCase(true, o);
	}

	@IsTest
	static void testAutoConversionMultipleVehiclesWithSameVIN() {
		createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SOLD, TEST_VIN);
		Test.startTest();
		Vehicle__c v = createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE, TEST_VIN).vehicle;

		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED_LEADS);
		System.assertEquals(v.Id, [SELECT Vehicle_ID__c FROM Vehicle_Interest__c].Vehicle_ID__c);
		expectCase(true, o);
		Test.stopTest();
	}

	@IsTest
	static void testFailedAutoConversionMultipleActiveVehiclesWithSameVIN() {
		createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE, TEST_VIN);

		Test.startTest();
		createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE, TEST_VIN);

		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;

		ShiftTesting.expectInsertExceptionContains(l, 'multiple active vehicles');
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionWithExistingContactEmail() {
		Contact c = createVehicleWithOpportunity().contact;
		c.Email = TEST_EMAIL;
		update c;
		
		Test.startTest();
		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER;
		l.Email = TEST_EMAIL;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, c);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED);
		System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Interest__c]);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(false, o);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionWithExistingContactPhone() {
		Contact c = createVehicleWithOpportunity().contact;
		c.Phone = '123-456-7890';
		c.HomePhone = '234-567-8901';
		c.MobilePhone = '345-678-9012';
		update c;
	 
		Test.startTest();
		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER;
		l.Phone = c.HomePhone;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, c);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED);
		System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Interest__c]);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(false, o);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionMultipleContactsWithSameEmail() {
		Contact c1 = createVehicleWithOpportunity().contact;
		c1.Email = TEST_EMAIL;
		update c1;
		Account a2 = ShiftTesting.createAccount();
		insert a2;
		Contact c2 = ShiftTesting.createContact(a2);
		c2.Email = TEST_EMAIL;
		insert c2;

		Test.startTest();
		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER;
		l.Email = TEST_EMAIL;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, c1);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED);
		System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Interest__c]);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(false, o);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionMultipleContactsWithSamePhoneNumber() {
		String testPhone = '123-456-7890';
		Contact c1 = createVehicleWithOpportunity().contact;
		c1.Phone = testPhone;
		update c1;
		Contact c2 = ShiftTesting.createContact();
		c2.MobilePhone = testPhone;
		insert c2;

		Test.startTest();
		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER;
		l.Phone = testPhone;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, c1);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED);
		System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Interest__c]);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(false, o);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionDifferentMatchesOnEmailAndPhoneNumber() {
		String testPhone = '123-456-7890';
		Contact c1 = createVehicleWithOpportunity().contact;
		c1.Email = TEST_EMAIL;
		update c1;

		Test.startTest();
		Contact c2 = ShiftTesting.createContact();
		c2.MobilePhone = testPhone;
		insert c2;

		// Hitting query limits
		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER;
		l.Email = TEST_EMAIL;
		l.Phone = testPhone;
		insert l;
		Test.stopTest();

		Opportunity o = expectConvertedOpportunity(l, c1);
		System.assertEquals(ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED, o.StageName);
		ShiftTesting.expectStageChanges(o.Id, STAGE_NAMES_LEADS_QUALIFIED);
		System.assertEquals(0, [SELECT COUNT() FROM Vehicle_Interest__c]);
		System.assertEquals(0, [SELECT COUNT() FROM Test_Drive__c]);
		expectCase(false, o);
	}

	@IsTest
	static void testAutoConversionWithExistingBuyerOpportunity() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		ctx.contact.Email = TEST_EMAIL;
		update ctx.contact;

		Test.startTest();
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		l.Email = TEST_EMAIL;
		insert l;

		System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE RecordType.Name = 'Buyer']);
		Vehicle_Interest__c vi = [SELECT Buyer_Opportunity_ID__c FROM Vehicle_Interest__c];
		System.assertEquals(ctx.opportunity.Id, vi.Buyer_Opportunity_ID__c);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionWithExistingBuyerOpportunityWithOpenPurchase() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		ctx.contact.Email = TEST_EMAIL;
		update ctx.contact;
		Vehicle__c v = ctx.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		insert vo;
		ctx.setAndUpdateOpenPurchase(vo);

		Lead l = ShiftTesting.createLead();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER;
		l.Email = TEST_EMAIL;
		insert l;

		System.assertEquals(2, [SELECT COUNT() FROM Opportunity WHERE RecordType.Name = 'Buyer']);
	}

	@IsTest
	static void testAutoConversionWithMultipleExistingBuyerOpportunities() {
		ShiftTesting.BuyerTestContext ctx1 = ShiftTesting.prepareBuyerTestContext();
		ctx1.opportunity.CreatedDate = Date.today().addDays(-10);
		insert ctx1.opportunity;
		ctx1.contact.Email = TEST_EMAIL;
		update ctx1.contact;
		Vehicle__c v = ctx1.createAndInsertVehicle();
		Vehicle_Order__c vo = ctx1.createVehicleOrder(v);
		insert vo;
		ctx1.setAndUpdateOpenPurchase(vo);

		ShiftTesting.BuyerTestContext ctx2 = new ShiftTesting.BuyerTestContext();
		ctx2.opportunity = ShiftTesting.createBuyerOpportunity();
		ctx2.opportunity.AccountId = ctx1.account.Id;
		ctx2.opportunity.CreatedDate = Date.today().addDays(-7);
		insert ctx2.opportunity;

		ShiftTesting.BuyerTestContext ctx3 = new ShiftTesting.BuyerTestContext();
		ctx3.opportunity = ShiftTesting.createBuyerOpportunity();
		ctx3.opportunity.AccountId = ctx1.account.Id;
		ctx3.opportunity.CreatedDate = Date.today().addDays(-4);
		insert ctx3.opportunity;

		Test.startTest();
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		l.Email = TEST_EMAIL;
		insert l;

		System.assertEquals(3, [SELECT COUNT() FROM Opportunity WHERE RecordType.Name = 'Buyer']);
		Vehicle_Interest__c vi = [SELECT Buyer_Opportunity_ID__c FROM Vehicle_Interest__c];
		System.assertEquals(ctx2.opportunity.Id, vi.Buyer_Opportunity_ID__c);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionWithExistingVehicleInterest() {
		createVehicleWithOpportunity();
		Lead l1 = createLeadWithTestVINInquiry();
		l1.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l1.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		l1.Email = TEST_EMAIL;
		insert l1;

		Vehicle_Interest__c vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(!vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);

		Test.startTest();
		Lead l2 = createLeadWithTestCraigslistEmailInquiry();
		l2.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_OFF_COMING_SOON;
		l2.Email = TEST_EMAIL;
		insert l2;

		vi = [SELECT Contact_When_Available_For_Sale__c, Contact_If_Deposit_Falls_Through__c, Contact_On_Price_Drop__c FROM Vehicle_Interest__c];
		System.assert(vi.Contact_When_Available_For_Sale__c);
		System.assert(!vi.Contact_If_Deposit_Falls_Through__c);
		System.assert(vi.Contact_On_Price_Drop__c);
		Test.stopTest();
	}

	@IsTest
	static void testCaseCreationOnMultipleAutoConversions() {
		createVehicleWithOpportunity();
		Lead l1 = ShiftTesting.createLead();
		l1.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l1.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER;
		l1.Email = TEST_EMAIL;
		insert l1;
		Opportunity o = expectConvertedOpportunity(l1, null);
		expectCase(false, o);

		// Breaking up the test to get around governer limits
		Test.startTest();
		Lead l2 = createLeadWithTestVINInquiry();
		l2.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l2.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		l2.Email = TEST_EMAIL;
		l2.Contact_Method__c = TEST_CONTACT_METHOD;
		l2.VIN_Inquiry__c = TEST_VIN;
		l2.Requested_Test_Drive_Time__c = DateTime.now();
		l2.Requested_Test_Drive_Location__c = TEST_REQUESTED_TEST_DRIVE_LOCATION;
		l2.Craigslist_Listing_Email_Inquiry__c = TEST_EMAIL;
		l2.Craigslist_Listing_Phone_Number_Inquiry__c = TEST_PHONE;
		l2.Initial_Email_Content__c = TEST_INITIAL_BUYER_OUTREACH;
		insert l2;
		Case c = [
			SELECT
				Account.Id, Status, Source__c, Inquiry_Type__c, Origin, VIN_Inquiry__c,
				Requested_Test_Drive_Time__c, Requested_Test_Drive_Location__c, Craigslist_Listing_Email_Inquiry__c,
				Craigslist_Listing_Phone_Number_Inquiry__c, Initial_Buyer_Outreach__c
			FROM Case
			WHERE Opportunity_ID__c = :o.Id
		];
		System.assertEquals(o.AccountId, c.Account.Id);
		System.assertEquals(ShiftConstants.CASE_STATUS_NEW, c.Status);
		expectLeadCaseMatch(l2, c);

		Lead l3 = createLeadWithTestVINInquiry();
		l3.LeadSource = ShiftConstants.LEAD_SOURCE_WORD_OF_MOUTH;
		l3.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		l3.Email = TEST_EMAIL;
		l3.Initial_Email_Content__c = TEST_INITIAL_BUYER_OUTREACH_ALT;
		insert l3;
		c = [SELECT Account.Id, Status, Source__c, Initial_Buyer_Outreach__c FROM Case WHERE Opportunity_ID__c = :o.Id];
		System.assertEquals(o.AccountId, c.Account.Id);
		System.assertEquals(ShiftConstants.CASE_STATUS_NEEDS_ACTION, c.Status);
		System.assertEquals(l2.LeadSource, c.Source__c);
		System.assert(c.Initial_Buyer_Outreach__c.contains(l2.Initial_Email_Content__c));
		System.assert(c.Initial_Buyer_Outreach__c.contains(l2.LeadSource));
		System.assert(c.Initial_Buyer_Outreach__c.contains(l3.Initial_Email_Content__c));
		System.assert(c.Initial_Buyer_Outreach__c.contains(l3.LeadSource));
		Test.stopTest();
	}

	@IsTest
	static void testMultipleCaseCreation() {
		createVehicleWithOpportunity();
		Lead l1 = createLeadWithTestVINInquiry();
		l1.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l1.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		l1.Email = TEST_EMAIL;
		insert l1;

		Test.startTest();
		createAlternateVehicleWithOpportunity();
		
		Lead l2 = createLeadWithTestVINInquiry();
		l2.VIN_Inquiry__c = TEST_VIN_ALT;
		l2.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l2.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		l2.Email = TEST_EMAIL;
		insert l2;

		Opportunity o = expectConvertedOpportunity(l1, null);
		System.assertEquals(1, [SELECT COUNT() FROM Case WHERE Opportunity_ID__c = :o.Id AND VIN_Inquiry__c = :TEST_VIN]);
		System.assertEquals(1, [SELECT COUNT() FROM Case WHERE Opportunity_ID__c = :o.Id AND VIN_Inquiry__c = :TEST_VIN_ALT]);
		Test.stopTest();
	}

	@IsTest
	static void testTestDriveCaseCreation() {
		createVehicleWithOpportunity(ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL);
		Lead l1 = createLeadWithTestVINInquiry();
		l1.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l1.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION;
		insert l1;

		Test.startTest();
		Lead l2 = createLeadWithTestVINInquiry();
		l2.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l2.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_TEST_DRIVE;
		insert l2;
		System.assertEquals(2, [SELECT COUNT() FROM Case WHERE VIN_Inquiry__c = :TEST_VIN]);
		Test.stopTest();
	}

	@IsTest
	static void testSkipCaseCreationForVoiceLead() {
		Lead l = ShiftTesting.createLead();
		l.Contact_Method__c = ShiftConstants.LEAD_CONTACT_METHOD_VOICE;

		Test.startTest();
		insert l;
		System.assertEquals(0, [SELECT COUNT() FROM Case WHERE Origin = :ShiftConstants.LEAD_CONTACT_METHOD_VOICE]);
		Test.stopTest();
	}

	@IsTest
	static void testCaseCreationForChatLead() {
		Lead l = ShiftTesting.createLead();
		l.Contact_Method__c = ShiftConstants.LEAD_CONTACT_METHOD_CHAT;

		Test.startTest();
		insert l;
		System.assertEquals(1, [SELECT COUNT() FROM Case WHERE Origin = :ShiftConstants.LEAD_CONTACT_METHOD_CHAT]);
		Test.stopTest();
	}

	@IsTest
	static void testLeadEmailCarryOver() {
		Contact c = createVehicleWithOpportunity().contact;
		c.Phone = '123-456-7890';
		c.HomePhone = '234-567-8901';
		c.MobilePhone = '345-678-9012';
		update c;
 
		Test.startTest();
		Lead l = ShiftTesting.createLead();
		l.Phone = c.HomePhone;
		l.Email = TEST_EMAIL;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, c);
		Contact updatedContact = [SELECT Email FROM Contact WHERE AccountId = :o.AccountId];
		System.assertEquals(l.Email, updatedContact.Email);
		Test.stopTest();
	}

	@IsTest
	static void testLeadPhoneCarryOver() {
		Contact c = createVehicleWithOpportunity().contact;
		c.Email = TEST_EMAIL;
		update c;
		
		Test.startTest();
		Lead l = ShiftTesting.createLead();
		l.Email = TEST_EMAIL;
		l.Phone = TEST_PHONE;
		l.MobilePhone = TEST_PHONE;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, c);
		Contact updatedContact = [SELECT Phone, MobilePhone FROM Contact WHERE AccountId = :o.AccountId];
		System.assertEquals(l.Phone, updatedContact.Phone);
		System.assertEquals(l.MobilePhone, updatedContact.MobilePhone);
		Test.stopTest();
	}

	@IsTest
	static void testLeadOpportunityCarryOver() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		ctx.contact.Email = TEST_EMAIL;
		update ctx.contact;

		Test.startTest();
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.Email = TEST_EMAIL;
		l.HTTP_Referrer__c = TEST_HTTP_REFERRER;
		l.UTM_Campaign__c = TEST_UTM_CAMPAIGN;
		l.UTM_Content__c = TEST_UTM_CONTENT;
		l.UTM_Source__c = TEST_UTM_SOURCE;
		l.UTM_Term__c = TEST_UTM_TERM;
		l.UTM_Medium__c = TEST_UTM_MEDIUM;
		insert l;

		Opportunity o = [
			SELECT HTTP_Referrer__c, UTM_Campaign__c, UTM_Content__c, UTM_Source__c, UTM_Term__c, UTM_Medium__c
			FROM Opportunity
			WHERE RecordType.Name = 'Buyer' AND AccountId = :ctx.contact.AccountId
		];
		expectTrackingData(l, o);
		Test.stopTest();
	}

	@IsTest
	static void testLeadDoNotOverride() {
		ShiftTesting.BuyerTestContext ctx = ShiftTesting.createAndInsertBuyer();
		ctx.contact.Email = TEST_EMAIL_ALT;
		ctx.contact.Phone = TEST_PHONE_ALT;
		ctx.contact.MobilePhone = TEST_PHONE_ALT;
		ctx.opportunity.HTTP_Referrer__c = TEST_HTTP_REFERRER_ALT;
		ctx.opportunity.UTM_Campaign__c = TEST_UTM_CAMPAIGN_ALT;
		ctx.opportunity.UTM_Content__c = TEST_UTM_CONTENT_ALT;
		ctx.opportunity.UTM_Source__c = TEST_UTM_SOURCE_ALT;
		ctx.opportunity.UTM_Term__c = TEST_UTM_TERM_ALT;
		ctx.opportunity.UTM_Medium__c = TEST_UTM_MEDIUM_ALT;
		update ctx.contact;
		update ctx.opportunity;

		Test.startTest();
		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.Email = TEST_EMAIL;
		l.HTTP_Referrer__c = TEST_HTTP_REFERRER;
		l.UTM_Campaign__c = TEST_UTM_CAMPAIGN;
		l.UTM_Content__c = TEST_UTM_CONTENT;
		l.UTM_Source__c = TEST_UTM_SOURCE;
		l.UTM_Term__c = TEST_UTM_TERM;
		l.UTM_Medium__c = TEST_UTM_MEDIUM;
		insert l;

		Opportunity o = [
			SELECT AccountId, HTTP_Referrer__c, UTM_Campaign__c, UTM_Content__c, UTM_Source__c, UTM_Term__c, UTM_Medium__c
			FROM Opportunity
			WHERE RecordType.Name = 'Buyer' AND AccountId = :ctx.contact.AccountId
		];
		Contact updatedContact = [SELECT Email, Phone, MobilePhone FROM Contact WHERE AccountId = :o.AccountId];

		System.assertEquals(TEST_EMAIL_ALT, updatedContact.Email);
		System.assertEquals(TEST_PHONE_ALT, updatedContact.Phone);
		System.assertEquals(TEST_PHONE_ALT, updatedContact.MobilePhone);
		System.assertEquals(TEST_HTTP_REFERRER_ALT, o.HTTP_Referrer__c);
		System.assertEquals(TEST_UTM_CAMPAIGN_ALT, o.UTM_Campaign__c);
		System.assertEquals(TEST_UTM_CONTENT_ALT, o.UTM_Content__c);
		System.assertEquals(TEST_UTM_SOURCE_ALT, o.UTM_Source__c);
		System.assertEquals(TEST_UTM_TERM_ALT, o.UTM_Term__c);
		System.assertEquals(TEST_UTM_TERM_ALT, o.UTM_Term__c);
		Test.stopTest();
	}

	@IsTest
	static void testAutoConversionWithIncentiveToken() {
		Incentive_Program__c incentiveProgram = ShiftTesting.createIncentiveProgram();
		insert incentiveProgram;
		String incentiveToken = 'testToken';
		Incentive__c incentive = ShiftTesting.createIncentive(incentiveToken, incentiveProgram.Id);
		insert incentive;

		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_TEST_DRIVE;
		l.Requested_Test_Drive_Time__c = DateTime.now();
		l.Requested_Test_Drive_Location__c = TEST_REQUESTED_TEST_DRIVE_LOCATION;
		l.Requested_Test_Drive_Geolocation__latitude__s = 3.1415926;
		l.Requested_Test_Drive_Geolocation__longitude__s = 10.1234567;
		l.Incentive_Token__c = incentiveToken;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		Applied_Incentive__c appliedIncentive = [SELECT Id, Incentive_ID__c, Opportunity_ID__c FROM Applied_Incentive__c WHERE Opportunity_ID__c = :o.Id];
		System.assert(appliedIncentive != null, 'valid incentive not applied to opportunity converted from lead');
		System.assertEquals(appliedIncentive.Incentive_ID__c, incentive.Id);
		System.assertEquals(appliedIncentive.Opportunity_ID__c, o.Id);
	}

	@IsTest
	static void testAutoConversionWithInvalidIncentiveToken() {
		Incentive_Program__c incentiveProgram = ShiftTesting.createIncentiveProgram();
		insert incentiveProgram;
		String incentiveToken = 'testToken';
		Incentive__c incentive = ShiftTesting.createIncentive(incentiveToken, incentiveProgram.Id);
		insert incentive;

		createVehicleWithOpportunity();
		Lead l = createLeadWithTestVINInquiry();
		l.LeadSource = ShiftConstants.LEAD_SOURCE_DRIVESHIFT;
		l.Inquiry_Type__c = ShiftConstants.LEAD_INQUIRY_TYPE_TEST_DRIVE;
		l.Requested_Test_Drive_Time__c = DateTime.now();
		l.Requested_Test_Drive_Location__c = TEST_REQUESTED_TEST_DRIVE_LOCATION;
		l.Requested_Test_Drive_Geolocation__latitude__s = 3.1415926;
		l.Requested_Test_Drive_Geolocation__longitude__s = 10.1234567;
		l.Incentive_Token__c = incentiveToken;
		l.Email = incentive.Email__c;
		insert l;

		Opportunity o = expectConvertedOpportunity(l, null);
		List<Applied_Incentive__c> appliedIncentives = [SELECT Id, Incentive_ID__c, Opportunity_ID__c FROM Applied_Incentive__c WHERE Opportunity_ID__c = :o.Id];
		System.assert(appliedIncentives.isEmpty(), 'invalid incentive applied to opportunity');
	}
}