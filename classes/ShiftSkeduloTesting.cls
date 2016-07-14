// This class is intended to be used only in an anonymous Apex window in the Developer Console.
// It provides classes that can be used to create objects for testing, including
// Staff Profiles, Opportunities, and the objects required to create them.
//
// To create a StaffProfile, run the following:
//
//	ShiftSkeduloTesting.StaffProfileCreator spCreator =
//		new ShiftSkeduloTesting.StaffProfileCreator('FirstName', 'LastName', 'CC');
//	spCreator.create();
//
// The options for the third argument are 'CC', 'CE', and 'DOS'.
// The Staff Profile can be customized making the following assignments
// before calling create (defaults are shown here):
//
//	spCreator.regionShiftKey = 'us/sfo';
//	spCreator.parkingLotName = '200 Littlefield';
//	spCreator.homeAddress = '2500 Market St, San Francisco, CA, 94114-2512';
//	spCreator.subregionName = 'San Francisco';
//	spCreator.canDriveManual = false;
//
// Seller and Buyer Opportunities can be created and customized similarly.
// The customizations are optional; the defaults are shown here.
//
//	ShiftSkeduloTesting.SellerOpportunityCreator soCreator =
//		new ShiftSkeduloTesting.SellerOpportunityCreator('FirstName', 'LastName');
//	soCreator.regionShiftKey = 'us/sfo';
//	soCreator.year = 2016;
//	soCreator.make = 'Acura';
//	soCreator.model = 'RDX';
//	soCreator.parkingLotName = '200 Littlefield';
//	soCreator.create();
//
//	ShiftSkeduloTesting.BuyerOpportunityCreator boCreator =
//		new ShiftSkeduloTesting.BuyerOpportunityCreator('FirstName', 'LastName');
//	boCreator.regionShiftKey = 'us/sfo';
//	boCreator.create();
//
// Once create() has been called on a SellerOpportunityCreator and a
// BuyerOpportunityCreator, a vehicle interest can be created as follows:
//
// 	boCreator.addVehicleInterest(soCreator.getVehicleId());
public class ShiftSkeduloTesting {
	static final Map<String, String> ROLE_TO_ATTRIBUTE_SHIFT_KEY = new Map<String, String>{
		'CC' => 'is-concierge',
		'CE' => 'is-enthusiast',
		'DOS' => 'is-delivery-operations-specialist'
	};

	static Account createAndInsertAccount() {
		Account account = new Account(Name = 'ignored');
		insert account;
		return account;
	}

	static Contact createAndInsertContact(Account account, String firstName, String lastName) {
		Contact contact = new Contact(
			AccountId = account.Id,
			FirstName = firstName,
			LastName = lastName
		);
		insert contact;
		return contact;
	}

	static User createAndInsertUser(Contact contact, String profileName) {
		String email = contact.FirstName + '.' + contact.LastName + '@test.test';
		User user = new User(
			ContactId = contact.Id,
			FirstName = contact.FirstName,
			LastName = contact.LastName,
			Username = email,
			Email = email,
			Alias = ShiftUtil.randomStringLowercaseAlphanum(8),
			ProfileId = [SELECT Id FROM Profile WHERE Name = :profileName].Id,
			TimeZoneSidKey = 'GMT',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US'
		);
		insert user;
		return user;
	}

	static Staff_Profile__c createAndInsertStaffProfile(User user, String regionShiftKey, String parkingLotName, String homeAddress) {
		Staff_Profile__c staffProfile = new Staff_Profile__c(
			User_ID__c = user.Id,
			Region_ID__c = [SELECT Id FROM Region__c WHERE Shift_Key__c = :regionShiftKey].Id,
			Parking_Lot_ID__c = [SELECT Id FROM Parking_Lot__c WHERE Name = :parkingLotName].Id,
			Home_Address__c = homeAddress
		);
		insert staffProfile;
		return staffProfile;
	}

	static Subregion_Assignment__c createAndInsertSubregionAssignment(Staff_Profile__c staffProfile, String subregionName) {
		Subregion_Assignment__c assignment = new Subregion_Assignment__c(
			Staff_Profile_ID__c = staffProfile.Id,
			Subregion_ID__c = [SELECT Id FROM Subregion__c WHERE Name = :subregionName].Id,
			Is_Primary__c = true,
			Starts_At__c = DateTime.now().addDays(-2),
			Ends_At__c = DateTime.now().addYears(5)
		);
		insert assignment;
		return assignment;
	}

	static Staff_Profile_Attribute_Association__c createAndInsertStaffProfileAttributeAssociation(Staff_Profile__c staffProfile, String attributeShiftKey) {
		Staff_Profile_Attribute_Association__c association = new Staff_Profile_Attribute_Association__c(
			Staff_Profile_ID__c = staffProfile.Id,
			Staff_Profile_Attribute_ID__r = new Staff_Profile_Attribute__c(Shift_Key__c = attributeShiftKey)
		);
		insert association;
		return association;
	}

