@IsTest
public class ShiftTesting {
	public static final String REGION_SHIFT_KEY_TESTING = 'testing';
	public static final String REGION_TIMEZONE_TESTING = 'America/Testing';
	public static final String REGION_NAME_TESTING = 'Test Region';
	public static final String SUBREGION_NAME_TESTING = 'Test Subregion';
	public static final String PARKING_LOT_NAME_TESTING = 'Test Parking Lot';
	public static final String PARKING_LOT_ADDRESS_TESTING = '123 Testing Street';

	public static final String SHIFT_COMPANY_ACCOUNT_TEST_NAME = 'Shift Company (Testing)';

	public static final String INCENTIVE_PROGRAM_PAYOUT_METHOD_AMAZON_GIFT_CARD = 'Amazon Gift Card';

	private static Id lazyTestRegionId;
	private static Id shiftCompanyAccountId;

	private static void ensureCompanyAccount() {
		String expctName = SHIFT_COMPANY_ACCOUNT_TEST_NAME;
		List<Account> accts = [SELECT Id FROM Account WHERE Name = :expctName];
		if (!accts.isEmpty()) {
			System.assertEquals(1, accts.size());
			shiftCompanyAccountId = accts.get(0).Id;
			return;
		}
		Account acct = new Account(Name = expctName, Shift_key__c = ShiftConstants.ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY);
		insert acct;
		shiftCompanyAccountId = acct.Id;
	}

	// TODO
	// Memoize in a Map so that further lookups are free, however precludes changing ProfileIDs between tests which
	// doesn't effect any existing tests but may be unintended behavior for future test cases
	private static void fillUserFields(String profileName, User u) {
		u.ProfileId = [SELECT Id FROM Profile WHERE Name = :profileName].Id;
		u.TimeZoneSidKey = 'GMT';
		u.LocaleSidKey = 'en_US';
		u.EmailEncodingKey = 'UTF-8';
		u.LanguageLocaleKey = 'en_US';
		u.Alias = ShiftUtil.randomStringLowercaseAlphanum(8);
		u.CommunityNickname = ShiftUtil.randomStringLowercaseAlphanum(40);
	}

	public static User createBaseUser() {
		String email = 'test-user-' + ShiftUtil.randomStringLowercaseAlphanum(15) + '@invalid.invalid';
		User u = new User(
				FirstName = ShiftUtil.randomStringLowercaseAlphanum(8),
				LastName = ShiftUtil.randomStringLowercaseAlphanum(8),
				Username = email,
				Email = email
		);
		return u;
	}

	// Does not insert; only creates and initializes a valid User object
	public static User createTestUser() {
		User u = createBaseUser();
		fillUserFields('System Administrator', u);
		return u;
	}

	public static User createISRInboundUser() {
		User u = createBaseUser();
		fillUserFields(ShiftConstants.PROFILE_NAME_INSIDE_SALES_INBOUND, u);
		return u;
	}

	public static User createISROutboundUser() {
		User u = createBaseUser();
		fillUserFields(ShiftConstants.PROFILE_NAME_INSIDE_SALES_OUTBOUND, u);
		return u;
	}

	public static Shift_Contract__c createAndInsertShiftContract(Id opportunityId) {
		Shift_Contract__c contract = new Shift_Contract__c(Opportunity_ID__c = opportunityId);
		insert contract;
		return contract;
	}

	public static User insertTestUser() {
		return insertTestUsers(1)[0];
	}

	public static List<User> insertTestUsers(Integer numToCreate) {
		List<User> users = new List<User>();

		for (Integer i = 0; i < numToCreate; i++) {
			users.add(createTestUser());
		}
		insert users;

		return users;
	}


	private static void ensureKeyedUser(String profileName, User partialUser) {
		if ([SELECT COUNT() FROM User WHERE Shift_Key__c = :partialUser.Shift_Key__c] > 0) {
			return;
		}
		fillUserFields(profileName, partialUser);
		insert partialUser;
	}

