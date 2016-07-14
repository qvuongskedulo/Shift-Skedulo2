@IsTest
public class ShiftStaffProfilesTest {
	private static final String STAFF_PROFILE_ATTRIBUTE_LABEL_TESTING = 'Testing';
	private static final String STAFF_PROFILE_ATTRIBUTE_SHIFT_KEY_TESTING = 'testing';
	private static final String STAFF_PROFILE_ATTRIBUTE_TYPE_TESTING = 'Testing';

	@TestSetup private static void setup() { ShiftTesting.setup(); }

	static Staff_Profile__c createStaffProfile(User u) {
		return new Staff_Profile__c(
			User_ID__c = u.Id,
			Region_ID__c = ShiftTesting.getTestRegionId()
		);
	}

	static Staff_Profile_Attribute__c createTestStaffProfileAttribute() {
		return createTestStaffProfileAttribute('');
	}

	static Staff_Profile_Attribute__c createTestStaffProfileAttribute(String suffix) {
		return new Staff_Profile_Attribute__c(
				Label__c = STAFF_PROFILE_ATTRIBUTE_LABEL_TESTING + suffix,
				Shift_Key__c = STAFF_PROFILE_ATTRIBUTE_SHIFT_KEY_TESTING + suffix,
				Type__c = STAFF_PROFILE_ATTRIBUTE_TYPE_TESTING
		);
	}

	static Staff_Profile_Attribute_Association__c createStaffProfileAttributeAssociation(Id staffProfileId, Id staffProfileAssociationId) {
		return new Staff_Profile_Attribute_Association__c(
			Staff_Profile_ID__c = staffProfileId,
			Staff_Profile_Attribute_ID__c = staffProfileAssociationId
		);
	}

	static Id expectSkeduloResourceSynced(Id staffProfileId) {
		Staff_Profile__c staffProfile = [
			SELECT
				User_ID__c,
				User_ID__r.Name,
				Home_Address__c,
				Region_ID__r.Skedulo_Region_ID__c,
				Email__c,
				Skedulo_Resource_ID__c,
				Skedulo_Resource_ID__r.Name,
				Skedulo_Resource_ID__r.sked__User__c,
				Skedulo_Resource_ID__r.sked__Home_Address__c,
				Skedulo_Resource_ID__r.sked__Primary_Region__c,
				Skedulo_Resource_ID__r.sked__Resource_Type__c,
				Skedulo_Resource_ID__r.sked__Email__c
			FROM Staff_Profile__c
			WHERE Id = :staffProfileId
		];
		System.assertEquals(staffProfile.User_ID__c, staffProfile.Skedulo_Resource_ID__r.sked__User__c);
		System.assertEquals(staffProfile.User_ID__r.Name, staffProfile.Skedulo_Resource_ID__r.Name);
		System.assertEquals(staffProfile.Home_Address__c, staffProfile.Skedulo_Resource_ID__r.sked__Home_Address__c);
		System.assertEquals(staffProfile.Region_ID__r.Skedulo_Region_ID__c, staffProfile.Skedulo_Resource_ID__r.sked__Primary_Region__c);
		System.assertEquals(ShiftConstants.SKEDULO_RESOURCE_TYPE_PERSON, staffProfile.Skedulo_Resource_ID__r.sked__Resource_Type__c);
		System.assertEquals(staffProfile.Email__c, staffProfile.Skedulo_Resource_ID__r.sked__Email__c);
		return staffProfile.Skedulo_Resource_ID__c;
	}

