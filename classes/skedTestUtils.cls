public class skedTestUtils {
    
	public static Map<string, sObject> SetupTestData() {
		Map<string, sObject> mapTestData = new Map<string, sObject>();
		SetupJobTypeSettings();
        SetupJobTypeActivitySettings();
		SetupBookingAvailabilitySettings();

		sked_Booking_Email_Setting__c emailSetting = sked_Booking_Email_Setting__c.getOrgDefaults();
		emailSetting.Activated__c = TRUE;
		emailSetting.Buyer_Opportunity_CC_List__c = 'buy@shift.com.test';
		emailSetting.Seller_Opportunity_CC_List__c = 'sell@shift.com.test';
		emailSetting.Travel_Time_Buffer__c = 15;
		emailSetting.Last_Job_Rule_Minutes__c = 15;
		upsert emailSetting;

	/*************************Region - Resource - Tag - Staff Profile*************************/

		Region__c region1 = new Region__c(
				Name = 'San Francisco',
				Shift_Key__c = 'us/sfo',
				Timezone__c = 'America/New_York'
		);
		insert region1;
		mapTestData.put('region1', region1);

		Subregion__c subRegion1 = new Subregion__c(
				Name = 'San Francisco',
				Region_ID__c = region1.Id,
				ZIP_Code_List_String__c = '94102,94103,94104,94105,94107,94108,94109,94110,94111,94112,94114,94115,94116,94117,94118,94121,94122,94123,94124,94127,94129,94131,94132,94133,94134,94158'
		);
		insert subRegion1;

		Parking_Lot__c parkingLot1 = new Parking_Lot__c(
				Name = '200 Littlefield',
				Geolocation__Latitude__s = 37.6440850,
				Geolocation__Longitude__s = -122.3986130,
				Address__c = '200 Littlefield, Ave South San Francisco, CA 94080',
				Region_ID__c = region1.Id
		);
		insert parkingLot1;

		Vehicle__c vehicle1 = new Vehicle__c(
				Name = '2014 Acura ILX',
				Listing_Region_ID__c = region1.Id,
				Make__c = 'Acura',
				Model__c = 'ILX',
				Mileage__c = 10000,
				VIN__c = '2G2WP522941132397',
				Parking_Lot_ID__c = parkingLot1.Id,
				Transmission__c = 'Manual',
				Photos_Ready__c = TRUE,
				Paperwork_Missing__c = 'NO'
		);
		insert vehicle1;

		Staff_Profile_Attribute__c staffrofileAttr1 = new Staff_Profile_Attribute__c(
				Label__c = 'Can Drive Manual',
				Shift_Key__c = 'can-drive-manual',
				Type__c = 'Capability'
		);
		insert staffrofileAttr1;
		Staff_Profile_Attribute__c staffrofileAttr2 = new Staff_Profile_Attribute__c(
				Label__c = 'Is Delivery Operations Specialist',
				Shift_Key__c = 'is-delivery-operations-specialist',
				Type__c = 'Role'
		);
		insert staffrofileAttr2;
		Staff_Profile_Attribute__c staffrofileAttr3 = new Staff_Profile_Attribute__c(
				Label__c = 'Is Concierge',
				Shift_Key__c = 'is-concierge',
				Type__c = 'Role'
		);
		insert staffrofileAttr3;
		Staff_Profile_Attribute__c staffrofileAttr4 = new Staff_Profile_Attribute__c(
				Label__c = 'Is Enthusiast',
				Shift_Key__c = 'is-enthusiast',
				Type__c = 'Role'
		);
		insert staffrofileAttr4;
		Staff_Profile_Attribute__c staffrofileAttr5 = new Staff_Profile_Attribute__c(
				Label__c = 'Is PrOps Driver',
				Shift_Key__c = 'is-props-driver',
				Type__c = 'Role'
		);
		insert staffrofileAttr5;

		Staff_Profile__c staffProfile1 = new Staff_Profile__c(
				Region_ID__c = region1.Id,
				User_ID__c = UserInfo.getUserId(),
				Parking_Lot_ID__c = parkingLot1.Id
		);
		insert staffProfile1;

		List<Staff_Profile_Attribute_Association__c> staffAttrAssociations = new List<Staff_Profile_Attribute_Association__c>();
		Staff_Profile_Attribute_Association__c staff1Attr1 = new Staff_Profile_Attribute_Association__c(
				Staff_Profile_ID__c = staffProfile1.Id,
				Staff_Profile_Attribute_ID__c = staffrofileAttr1.Id
		);
		staffAttrAssociations.add(staff1Attr1);
		Staff_Profile_Attribute_Association__c staff1Attr2 = new Staff_Profile_Attribute_Association__c(
				Staff_Profile_ID__c = staffProfile1.Id,
				Staff_Profile_Attribute_ID__c = staffrofileAttr2.Id
		);
		staffAttrAssociations.add(staff1Attr2);
		Staff_Profile_Attribute_Association__c staff1Attr3 = new Staff_Profile_Attribute_Association__c(
				Staff_Profile_ID__c = staffProfile1.Id,
				Staff_Profile_Attribute_ID__c = staffrofileAttr3.Id
		);
		staffAttrAssociations.add(staff1Attr3);
		Staff_Profile_Attribute_Association__c staff1Attr4 = new Staff_Profile_Attribute_Association__c(
				Staff_Profile_ID__c = staffProfile1.Id,
				Staff_Profile_Attribute_ID__c = staffrofileAttr4.Id
		);
		staffAttrAssociations.add(staff1Attr4);
		Staff_Profile_Attribute_Association__c staff1Attr5 = new Staff_Profile_Attribute_Association__c(
				Staff_Profile_ID__c = staffProfile1.Id,
				Staff_Profile_Attribute_ID__c = staffrofileAttr5.Id
		);
		staffAttrAssociations.add(staff1Attr5);
		insert staffAttrAssociations;

		staffProfile1 = [SELECT Id, Skedulo_Resource_ID__c FROM Staff_Profile__c WHERE Id = :staffProfile1.Id];
		sked__Resource__c skedResource1 = [SELECT Id, Name,
		(SELECT sked__Tag__r.Name
		FROM sked__ResourceTags__r)
		FROM sked__Resource__c WHERE Id = :staffProfile1.Skedulo_Resource_ID__c];
		skedResource1.sked__Home_Address__c = '2500 Market St, San Francisco, CA, 94114-2512';
		skedResource1.sked__GeoLocation__Latitude__s = 37.76210607100046;
		skedResource1.sked__GeoLocation__Longitude__s = -122.43639097799968;
		update skedResource1;
		mapTestData.put('skedResource1', skedResource1);

		//insert availability records
		sked__Availability__c availability = new sked__Availability__c(
				sked__Resource__c = skedResource1.Id,
				sked__Start__c = system.now(),
				sked__Finish__c = system.now().addHours(1),
				sked__Is_Available__c = TRUE
		);
		insert availability;

        /*Load Availabilty Template for Resource*/
		sked__Availability_Template__c avaiTemp = new sked__Availability_Template__c();
		insert avaiTemp;

		List<sked__Availability_Template_Entry__c> weekDayEntries = new List<sked__Availability_Template_Entry__c>();
		sked__Availability_Template_Entry__c monEntry = new sked__Availability_Template_Entry__c(sked__Availability_Template__c = avaiTemp.Id, sked__Weekday__c = 'MON', sked__Start_Time__c = 900, sked__Finish_Time__c = 1700, sked__Is_Available__c = true);
		weekDayEntries.add(monEntry);
		sked__Availability_Template_Entry__c tueEntry = new sked__Availability_Template_Entry__c(sked__Availability_Template__c = avaiTemp.Id, sked__Weekday__c = 'TUE', sked__Start_Time__c = 600, sked__Finish_Time__c = 1700, sked__Is_Available__c = true);
		weekDayEntries.add(tueEntry);
		sked__Availability_Template_Entry__c wedEntry = new sked__Availability_Template_Entry__c(sked__Availability_Template__c = avaiTemp.Id, sked__Weekday__c = 'WED', sked__Start_Time__c = 900, sked__Finish_Time__c = 1700, sked__Is_Available__c = true);
		weekDayEntries.add(wedEntry);
		sked__Availability_Template_Entry__c thuEntry = new sked__Availability_Template_Entry__c(sked__Availability_Template__c = avaiTemp.Id, sked__Weekday__c = 'THU', sked__Start_Time__c = 900, sked__Finish_Time__c = 2000, sked__Is_Available__c = true);
		weekDayEntries.add(thuEntry);
		sked__Availability_Template_Entry__c friEntry = new sked__Availability_Template_Entry__c(sked__Availability_Template__c = avaiTemp.Id, sked__Weekday__c = 'FRI', sked__Start_Time__c = 900, sked__Finish_Time__c = 1700, sked__Is_Available__c = true);
		weekDayEntries.add(friEntry);
		sked__Availability_Template_Entry__c satEntry = new sked__Availability_Template_Entry__c(sked__Availability_Template__c = avaiTemp.Id, sked__Weekday__c = 'SAT', sked__Start_Time__c = 900, sked__Finish_Time__c = 1700, sked__Is_Available__c = true);
		weekDayEntries.add(satEntry);
		sked__Availability_Template_Entry__c sunEntry = new sked__Availability_Template_Entry__c(sked__Availability_Template__c = avaiTemp.Id, sked__Weekday__c = 'SUN', sked__Start_Time__c = 900, sked__Finish_Time__c = 1700, sked__Is_Available__c = true);
		weekDayEntries.add(sunEntry);
		insert weekDayEntries;

		sked__Availability_Template_Resource__c avaiTempRes = new sked__Availability_Template_Resource__c(sked__Availability_Template__c = avaiTemp.Id, sked__Resource__c = skedResource1.Id);
		insert avaiTempRes;
        /*End - Load Availabilty Template for Resource*/


		Subregion_Assignment__c subRegionAssignment1 = new Subregion_Assignment__c(
				Subregion_ID__c = subRegion1.Id,
				Starts_At__c = system.now().addDays(-100),
				Ends_At__c = system.now().addDays(100),
				Staff_Profile_ID__c = staffProfile1.Id
		);
		insert subRegionAssignment1;
    /*************************End - Region - Resource - Tag - Staff Profile*************************/



    /***********************Account - Contact - Vehicle - Opportunity***********************************/
		Account account1 = new Account(
				Name = 'Skedulo Test Account'
		);
		insert account1;

		Contact contact1 = new Contact(
				FirstName = 'Test',
				LastName = 'Skedulo',
				AccountId = account1.Id,
				Email = 'testContact@email.com'
		);
		insert contact1;

		Opportunity sellerOpp = new Opportunity(
				RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Seller').getRecordTypeId(),
				Name = '2014 Acura ILX - Joe Test',
				AccountId = account1.Id,
				Region_ID__c = region1.Id,
				Vehicle_ID__c = vehicle1.Id,
				StageName = 'Evaluate and Pickup',
				CloseDate = system.now().date().addDays(10)
		);
		insert sellerOpp;
		mapTestData.put('sellerOpp', sellerOpp);

		Evaluation__c evaluation1 = new Evaluation__c(
				Seller_Opportunity_ID__c = sellerOpp.Id,
				Location__c = '2152 Pine St, San Francisco, CA 94115, USA',
				Geolocation__Latitude__s = 37.788288,
				Geolocation__Longitude__s = -122.431223,
				Originally_Requested_At__c = DateTime.newInstance(system.now().date(), Time.newInstance(0, 0, 0, 0)).addHours(13)
		);
		insert evaluation1;
		mapTestData.put('evaluation1', evaluation1);

		Pick_Up__c pickup1 = new Pick_Up__c(
				Evaluation_ID__c = evaluation1.Id,
				Location__c = '2152 Pine St, San Francisco, CA 94115, USA',
				Geolocation__Latitude__s = 37.788288,
				Geolocation__Longitude__s = -122.431223,
				Original_Time_Requested__c = DateTime.newInstance(system.now().date(), Time.newInstance(0, 0, 0, 0)).addHours(13)
		);
		insert pickup1;
		mapTestData.put('pickup1', pickup1);

		Opportunity buyerOpp = new Opportunity(
				RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Buyer').getRecordTypeId(),
				Name = 'Jane Buyer',
				AccountId = account1.Id,
				Region_ID__c = region1.Id,
				StageName = 'Qualified',
				CloseDate = system.now().date().addDays(10)
		);
		insert buyerOpp;
		mapTestData.put('buyerOpp', buyerOpp);

		Vehicle_Interest__c vehicleInterest1 = new Vehicle_Interest__c(
				Buyer_Opportunity_ID__c = buyerOpp.Id,
				Vehicle_ID__c = vehicle1.Id
		);
		insert vehicleInterest1;
		mapTestData.put('vehicleInterest1', vehicleInterest1);

		Test_Drive__c testDrive1 = new Test_Drive__c(
				Vehicle_Interest_ID__c = vehicleInterest1.Id,
				Location__c = '120 Gillette Ave, San Francisco, CA 94134, USA',
				Geolocation__Latitude__s = 37.710715,
				Geolocation__Longitude__s = -122.396610,
				Original_Time_Requested__c = DateTime.newInstance(system.now().date(), Time.newInstance(0, 0, 0, 0)).addHours(13),
				Test_Drive_By_ID__c = UserInfo.getUserId()
		);
		insert testDrive1;
		mapTestData.put('testDrive1', testDrive1);

		Delivery__c delivery1 = new Delivery__c(
				Vehicle_Interest__c = vehicleInterest1.Id,
				Location__c = '120 Gillette Ave, San Francisco, CA 94134, USA',
				Geolocation__Latitude__s = 37.710715,
				Geolocation__Longitude__s = -122.396610,
				Original_Time_Requested__c = DateTime.newInstance(system.now().date(), Time.newInstance(0, 0, 0, 0)).addHours(13)
		);
		insert delivery1;
		mapTestData.put('delivery1', delivery1);

		Pick_Up__c pickup2 = new Pick_Up__c(
				Vehicle_Interest_ID__c = vehicleInterest1.Id,
				Location__c = '2152 Pine St, San Francisco, CA 94115, USA',
				Geolocation__Latitude__s = 37.788288,
				Geolocation__Longitude__s = -122.431223,
				Original_Time_Requested__c = DateTime.newInstance(system.now().date(), Time.newInstance(0, 0, 0, 0)).addHours(13)
		);
		insert pickup2;
		mapTestData.put('pickup2', pickup2);
    /***********************End - Account - Contact - Vehicle - Opportunity***********************************/
		return mapTestData;
	}

	private static void SetupJobTypeSettings() {
		List<Job_Type_Settings__c> jobTypeSettings = new List<Job_Type_Settings__c>();
		Job_Type_Settings__c jobTypeSetting1 = new Job_Type_Settings__c(
				Name = 'Drivers Assist Setting 1',
				Job_Type__c = 'Drivers Assist',
				Object_Type__c = 'evaluation',
				Duration__c = 15,
				Resource_tag__c = '',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = true
		);
		jobTypeSettings.add(jobTypeSetting1);

		Job_Type_Settings__c jobTypeSetting2 = new Job_Type_Settings__c(
				Name = 'Drivers Assist Setting 2',
				Job_Type__c = 'Drivers Assist',
				Object_Type__c = 'testdrive',
				Duration__c = 15,
				Resource_tag__c = '',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = true
		);
		jobTypeSettings.add(jobTypeSetting2);

		Job_Type_Settings__c jobTypeSetting3 = new Job_Type_Settings__c(
				Name = 'Evaluation Setting 1',
				Job_Type__c = 'Inbound Evaluation + Pickup',
				Object_Type__c = 'evaluation',
				Duration__c = 60,
				Resource_tag__c = 'is-concierge',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting3);

		Job_Type_Settings__c jobTypeSetting4 = new Job_Type_Settings__c(
				Name = 'Evaluation Setting 2',
				Job_Type__c = 'Inbound Evaluation + Possible Pickup',
				Object_Type__c = 'evaluation',
				Duration__c = 60,
				Resource_tag__c = 'is-concierge',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting4);

		Job_Type_Settings__c jobTypeSetting5 = new Job_Type_Settings__c(
				Name = 'Evaluation Setting 3',
				Job_Type__c = 'Inbound Evaluation Only',
				Object_Type__c = 'evaluation',
				Duration__c = 45,
				Resource_tag__c = 'is-concierge',
				Start_from_Hub__c = false,
				Back_to_Hub__c = false,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting5);

		Job_Type_Settings__c jobTypeSetting6 = new Job_Type_Settings__c(
				Name = 'Evaluation Setting 4',
				Job_Type__c = 'Outbound Evaluation + Pickup',
				Object_Type__c = 'evaluation',
				Duration__c = 75,
				Resource_tag__c = 'is-concierge',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting6);

		Job_Type_Settings__c jobTypeSetting7 = new Job_Type_Settings__c(
				Name = 'Evaluation Setting 5',
				Job_Type__c = 'Outbound Evaluation + Possible Pickup',
				Object_Type__c = 'evaluation',
				Duration__c = 60,
				Resource_tag__c = 'is-concierge',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting7);

		Job_Type_Settings__c jobTypeSetting8 = new Job_Type_Settings__c(
				Name = 'Evaluation Setting 6',
				Job_Type__c = 'Outbound Evaluation Only',
				Object_Type__c = 'evaluation',
				Duration__c = 60,
				Resource_tag__c = 'is-concierge',
				Start_from_Hub__c = false,
				Back_to_Hub__c = false,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting8);

		Job_Type_Settings__c jobTypeSetting9 = new Job_Type_Settings__c(
				Name = 'Evaluation Setting 7',
				Job_Type__c = SkeduloConstants.JOB_TYPE_EVALUATION,
				Object_Type__c = SkeduloConstants.OBJECT_TYPE_EVALUATION,
				Duration__c = 60,
				Resource_tag__c = 'is-concierge',
				Start_from_Hub__c = false,
				Back_to_Hub__c = false,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting9);

		Job_Type_Settings__c jobTypeSetting11 = new Job_Type_Settings__c(
				Name = 'Test Drive Setting 1',
				Job_Type__c = 'Test Drive',
				Object_Type__c = 'testdrive',
				Duration__c = 60,
				Resource_tag__c = 'is-enthusiast',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting11);

		Job_Type_Settings__c jobTypeSetting12 = new Job_Type_Settings__c(
				Name = 'Test Drive Setting 2',
				Job_Type__c = 'Test Drive',
				Object_Type__c = 'testdrive',
				Duration__c = 60,
				Resource_tag__c = 'is-enthusiast',
				Start_from_Hub__c = false,
				Back_to_Hub__c = true,
				Drivers_Assist__c = true,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting12);

		Job_Type_Settings__c jobTypeSetting13 = new Job_Type_Settings__c(
				Name = 'Delivery Setting 1',
				Job_Type__c = 'Delivery',
				Object_Type__c = 'delivery',
				Duration__c = 30,
				Resource_tag__c = 'is-delivery-operations-specialist',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting13);

		Job_Type_Settings__c jobTypeSetting14 = new Job_Type_Settings__c(
				Name = 'Pickup Setting 1',
				Job_Type__c = 'Pickup Only',
				Object_Type__c = 'pickup',
				Duration__c = 30,
				Resource_tag__c = 'is-delivery-operations-specialist',
				Start_from_Hub__c = true,
				Back_to_Hub__c = true,
				Drivers_Assist__c = false,
				Not_Show__c = false
		);
		jobTypeSettings.add(jobTypeSetting14);

		insert jobTypeSettings;
	}
    
    private static void SetupJobTypeActivitySettings() {
        List<Job_Type_Activity_Settings__c> jobTypeActivitySettings = new List<Job_Type_Activity_Settings__c>();
		Job_Type_Activity_Settings__c jobTypeActivitySettings1 = new Job_Type_Activity_Settings__c(
            Name = 'Prep time before Test Drive',
            Job_Type__c = 'Test Drive',
            Activity_Type__c = 'Prep Time',
            Is_Before__c = true,
            Is_After__c = true,
            Duration__c = 15
		);
		jobTypeActivitySettings.add(jobTypeActivitySettings1);
        insert jobTypeActivitySettings;
    }

	private static void SetupBookingAvailabilitySettings() {
		List<Booking_Availability_Settings__c> settings = new List<Booking_Availability_Settings__c>();
		Booking_Availability_Settings__c setting1 = new Booking_Availability_Settings__c(
				Name = 'Test Drive Setting 1',
				Object_Type__c = 'testdrive',
				Start__c = 0,
				End__c = 200,
				Is_Available__c = TRUE
		);
		settings.add(setting1);
		Booking_Availability_Settings__c setting2 = new Booking_Availability_Settings__c(
				Name = 'Test Drive Setting 2',
				Object_Type__c = 'testdrive',
				Start__c = 200,
				End__c = 330,
				Is_Available__c = FALSE
		);
		settings.add(setting2);
		Booking_Availability_Settings__c setting3 = new Booking_Availability_Settings__c(
				Name = 'Test Drive Setting 3',
				Object_Type__c = 'testdrive',
				Start__c = 330,
				End__c = 500,
				Is_Available__c = TRUE
		);
		settings.add(setting3);
		Booking_Availability_Settings__c setting4 = new Booking_Availability_Settings__c(
				Name = 'Test Drive Setting 4',
				Object_Type__c = 'testdrive',
				Start__c = 500,
				End__c = 630,
				Is_Available__c = FALSE
		);
		settings.add(setting4);
		Booking_Availability_Settings__c setting5 = new Booking_Availability_Settings__c(
				Name = 'Test Drive Setting 5',
				Object_Type__c = 'testdrive',
				Start__c = 630,
				End__c = 800,
				Is_Available__c = TRUE
		);
		settings.add(setting5);
		insert settings;
	}
}