	private static void ensureCommunityUser(User partialUser) {
		Contact ct = new Contact(
			LastName = partialUser.LastName,
			Email = partialUser.Email,
			AccountId = shiftCompanyAccountId
		);
		insert ct;

		partialUser.ContactId = ct.Id;
		ensureKeyedUser('Community API', partialUser);
	}

	private static void ensureSystemUsers() {
		ensureKeyedUser('System Administrator', new User(
			UserName = 'salesforce-api-user-test@driveshift.com',
			Email = 'salesforce-api-user-test@driveshift.com',
			LastName = 'APIUser',
			Shift_Key__c = 'api-user'
		));
		ensureCommunityUser(new User(
			UserName = 'salesforce-default-owner-test@driveshift.com',
			Email = 'salesforce-default-owner-test@driveshift.com',
			LastName = 'Unowned',
			Shift_Key__c = 'unowned'
		));
	}

	public static Parking_Lot__c createParkingLot(String name, String address, Id regionId, Boolean isRegionPrimary) {
		return new Parking_Lot__c(
			Name = name,
			Address__c = address,
			Region_ID__c = regionId,
			Is_Region_Primary__c = isRegionPrimary,
			Geolocation__Latitude__s = 3.14159,
			Geolocation__Longitude__s = 2.71828
		);
	}

	public static Parking_Lot__c createRandomParkingLot(Id regionId, Boolean isRegionPrimary) {
		return createParkingLot(ShiftUtil.randomStringLowercaseAlphanum(8), ShiftUtil.randomStringLowercaseAlphanum(8), regionId, isRegionPrimary);
	}

	private static void insertTestRegionData() {
		Region__c region = new Region__c(
			Name = REGION_NAME_TESTING,
			Shift_Key__c = REGION_SHIFT_KEY_TESTING,
			Timezone__c = REGION_TIMEZONE_TESTING
		);
		insert region;
		insert new Subregion__c(
			Name = SUBREGION_NAME_TESTING,
			Region_ID__c = region.Id
		);
		insert createParkingLot(ShiftTesting.PARKING_LOT_NAME_TESTING, ShiftTesting.PARKING_LOT_ADDRESS_TESTING, region.Id, true);
	}

	public static void setup() {
		ensureCompanyAccount();
		ensureSystemUsers();
		insertTestRegionData();
	}

	public static Id getTestRegionId() {
		if (lazyTestRegionId == null) {
			lazyTestRegionId = [SELECT Id FROM Region__c WHERE Shift_Key__c = :REGION_SHIFT_KEY_TESTING].Id;
		}
		return lazyTestRegionId;
	}

	public static Lead createLead() {
		return new Lead(
			FirstName = 'First' + ShiftUtil.randomStringLowercaseAlphanum(8),
			LastName = 'Last' + ShiftUtil.randomStringLowercaseAlphanum(8),
			Company = 'Company' + ShiftUtil.randomStringLowercaseAlphanum(8),
			Region_ID__r = new Region__c(Shift_Key__c = REGION_SHIFT_KEY_TESTING)
		);
	}

	public static Account createAccount() {
		return new Account(Name = 'Test Account ' + ShiftUtil.randomStringLowercaseAlphanum(16));
	}

	public static Contact createContact() {
		return new Contact(
			FirstName = 'First' + ShiftUtil.randomStringLowercaseAlphanum(8),
			LastName = 'Last' + ShiftUtil.randomStringLowercaseAlphanum(8)
		);
	}

	public static Contact createContactWithRandomEmail() {
		return new Contact(
			FirstName = 'First' + ShiftUtil.randomStringLowercaseAlphanum(8),
			LastName = 'Last' + ShiftUtil.randomStringLowercaseAlphanum(8),
			Email = ShiftUtil.randomStringLowercaseAlphanum(10) + '@' + ShiftUtil.randomStringLowercaseAlphanum(5) + '.com'
		);
	}

	public static Contact createContact(Account acct) {
		Contact res = createContact();
		res.AccountId = acct.Id;
		return res;
	}