	static Id expectSkeduloTagSynced(Id attributeId) {
		Staff_Profile_Attribute__c attribute = [
			SELECT
				Shift_Key__c,
				Type__c,
				Skedulo_Tag_ID__c,
				Skedulo_Tag_ID__r.Name,
				Skedulo_Tag_ID__r.sked__Type__c,
				Skedulo_Tag_ID__r.sked__Classification__c
			FROM Staff_Profile_Attribute__c
			WHERE Id = :attributeId
		];
		System.assertEquals(attribute.Shift_Key__c, attribute.Skedulo_Tag_ID__r.Name);
		System.assertEquals(
			ShiftConstants.STAFF_PROFILE_ATTRIBUTE_TYPE_TO_SKEDULO_TAG_TYPE.get(attribute.Type__c),
			attribute.Skedulo_Tag_ID__r.sked__Type__c
		);
		System.assertEquals(ShiftConstants.SKEDULO_TAG_CLASSIFICATION_GLOBAL, attribute.Skedulo_Tag_ID__r.sked__Classification__c);
		return attribute.Skedulo_Tag_ID__c;
	}

	static Id expectSkeduloResourceTagSynced(Id associationId) {
		Staff_Profile_Attribute_Association__c association = [
			SELECT
				Staff_Profile_ID__r.Skedulo_Resource_ID__c,
				Staff_Profile_Attribute_ID__r.Skedulo_Tag_ID__c,
				Skedulo_Resource_Tag_ID__c,
				Skedulo_Resource_Tag_ID__r.sked__Resource__c,
				Skedulo_Resource_Tag_ID__r.sked__Tag__c
			FROM Staff_Profile_Attribute_Association__c
			WHERE Id = :associationId
		];
		System.assertEquals(association.Staff_Profile_ID__r.Skedulo_Resource_ID__c, association.Skedulo_Resource_Tag_ID__r.sked__Resource__c);
		System.assertEquals(association.Staff_Profile_Attribute_ID__r.Skedulo_Tag_ID__c, association.Skedulo_Resource_Tag_ID__r.sked__Tag__c);
		return association.Skedulo_Resource_Tag_ID__c;
	}

	@IsTest
	static void testInsertWithNullUserId() {
		User testUser = ShiftTesting.insertTestUser();
		Staff_Profile__c profileWithoutUser = new Staff_Profile__c (
			Region_ID__c = ShiftTesting.getTestRegionId()
		);
		ShiftTesting.expectInsertExceptionContains(profileWithoutUser, 'User ID is null');
	}

	@IsTest
	static void testInsertUserIdCollision() {
		User testUser = ShiftTesting.insertTestUser();
		Staff_Profile__c profile1 = createStaffProfile(testUser);
		insert profile1;
		Staff_Profile__c profile2 = createStaffProfile(testUser);
		ShiftTesting.expectInsertExceptionContains(profile2, 'User cannot be associated with multiple staff profiles.');
	}

	@IsTest
	static void testUpdateUserIdCollision() {
		User testUser1 = ShiftTesting.insertTestUser();
		User testUser2 = ShiftTesting.insertTestUser();
		Staff_Profile__c sp1 = createStaffProfile(testUser1);
		Staff_Profile__c sp2 = createStaffProfile(testUser2);
		insert sp1;
		insert sp2;
		sp2.User_ID__c = testUser1.Id;
		ShiftTesting.expectUpdateExceptionContains(sp2, 'User cannot be associated with multiple staff profiles.');
	}

	@IsTest
	static void testBatchInsertInternalUserIdCollision() {
		User testUser = ShiftTesting.insertTestUser();
		List<Staff_Profile__c> profiles = new List<Staff_Profile__c>();
		profiles.add(createStaffProfile(testUser));
		profiles.add(createStaffProfile(testUser));
		ShiftTesting.expectInsertExceptionContains(profiles, 'User cannot be associated with multiple staff profiles.');
	}

	@IsTest
	static void testBatchUpdateInternalUserIdCollision() {
		User testUser1 = ShiftTesting.insertTestUser();
		User testUser2 = ShiftTesting.insertTestUser();
		Staff_Profile__c sp1 = createStaffProfile(testUser1);
		Staff_Profile__c sp2 = createStaffProfile(testUser2);
		insert sp1;
		insert sp2;

		User testUser3 = ShiftTesting.insertTestUser();
		sp1.User_ID__c = testUser3.Id;
		sp2.User_ID__c = testUser3.Id;
		List<Staff_Profile__c> profiles = new List<Staff_Profile__C> {sp1, sp2};
		ShiftTesting.expectUpdateExceptionContains(profiles, 'User cannot be associated with multiple staff profiles.');
	}