	static Vehicle__c createAndInsertVehicle(String vehicleRegionShiftKey, Integer year, String make, String model, String parkingLotName) {
		Vehicle__c vehicle = new Vehicle__c(
			Year__c = year,
			Make__c = make,
			Model__c = model,
			Mileage__c = 10000,
			Listing_Region_ID__r = new Region__c(Shift_Key__c = vehicleRegionShiftKey),
			Parking_Lot_ID__c = [SELECT Id FROM Parking_Lot__c WHERE Name = :parkingLotName].Id
		);
		insert vehicle;
		return vehicle;
	}

	static Opportunity createAndInsertSellerOpportunity(Account account, Vehicle__c vehicle, String regionShiftKey) {
		Opportunity opportunity = new Opportunity(
			AccountId = account.Id,
			OwnerId = [SELECT Id FROM User WHERE Shift_Key__c = 'unowned'].Id,
			Region_ID__r = new Region__c(Shift_Key__c = regionShiftKey),
			Vehicle_ID__c = vehicle.Id,
			StageName = 'Quote and Schedule',
			RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Seller'].Id,
			CloseDate = Date.today().addDays(30)
		);
		insert opportunity;
		return opportunity;
	}

	static Opportunity createAndInsertBuyerOpportunity(Account account, String regionShiftKey) {
		Opportunity opportunity = new Opportunity(
			AccountId = account.Id,
			OwnerId = [SELECT Id FROM User WHERE Shift_Key__c = 'unowned'].Id,
			Region_ID__r = new Region__c(Shift_Key__c = regionShiftKey),
			StageName = 'Qualified',
			RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = 'Buyer'].Id,
			CloseDate = Date.today().addDays(30)
		);
		insert opportunity;
		return opportunity;
	}

	static Vehicle_Interest__c createAndInsertVehicleInterest(Opportunity buyerOpportunity, Id vehicleId) {
		Vehicle_Interest__c vehicleInterest = new Vehicle_Interest__c(
			Buyer_Opportunity_ID__c = buyerOpportunity.Id,
			Vehicle_ID__c = vehicleId
		);
		insert vehicleInterest;
		return vehicleInterest;
	}

	public class StaffProfileCreator {
		private String firstName;
		private String lastName;
		private String role;
		public String regionShiftKey;
		public String parkingLotName;
		public String homeAddress;
		public String subregionName;
		public Boolean canDriveManual;

		public StaffProfileCreator(String firstName, String lastName, String role) {
			this.firstName = firstName;
			this.lastName = lastName;
			this.role = role;
			this.regionShiftKey = 'us/sfo';
			this.parkingLotName = '200 Littlefield';
			this.homeAddress = '2500 Market St, San Francisco, CA, 94114-2512';
			this.subregionName = 'San Francisco';
			this.canDriveManual = false;
		}

		public void create() {
			Account account = createAndInsertAccount();
			Contact contact = createAndInsertContact(account, firstName, lastName);
			User user = createAndInsertUser(contact, 'Local Market');
			Staff_Profile__c staffProfile = createAndInsertStaffProfile(user, regionShiftKey, parkingLotName, homeAddress);
			createAndInsertSubregionAssignment(staffProfile, subregionName);
			createAndInsertStaffProfileAttributeAssociation(staffProfile, ROLE_TO_ATTRIBUTE_SHIFT_KEY.get(role));
			if (canDriveManual) {
				createAndInsertStaffProfileAttributeAssociation(staffProfile, 'can-drive-manual');
			}
		}
	}

	public class SellerOpportunityCreator {
		private String firstName;
		private String lastName;
		public String regionShiftKey;
		public Integer year;
		public String make;
		public String model;
		public String parkingLotName;
		private Opportunity sellerOpportunity;

		public SellerOpportunityCreator(String firstName, String lastName) {
			this.firstName = firstName;
			this.lastName = lastName;
			this.regionShiftKey = 'us/sfo';
			this.year = 2016;
			this.make = 'Acura';
			this.model = 'RDX';
			this.parkingLotName = '200 Littlefield';
		}

		public void create() {
			Account account = createAndInsertAccount();
			Contact contact = createAndInsertContact(account, firstName, lastName);
			Vehicle__c vehicle = createAndInsertVehicle(regionShiftKey, year, make, model, parkingLotName);
			this.sellerOpportunity = createAndInsertSellerOpportunity(account, vehicle, regionShiftKey);
		}

		public Id getVehicleId() {
			return this.sellerOpportunity.Vehicle_ID__c;
		}
	}

	public class BuyerOpportunityCreator {
		private String firstName;
		private String lastName;
		public String regionShiftKey;
		private Opportunity buyerOpportunity;

		public BuyerOpportunityCreator(String firstName, String lastName) {
			this.firstName = firstName;
			this.lastName = lastName;
			this.regionShiftKey = 'us/sfo';
		}

		public void create() {
			Account account = createAndInsertAccount();
			Contact contact = createAndInsertContact(account, firstName, lastName);
			this.buyerOpportunity = createAndInsertBuyerOpportunity(account, regionShiftKey);
		}

		public void addVehicleInterest(Id vehicleId) {
			createAndInsertVehicleInterest(buyerOpportunity, vehicleId);
		}
	}
}