	public static Vehicle__c createVehicle() {
		return new Vehicle__c(
			Year__c = 2015,
			Make__c = 'Toyota',
			Model__c = 'Camry',
			Listing_Region_ID__r = new Region__c(Shift_Key__c = REGION_SHIFT_KEY_TESTING)
		);
	}

	public static Opportunity createSellerOpportunity() {
		RecordType recType =
			[SELECT ID FROM RecordType WHERE DeveloperName = 'Seller' AND SObjectType = 'Opportunity'];
		return new Opportunity(
			CloseDate = Date.today().addDays(60),
			RecordTypeId = recType.Id,
			Region_ID__r = new Region__c(Shift_Key__c = REGION_SHIFT_KEY_TESTING),
			StageName = ShiftConstants.SELLER_OPPORTUNITY_STAGE_LEADS
		);
	}

	public static Opportunity createBuyerOpportunity() {
		RecordType recType =
			[SELECT ID FROM RecordType WHERE DeveloperName = 'Buyer' AND SObjectType = 'Opportunity'];
		return new Opportunity(
			CloseDate = Date.today().addDays(60),
			RecordTypeId = recType.Id,
			StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_QUALIFIED
		);
	}

	public static Region__c createRandomRegion(String prefix) {
		return new Region__c(
				Name = prefix + ShiftUtil.randomStringLowercaseAlphanum(8),
				Shift_Key__c = ShiftUtil.randomStringLowercaseAlphanum(8),
				Timezone__c = ShiftTesting.REGION_TIMEZONE_TESTING
		);
	}

	public static Account selectCommunityAccount() {
		return [
			SELECT Id, Name, Shift_Key__c
			FROM Account
			WHERE Shift_Key__c = :ShiftConstants.ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY
		];
	}

	public static Incentive__c createIncentive(String token, Id programId, String email) {
	  return new Incentive__c(
	    Token__c = token,
	    Email__c = email,
	    Incentive_Program_ID__c = programId
	  );
	}

	public static Incentive__c createIncentive(String token, Id programId) {
	  return createIncentive(token, programId, 'incentive-testing-' + ShiftUtil.randomStringLowercaseAlphanum(5) + '@shift.com');
	}

	public static Applied_Incentive__c createAppliedIncentive(Id opportunityId, Id incentiveId) {
		return new Applied_Incentive__c(
			Opportunity_ID__c = opportunityId,
			Incentive_ID__c = incentiveId
		);
	}

	public static Incentive_Program__c createIncentiveProgram() {
	  return new Incentive_Program__c(
	    Name = ShiftUtil.randomStringLowercaseAlphanum(10),
	    Shift_Key__c = ShiftUtil.randomStringLowercaseAlphanum(10),
	    Type__c = 'Referral Program',
	    Referrer_Payout__c = 100.00,
	    Referrer_Payout_Method__c = INCENTIVE_PROGRAM_PAYOUT_METHOD_AMAZON_GIFT_CARD,
	    Payout__c = 100.00,
	    Payout_Method__c = INCENTIVE_PROGRAM_PAYOUT_METHOD_AMAZON_GIFT_CARD
	  );
	}
	
	// This automatically changes the vehicle's seller opportunity's stage to Handover.
	public static void prepareVehicleForHandover(Vehicle__c v) {
		BuyerTestContext ctx = createAndInsertBuyer();
		Vehicle_Order__c vo = ctx.createVehicleOrder(v);
		insert vo;
		ctx.setAndUpdateOpenPurchase(vo);
	}

	public abstract class OpportunityTestContext {
		public Account account;
		public Contact contact;
		public Opportunity opportunity;

		public void prepare() {
			this.account = createAccount();
			insert this.account;
			this.contact = createContact(this.account);
			insert this.contact;
		}

		public void insertOpportunity() {
			insert this.opportunity;
		}
	}

	public class SellerTestContext extends OpportunityTestContext {
		public Vehicle__c vehicle;