	@IsTest
	static void testBatchUpdateWithUnmodifiedUserId() {
		User testUser1 = ShiftTesting.insertTestUser();
		User testUser2 = ShiftTesting.insertTestUser();
		List<Staff_Profile__c> profilesForInsert = new List<Staff_Profile__c>();
		profilesForInsert.add(createStaffProfile(testUser1));
		profilesForInsert.add(createStaffProfile(testUser2));
		insert profilesForInsert;

		User testUser3 = ShiftTesting.insertTestUser();
		List<Staff_Profile__c> profilesForUpdate = [SELECT Id, User_ID__c, Bio__c FROM Staff_Profile__c WHERE User_ID__c = :testUser1.Id OR User_ID__c = :testUser2.Id];
		System.assertEquals(2, profilesForUpdate.size());
		profilesForUpdate[0].User_ID__c = testUser3.Id;
		profilesForUpdate[1].Bio__c = 'test';
		update profilesForUpdate;
	}

	@IsTest
	static void testSyncSkeduloResource() {
		User u = ShiftTesting.insertTestUser();
		Staff_Profile__c staffProfile = createStaffProfile(u);
		staffProfile.Home_Address__c = ShiftUtil.randomStringLowercaseAlphanum(16);
		staffProfile.Region_ID__c = ShiftTesting.getTestRegionId();
		insert staffProfile;
		expectSkeduloResourceSynced(staffProfile.Id);

		staffProfile.Home_Address__c = ShiftUtil.randomStringLowercaseAlphanum(16);
		update staffProfile;
		Id skeduloResourceId = expectSkeduloResourceSynced(staffProfile.Id);

		delete staffProfile;
		System.assertEquals(0, [SELECT COUNT() FROM sked__Resource__c WHERE Id = :skeduloResourceId]);
	}

	@IsTest
	static void testSyncSkeduloTags() {
		Staff_Profile_Attribute__c attribute = createTestStaffProfileAttribute();
		insert attribute;
		System.assertEquals(null, [SELECT Skedulo_Tag_ID__c FROM Staff_Profile_Attribute__c WHERE Id = :attribute.Id].Skedulo_Tag_ID__c);
		System.assertEquals(0, [SELECT COUNT() FROM sked__Tag__c]);

		attribute.Label__c = STAFF_PROFILE_ATTRIBUTE_LABEL_TESTING + '2';
		attribute.Shift_Key__c = STAFF_PROFILE_ATTRIBUTE_SHIFT_KEY_TESTING + '2';
		attribute.Type__c = ShiftConstants.STAFF_PROFILE_ATTRIBUTE_TYPE_CAPABILITY;
		update attribute;
		Id skeduloTagId = expectSkeduloTagSynced(attribute.Id);

		attribute.Type__c = STAFF_PROFILE_ATTRIBUTE_TYPE_TESTING;
		update attribute;
		System.assertEquals(null, [SELECT Skedulo_Tag_ID__c FROM Staff_Profile_Attribute__c WHERE Id = :attribute.Id].Skedulo_Tag_ID__c);
		System.assertEquals(0, [SELECT COUNT() FROM sked__Tag__c WHERE Id = :skeduloTagId]);

		attribute.Type__c = ShiftConstants.STAFF_PROFILE_ATTRIBUTE_TYPE_ROLE;
		update attribute;
		skeduloTagId = expectSkeduloTagSynced(attribute.Id);

		delete attribute;
		System.assertEquals(0, [SELECT COUNT() FROM sked__Tag__c WHERE Id = :skeduloTagId]);

		Staff_Profile_Attribute__c attribute2 = createTestStaffProfileAttribute();
		attribute2.Type__c = ShiftConstants.STAFF_PROFILE_ATTRIBUTE_TYPE_CAPABILITY;
		insert attribute2;
		expectSkeduloTagSynced(attribute2.Id);
	}

	@IsTest
	static void testSyncSkeduloResourceTags() {
		User u = ShiftTesting.insertTestUser();
		Staff_Profile__c staffProfile = createStaffProfile(u);
		insert staffProfile;
		Staff_Profile_Attribute__c attribute = createTestStaffProfileAttribute();
		insert attribute;
		Staff_Profile_Attribute_Association__c association = createStaffProfileAttributeAssociation(staffProfile.Id, attribute.Id);
		insert association;
		System.assertEquals(null, association.Skedulo_Resource_Tag_ID__c);
		System.assertEquals(0, [SELECT COUNT() FROM sked__Resource_Tag__c]);

		// When a Staff Profile Attribute that previously didn't map to a Skedulo Tag
		// is changed so that it does map to a Skedulo Tag, Skedulo Resource Tags should
		// be created for each of that Staff Profile Attribute's Associations.
		attribute.Type__c = ShiftConstants.STAFF_PROFILE_ATTRIBUTE_TYPE_CAPABILITY;
		update attribute;
		Id skeduloResourceTagId = expectSkeduloResourceTagSynced(association.Id);

		attribute.Type__c = STAFF_PROFILE_ATTRIBUTE_TYPE_TESTING;
		update attribute;
		System.assertEquals(null, [SELECT Skedulo_Resource_Tag_ID__c FROM Staff_Profile_Attribute_Association__c WHERE Id = :association.Id].Skedulo_Resource_Tag_ID__c);
		System.assertEquals(0, [SELECT COUNT() FROM sked__Resource_Tag__c WHERE Id = :skeduloResourceTagId]);

		attribute.Type__c = ShiftConstants.STAFF_PROFILE_ATTRIBUTE_TYPE_ROLE;
		update attribute;
		skeduloResourceTagId = expectSkeduloResourceTagSynced(association.Id);

		delete association;
		System.assertEquals(0, [SELECT COUNT() FROM sked__Resource_Tag__c WHERE Id = :skeduloResourceTagId]);

		Staff_Profile_Attribute_Association__c association2 = createStaffProfileAttributeAssociation(staffProfile.Id, attribute.Id);
		insert association2;
		skeduloResourceTagId = expectSkeduloResourceTagSynced(association2.Id);

		delete attribute;
		System.assertEquals(0, [SELECT COUNT() FROM Staff_Profile_Attribute_Association__c WHERE Id = :association2.Id]);
		System.assertEquals(0, [SELECT COUNT() FROM sked__Resource_Tag__c WHERE Id = :skeduloResourceTagId]);
	}

	@IsTest
	static void testExistingSkeduloObjects() {
		sked__Resource__c skeduloResource = new sked__Resource__c();
		insert skeduloResource;

		User u = ShiftTesting.insertTestUser();
		Staff_Profile__c staffProfile = createStaffProfile(u);
		staffProfile.Home_Address__c = ShiftUtil.randomStringLowercaseAlphanum(16);
		staffProfile.Region_ID__c = ShiftTesting.getTestRegionId();
		staffProfile.Skedulo_Resource_ID__c = skeduloResource.Id;
		insert staffProfile;
		expectSkeduloResourceSynced(staffProfile.Id);

		sked__Tag__c skeduloTag = new sked__Tag__c();
		insert skeduloTag;

		Staff_Profile_Attribute__c attribute = createTestStaffProfileAttribute();
		attribute.Type__c = ShiftConstants.STAFF_PROFILE_ATTRIBUTE_TYPE_CAPABILITY;
		insert attribute;
		expectSkeduloTagSynced(attribute.Id);

		sked__Resource_Tag__c skeduloResourceTag = new sked__Resource_Tag__c(
			sked__Resource__c = skeduloResource.Id,
			sked__Tag__c = skeduloTag.Id
		);
		insert skeduloResourceTag;

		Staff_Profile_Attribute_Association__c association = createStaffProfileAttributeAssociation(staffProfile.Id, attribute.Id);
		insert association;
		expectSkeduloResourceTagSynced(association.Id);
	}