		public VehicleTester newVehicleTester() {
			return new VehicleTester(this.vehicle);
		}

		public Shift_Contract__c signSellerContract() {
			Shift_Contract__c sellerContract = ShiftTesting.createAndInsertShiftContract(this.opportunity.Id);
			this.opportunity.Seller_Contract_ID__c = sellerContract.Id;
			sellerContract.Signed_On__c = Date.today();
			update sellerContract;
			return sellerContract;
		}
	}

	public static SellerTestContext prepareSellerTestContext() {
		SellerTestContext ctx = new SellerTestContext();
		ctx.prepare();
		ctx.vehicle = createVehicle();
		insert ctx.vehicle;
		ctx.opportunity = createSellerOpportunity();
		ctx.opportunity.Vehicle_ID__c = ctx.vehicle.Id;
		ctx.opportunity.AccountId = ctx.account.Id;
		return ctx;
	}

	public static SellerTestContext createAndInsertSeller() {
		SellerTestContext ctx = prepareSellerTestContext();
		ctx.insertOpportunity();
		return ctx;
	}

	public class BuyerTestContext extends OpportunityTestContext {
		public Vehicle__c createAndInsertVehicle() {
			Vehicle__c vehicle = createVehicle();
			insert vehicle;
			return vehicle;
		}

		public Vehicle_Order__c createVehicleOrder(Vehicle__c vehicle) {
			return new Vehicle_Order__c(
				Buyer_Opportunity_ID__c = this.opportunity.Id,
				Vehicle_ID__c = vehicle.Id
			);
		}

		public Payment__c createPayment(Vehicle_Order__c vehicleOrder) {
			return new Payment__c(
				Vehicle_Order_ID__c = vehicleOrder.Id
			);
		}

		public void setAndUpdateOpenPurchase(Vehicle_Order__c vo) {
			setOpenPurchase(vo);
			update vo;
		}

		public void setOpenPurchase(Vehicle_Order__c vo) {
			vo.Final_Sale_Price__c = 10000.00;
			vo.Taxes_And_Registration__c = 1000.00;
			vo.Vehicle_Sale_Complete__c = true;
			insert createPayment(vo);
		}

		public void setReturnedPurchase(Vehicle_Order__c vo) {
			setOpenPurchase(vo);
			vo.Vehicle_Sale_Complete__c = true;
			vo.Returned_On__c = Date.today();
			vo.Returned_Reason__c = ShiftConstants.VEHICLE_ORDER_RETURNED_REASON_BUYERS_REMORSE;
		}
	}

	public static BuyerTestContext prepareBuyerTestContext() {
		BuyerTestContext ctx = new BuyerTestContext();
		ctx.prepare();
		ctx.opportunity = createBuyerOpportunity();
		ctx.opportunity.AccountId = ctx.account.Id;
		return ctx;
	}

	public static BuyerTestContext createAndInsertBuyer() {
		BuyerTestContext ctx = prepareBuyerTestContext();
		ctx.insertOpportunity();
		return ctx;
	}

	public static void expectExceptionContains(Exception e, String substring) {
		if (!e.getMessage().contains(substring)) {
			throw e;
		}
	}

	public static void expectInsertExceptionContains(SObject obj, String substring) {
		try {
			insert obj;
			System.assert(false, 'was able to insert: ' + obj);
		} catch (DmlException e) {
			ShiftTesting.expectExceptionContains(e, substring);
		}
	}

	public static void expectUpdateExceptionContains(SObject obj, String substring) {
		try {
			update obj;
			System.assert(false, 'was able to update: ' + obj);
		} catch (DmlException e) {
			ShiftTesting.expectExceptionContains(e, substring);
		}
	}

	public static void expectInsertExceptionContains(List<SObject> objs, String substring) {
		try {
			insert objs;
			System.assert(false, 'was able to insert: ' + objs);
		} catch (DmlException e) {
			ShiftTesting.expectExceptionContains(e, substring);
		}
	}