	static void testDuplicateAttributeAssociation() {
		String expectedErrorMessage = 'duplicates value on record';

		User[] users = ShiftTesting.insertTestUsers(3);
		Staff_Profile__c[] staffProfiles = new List<Staff_Profile__c>();
		staffProfiles.add(createStaffProfile(users[0]));
		staffProfiles.add(createStaffProfile(users[1]));
		staffProfiles.add(createStaffProfile(users[2]));
		insert staffProfiles;

		Staff_Profile_Attribute__c[] attributes = new List<Staff_Profile_Attribute__c>();
		attributes.add(createTestStaffProfileAttribute('1'));
		attributes.add(createTestStaffProfileAttribute('2'));
		attributes.add(createTestStaffProfileAttribute('3'));
		insert attributes;

		Staff_Profile_Attribute_Association__c setupData1 = createStaffProfileAttributeAssociation(staffProfiles[0].Id, attributes[0].Id);
		Staff_Profile_Attribute_Association__c setupData2 = createStaffProfileAttributeAssociation(staffProfiles[0].Id, attributes[1].Id);
		Staff_Profile_Attribute_Association__c setupData3 = createStaffProfileAttributeAssociation(staffProfiles[1].Id, attributes[0].Id);

		insert new List<SObject> {setupData1, setupData2, setupData3};

		// Test 0: verify that the setup_data associations were created properly
		List<AggregateResult> verifyInitialSetupResults = [
				SELECT Staff_Profile_ID__c, COUNT(Id) numFound
				FROM Staff_Profile_Attribute_Association__c
				GROUP BY Staff_Profile_ID__c
		];
		Map<Id, Integer> resultsMap = new Map<Id, Integer>();
		for (AggregateResult result : verifyInitialSetupResults) {
			resultsMap.put((Id) result.get('Staff_Profile_ID__c'), (Integer) result.get('numFound'));
		}
		System.assertEquals(new Map<Id, Integer> {staffProfiles[0].Id => 2, staffProfiles[1].Id => 1}, resultsMap);


		// Test 1: verify that the insert fails if one item is a duplicate of existing data
		Staff_Profile_Attribute_Association__c setupData1Duplicate = createStaffProfileAttributeAssociation(setupData1.Staff_Profile_ID__c, setupData1.Staff_Profile_Attribute_ID__c);
		Staff_Profile_Attribute_Association__c test1Data1 = createStaffProfileAttributeAssociation(staffProfiles[0].Id, attributes[2].Id);
		ShiftTesting.expectInsertExceptionContains(
				new List<Staff_Profile_Attribute_Association__c> {setupData1Duplicate, test1Data1},
				expectedErrorMessage);


		// Test 2: if trying to save two duplicate items at the same time, verify that one fails and one succeeds.
		Staff_Profile_Attribute_Association__c test2Data1 = createStaffProfileAttributeAssociation(staffProfiles[1].Id, attributes[1].Id);
		Staff_Profile_Attribute_Association__c test2Data1Duplicate = createStaffProfileAttributeAssociation(test2Data1.Staff_Profile_ID__c, test2Data1.Staff_Profile_Attribute_ID__c);
		ShiftTesting.insertBulkAndVerifyFailures(
				new List<SObject> { test2Data1, test2Data1Duplicate },
				new List<String> { null, expectedErrorMessage }
		);


		// Test 3: verify that inserting two new items works.
		Staff_Profile_Attribute_Association__c test3Data1 = createStaffProfileAttributeAssociation(staffProfiles[1].Id, attributes[2].Id);
		Staff_Profile_Attribute_Association__c test3Data2 = createStaffProfileAttributeAssociation(staffProfiles[2].Id, attributes[0].Id);
		insert new List<Staff_Profile_Attribute_Association__c> {test3Data1, test3Data2};


		// Test 4: if doing a batch insert, verify that valid items succeed while duplicates fail properly.
		Staff_Profile_Attribute_Association__c test4Data1 = createStaffProfileAttributeAssociation(staffProfiles[1].Id, attributes[0].Id);
		Staff_Profile_Attribute_Association__c test4Data2 = createStaffProfileAttributeAssociation(staffProfiles[2].Id, attributes[2].Id);
		Staff_Profile_Attribute_Association__c test4Data3 = createStaffProfileAttributeAssociation(staffProfiles[1].Id, attributes[1].Id);
		Staff_Profile_Attribute_Association__c test4Data4 = createStaffProfileAttributeAssociation(staffProfiles[2].Id, attributes[0].Id);

		Id test4Data2StaffId = test4Data2.Staff_Profile_ID__c;
		Id test4Data2AttributeId = test4Data2.Staff_Profile_Attribute_ID__c;
		String test4ValidationSelect = 'SELECT COUNT() FROM Staff_Profile_Attribute_Association__c WHERE Staff_Profile_ID__c = :test4Data2StaffId AND Staff_Profile_Attribute_ID__c = :test4Data2AttributeId';

		System.assertEquals(0, Database.countQuery(test4ValidationSelect));

		ShiftTesting.insertBulkAndVerifyFailures(
				new List<SObject> { test4Data1, test4Data2, test4Data3, test4Data4 },
				new List<String> { expectedErrorMessage, null, expectedErrorMessage, expectedErrorMessage}
		);

		System.assertEquals(1, Database.countQuery(test4ValidationSelect));
	}