	public static void expectUpdateExceptionContains(List<SObject> objs, String substring) {
		try {
			update objs;
			System.assert(false, 'was able to update: ' + objs);
		} catch (DmlException e) {
			ShiftTesting.expectExceptionContains(e, substring);
		}
	}

	public static void insertBulkAndVerifyFailures(List<SObject> toInsert, List<String> expectedErrorMessages) {
		List<Database.SaveResult> insertResults = Database.insert(toInsert, false);

		for (Integer i = 0; i < toInsert.size(); i++) {
			Database.SaveResult saveResult = insertResults[i];
			String expectedError = expectedErrorMessages[i];

			if (expectedError == null) {
				System.assert(saveResult.isSuccess(), saveResult.getErrors());
			} else {
				System.assert(!saveResult.isSuccess(), expectedError);

				for (Database.Error error : saveResult.getErrors()) {
					if (!error.getMessage().contains(expectedError)) {
						System.assert(false, 'Different error received than expected; expected: ' + expectedError + '; received: ' + error.getMessage());
					}
				}
			}
		}
	}

	public static void expectOpportunityStage(Id opportunityId, String expectedStage) {
		System.assertEquals(expectedStage, [SELECT StageName FROM Opportunity WHERE Id = :opportunityId].StageName);
	}

	public static void expectOpportunityCustomerExperienceRepresentatitve(Id opportunityId, Id expectedUserId) {
		System.assertEquals(expectedUserId, [SELECT Customer_Experience_Representative__c FROM Opportunity WHERE Id = :opportunityId].Customer_Experience_Representative__c);
	}

	public static void expectStageChanges(Id opportunityId, List<String> expectedStageNames) {
		List<Shift_Stage_Change__c> actualStageChanges = [
			SELECT From_Stage__c, To_Stage__c
			FROM Shift_Stage_Change__c
			WHERE Opportunity_ID__c = :opportunityId
		];
		if (actualStageChanges.isEmpty()) {
			System.assert(expectedStageNames.isEmpty(), 'No stage changes for opportunity ' + opportunityId + ', but expected: ' + expectedStageNames);
		}
		System.assertEquals(expectedStageNames.size(), actualStageChanges.size());
		Set<Shift_Stage_Change__c> actualStageChangeSet = new Set<Shift_Stage_Change__c>();
		for (Shift_Stage_Change__c actualStageChange : actualStageChanges) {
			actualStageChangeSet.add(new Shift_Stage_Change__c(From_Stage__c = actualStageChange.From_Stage__c, To_Stage__c = actualStageChange.To_Stage__c));
		}
		System.assert(actualStageChangeSet.contains(new Shift_Stage_Change__c(From_Stage__c = null, To_Stage__c = expectedStageNames[0])), actualStageChangeSet);
		Shift_Stage_Change__c expectedStageChange;
		for (Integer i = 0; i < expectedStageNames.size() - 1; i++) {
			expectedStageChange = new Shift_Stage_Change__c(From_Stage__c = expectedStageNames[i], To_Stage__c = expectedStageNames[i + 1]);
			System.assert(actualStageChangeSet.contains(expectedStageChange), 'Missing stage change from ' + expectedStageNames[i] + ' to ' + expectedStageNames[i + 1]);
		}

		// TODO(max.woghiren): Find a way to assert creation order, rather than just
		// exclusive existence (https://shift.phacility.com/T1968).
		// The commented implementation below does this, but is subject to error
		// when multiple stage changes have the same CreatedDate.
		// List<Shift_Stage_Change__c> actualStageChanges = [
		// 	 SELECT From_Stage__c, To_Stage__c
		//	 FROM Shift_Stage_Change__c
		//	 WHERE Opportunity_ID__c = :opportunityId
		//	 ORDER BY CreatedDate ASC
		// ];
		// if (actualStageChanges.isEmpty()) {
		//	 System.assert(expectedStageNames.isEmpty(), 'No stage changes for opportunity ' + opportunityId + ', but expected: ' + expectedStageNames);
		// }
		// System.assertEquals(expectedStageNames.size(), actualStageChanges.size());
		// System.assert(actualStageChanges[0].From_Stage__c == null);
		// for (Integer i = 0; i < expectedStageNames.size(); i++) {
		// 	System.assertEquals(expectedStageNames[i], actualStageChanges[i].To_Stage__c, 'Stage change at index ' + i + ' on opportunity ' + opportunityId + ' has unexpected To_Stage');
		// }
	}