	@IsTest
	static void testInsertAttributeWithoutType() {
		// Test 1: verify that a normal insert works
		Staff_Profile_Attribute__c attributeShouldSucceed = createTestStaffProfileAttribute('1');
		insert attributeShouldSucceed;

		// Test 2: verify that inserting a single attribute without Type fails
		Staff_Profile_Attribute__c attributeShouldFail = createTestStaffProfileAttribute('2');
		attributeShouldFail.Type__c = null;
		ShiftTesting.expectInsertExceptionContains(attributeShouldFail, ShiftExceptions.FIELD_MISSING_EXCEPTION_TEXT);

		// Test 3: verify that inserting a batch fails and succeeds properly
		List<Staff_Profile_Attribute__c> batchAttributes = new List<Staff_Profile_Attribute__c>();
		Staff_Profile_Attribute__c batchAttributeShouldFail1 = createTestStaffProfileAttribute('3');
		batchAttributeShouldFail1.Type__c = '   ';
		Staff_Profile_Attribute__c batchAttributeShouldFail2 = createTestStaffProfileAttribute('4');
		batchAttributeShouldFail2.Type__c = '';
		Staff_Profile_Attribute__c batchAttributeShouldSucceed1 = createTestStaffProfileAttribute('5');
		Staff_Profile_Attribute__c batchAttributeShouldSucceed2 = createTestStaffProfileAttribute('6');
		ShiftTesting.insertBulkAndVerifyFailures(
				new List<SObject> {batchAttributeShouldFail1, batchAttributeShouldSucceed1, batchAttributeShouldFail2, batchAttributeShouldSucceed2},
				new List<String> {ShiftExceptions.FIELD_MISSING_EXCEPTION_TEXT, null, ShiftExceptions.FIELD_MISSING_EXCEPTION_TEXT, null}
		);

		// Test 4: verify that updating a Type to null fails
		attributeShouldSucceed.Type__c = null;
		ShiftTesting.expectUpdateExceptionContains(attributeShouldSucceed, ShiftExceptions.FIELD_MISSING_EXCEPTION_TEXT);

		// Test 5: verify that a valid update succeeds
		batchAttributeShouldSucceed1.Type__c = STAFF_PROFILE_ATTRIBUTE_TYPE_TESTING + '2';
		update batchAttributeShouldSucceed1;
	}
}