	public static void setOpenDeposit(Vehicle_Order__c vo) {
		// The formula that determines whether a deposit is open
		// checks for this field to be non-null.
		vo.Deposit_Accepted_On__c = Date.today();
	}

	public static void setReturnedDeposit(Vehicle_Order__c vo) {
		// The formula that determines whether a deposit exists and is returned
		// checks for these fields, respectively, to be non-null.
		vo.Deposit_Accepted_On__c = Date.today();
		vo.Deposit_Returned_Reason__c = ShiftConstants.VEHICLE_ORDER_DEPOSIT_RETURNED_REASON_OTHER;
	}

	public class TaskExpector {
		public Task task;

		public TaskExpector(Task task) { this.task = task; }

		public TaskExpector sync() {
			task = [
				SELECT
					Id, Status, OwnerId, Subject, Description, Team__c,
					Workflow_Identifier__c, Workflow_Version__c, Region_ID__c
				FROM Task
				WHERE Id = :task.Id
			];
			return this;
		}

		public TaskExpector expectStatus(String expect) {
			System.assertEquals(expect, task.Status);
			return this;
		}

		public TaskExpector expectNotStarted() {
			return expectStatus(ShiftConstants.TASK_STATUS_NOT_STARTED);
		}

		public TaskExpector expectTeam(String expect) {
			System.assertEquals(expect, task.Team__c);
			return this;
		}

		public TaskExpector expectSubject(String expect) {
			System.assertEquals(expect, task.Subject);
			return this;
		}

		public TaskExpector expectDescription(String expect) {
			System.assertEquals(expect, task.Description);
			return this;
		}

		public TaskExpector expectRegion(Id expect) {
			System.assertEquals(expect, task.Region_ID__c);
			return this;
		}

		public TaskExpector expectWorkflowIdentifier(String expect) {
			System.assertEquals(expect, task.Workflow_Identifier__c);
			return this;
		}

		public TaskExpector expectWorkflowVersion(Integer expect) {
			System.assertEquals(expect, task.Workflow_Version__c);
			return this;
		}

		public TaskExpector updateStatus(String status) {
			task.Status = status;
			update task;
			return this;
		}

		public TaskExpector updateComplete() {
			return updateStatus(ShiftConstants.TASK_STATUS_COMPLETED);
		}
	}

	public class VehicleTester {
		public Vehicle__c vehicle;

		public VehicleTester (Vehicle__c vehicle) { this.vehicle = vehicle; }

		public VehicleTester sync() {
			// for now, we pull back just what we need + Id?
			vehicle = [
				SELECT Id, Can_Be_Listed__c
				FROM Vehicle__c
				WHERE Id = :vehicle.Id
			];
			return this;
		 }

		public VehicleTester expectCanBeListed(Boolean canBeListed) {
			System.assertEquals(canBeListed, vehicle.Can_Be_Listed__c);
			return this;
		}

		public VehicleTester updatePaperworkMissing(String paperworkMissing) {
			vehicle.Paperwork_Missing__c = paperworkMissing;
			update vehicle;
			return this;
		}

		public VehicleTester updateListingTitle(String listingTitle) {
			vehicle.Listing_Title__c = listingTitle;
			update vehicle;
			return this;
		}

		public VehicleTester updateYear(Integer year) {
			vehicle.Year__c = year;
			update vehicle;
			return this;
		}

		public VehicleTester updatePhotosReady(Boolean photosReady) {
			vehicle.Photos_Ready__c = photosReady;
			update vehicle;
			return this;
		}
	}
}