public class ShiftLeads {
	static final Set<String> INQUIRY_TYPES_TO_SKIP_FOR_CASE_CREATION = new Set<String>{
		ShiftConstants.LEAD_INQUIRY_TYPE_HOT_BUYER,
		ShiftConstants.LEAD_INQUIRY_TYPE_OFF_SALE_PENDING,
		ShiftConstants.LEAD_INQUIRY_TYPE_OFF_COMING_SOON
	};

	static final Set<String> CONTACT_METHODS_TO_SKIP_FOR_CASE_CREATION = new Set<String>{
		ShiftConstants.LEAD_CONTACT_METHOD_VOICE
	};

	static final Set<String> INQUIRY_TYPES_TO_SET_OPPORTUNITY_STAGE_NAME_TO_LEAD = new Set<String>{
		ShiftConstants.LEAD_INQUIRY_TYPE_OFF_COMING_SOON,
		ShiftConstants.LEAD_INQUIRY_TYPE_OFF_SALE_PENDING,
		ShiftConstants.LEAD_INQUIRY_TYPE_VEHICLE_QUESTION
	};

	static String CONVERTED_STATUS_MASTER_LABEL;
	static String getConvertedStatusMasterLabel() {
		if (CONVERTED_STATUS_MASTER_LABEL == null) {
			CONVERTED_STATUS_MASTER_LABEL = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel;
		}
		return CONVERTED_STATUS_MASTER_LABEL;
	}

	static Map<Id, Contact> createContactIdToContactMap(Set<String> emails, Set<String> phoneNumbers) {
		return new Map<Id, Contact>([
			SELECT
				Id, CreatedDate, Email, Phone, HomePhone, MobilePhone,
				AssistantPhone, OtherPhone, Account.Id, MailingStreet,
				MailingCity, MailingState, MailingPostalCode, MailingCountry,
				Normalized_Phone__c, Normalized_HomePhone__c, Normalized_MobilePhone__c, Normalized_AssistantPhone__c, Normalized_OtherPhone__c
			FROM Contact
			WHERE
				Email IN :emails OR
				Normalized_Phone__c IN :phoneNumbers OR
				Normalized_HomePhone__c IN :phoneNumbers OR
				Normalized_MobilePhone__c IN :phoneNumbers OR
				Normalized_AssistantPhone__c IN :phoneNumbers OR
				Normalized_OtherPhone__c IN :phoneNumbers
		]);
	}

	static Map<Id, Id> createBuyerOpportunityIdToAccountIdMap(List<Opportunity> buyerOpportunities) {
		Map<Id, Id> buyerOpportunityIdToAccountId = new Map<Id, Id>();
		for (Opportunity buyerOpportunity : buyerOpportunities) {
			buyerOpportunityIdToAccountId.put(buyerOpportunity.Id, buyerOpportunity.Account.Id);
		}

		// Get a list of vehicle orders associated with our buyer opportunities
		// that have an open purchase.
		List<Vehicle_Order__c> vehicleOrdersWithOpenPurchases = [
			SELECT Buyer_Opportunity_ID__c
			FROM Vehicle_Order__c
			WHERE
				Buyer_Opportunity_ID__c IN :buyerOpportunityIdToAccountId.keySet() AND
				Vehicle_Purchased__c = TRUE AND
				Vehicle_Returned__c = FALSE
		];

		// Remove buyer opportunities from the map if they have open purchases.
		for (Vehicle_Order__c vehicleOrder : vehicleOrdersWithOpenPurchases) {
			buyerOpportunityIdToAccountId.remove(vehicleOrder.Buyer_Opportunity_ID__c);
		}

		return buyerOpportunityIdToAccountId;
	}

	static Map<Id, Opportunity> createAccountIdToExistingBuyerOpportunityMap(List<Contact> contacts) {
		Set<String> accountIds = new Set<String>();
		for (Contact contact : contacts) {
			accountIds.add(contact.Account.Id);
		}

		Id buyerRecordTypeId = ShiftOpportunities.getBuyerRecordTypeId();
		List<Opportunity> buyerOpportunities = [
			SELECT
				Id, Account.Id, CreatedDate, HTTP_Referrer__c, UTM_Campaign__c,
				UTM_Content__c, UTM_Source__c, UTM_Term__c, UTM_Medium__c
			FROM Opportunity
			WHERE RecordTypeId = :buyerRecordTypeId AND Account.Id IN :accountIds
		];
		Map<Id, Id> buyerOpportunityIdToAccountId = createBuyerOpportunityIdToAccountIdMap(buyerOpportunities);
		Set<Id> accountIdsWithExistingBuyerOpportunities = new Set<Id>(buyerOpportunityIdToAccountId.values());

		Map<Id, Opportunity> accountIdToExistingBuyerOpportunity = new Map<Id, Opportunity>();
		for (Opportunity buyerOpportunity : buyerOpportunities) {
			Id accountId = buyerOpportunityIdToAccountId.get(buyerOpportunity.Id);
			if (!accountIdsWithExistingBuyerOpportunities.contains(accountId)) {
				continue;
			}
			Opportunity existingBuyerOpportunity = accountIdToExistingBuyerOpportunity.get(accountId);
			if (existingBuyerOpportunity == null || buyerOpportunity.CreatedDate < existingBuyerOpportunity.CreatedDate) {
				accountIdToExistingBuyerOpportunity.put(accountId, buyerOpportunity);
			}
		}
		return accountIdToExistingBuyerOpportunity;
	}

	static Map<String, Contact> createEmailToContactMap(List<Contact> contacts) {
		Map<String, Contact> emailToContact = new Map<String, Contact>();
		for (Contact contact : contacts) {
			if (contact.Email == null) {
				continue;
			}
			if (emailToContact.containsKey(contact.Email)) {
				if (contact.CreatedDate < emailToContact.get(contact.Email).CreatedDate) {
					emailToContact.put(contact.Email, contact);
				}
			} else {
				emailToContact.put(contact.Email, contact);
			}
		}
		return emailToContact;
	}

	static Map<String, Contact> createPhoneNumberToContactMap(List<Contact> contacts) {
		Map<String, Contact> phoneNumberToContact = new Map<String, Contact>();
		for (Contact contact : contacts) {
			Set<String> contactPhoneNumbers = new Set<String>();
			contactPhoneNumbers.add(contact.Normalized_Phone__c);
			contactPhoneNumbers.add(contact.Normalized_HomePhone__c);
			contactPhoneNumbers.add(contact.Normalized_MobilePhone__c);
			contactPhoneNumbers.add(contact.Normalized_AssistantPhone__c);
			contactPhoneNumbers.add(contact.Normalized_OtherPhone__c);
			for (String phoneNumber : contactPhoneNumbers) {
				if (phoneNumber == null) {
					continue;
				}
				if (phoneNumberToContact.containsKey(phoneNumber)) {
					if (contact.CreatedDate < phoneNumberToContact.get(phoneNumber).CreatedDate) {
						phoneNumberToContact.put(phoneNumber, contact);
					}
				} else {
					phoneNumberToContact.put(phoneNumber, contact);
				}
			}
		}
		return phoneNumberToContact;
	}

	static Database.LeadConvert createLeadConvert(
			Lead lead,
			Map<String, Contact> emailToContact,
			Map<String, Contact> phoneNumberToContact,
			Map<Id, Opportunity> accountIdToExistingBuyerOpportunity) {
		Database.LeadConvert leadConvert = new Database.LeadConvert();
		leadConvert.setConvertedStatus(getConvertedStatusMasterLabel());
		leadConvert.setLeadId(lead.Id);
		leadConvert.setOpportunityName(lead.Name);

		Set<Contact> matchingContacts = new Set<Contact>();
		if (lead.Email != null && emailToContact.containsKey(lead.Email)) {
			Contact match = emailToContact.get(lead.Email);
			matchingContacts.add(new Contact(Id = match.Id, CreatedDate = match.CreatedDate, Account = new Account(Id = match.Account.Id)));
		}
		String normalizedLeadPhone = ShiftUtil.normalizePhone(lead.Phone);
		if (normalizedLeadPhone != null && phoneNumberToContact.containsKey(normalizedLeadPhone)) {
			Contact match = phoneNumberToContact.get(normalizedLeadPhone);
			matchingContacts.add(new Contact(Id = match.Id, CreatedDate = match.CreatedDate, Account = new Account(Id = match.Account.Id)));
		}

		Contact oldestContact;
		for (Contact matchingContact : matchingContacts) {
			if (oldestContact == null || matchingContact.CreatedDate < oldestContact.CreatedDate) {
				oldestContact = matchingContact;
			}
		}
		if (oldestContact != null) {
			leadConvert.setContactId(oldestContact.Id);
			leadConvert.setAccountId(oldestContact.Account.Id);
			if (accountIdToExistingBuyerOpportunity.containsKey(oldestContact.Account.Id)) {
				leadConvert.setDoNotCreateOpportunity(true);
			}
		}
		return leadConvert;
	}

	static Vehicle_Interest__c createVehicleInterestFromCraigslistData(Lead lead, Map<String, Id> craigslistEmailToVehicleId, Map<String, Id> craigslistPhoneNumberToVehicleId) {
		if (lead.Craigslist_Listing_Email_Inquiry__c != null) {
			return new Vehicle_Interest__c(Vehicle_ID__c = craigslistEmailToVehicleId.get(lead.Craigslist_Listing_Email_Inquiry__c));
		}
		if (lead.Craigslist_Listing_Phone_Number_Inquiry__c != null) {
			return new Vehicle_Interest__c(Vehicle_ID__c = craigslistPhoneNumberToVehicleId.get(lead.Craigslist_Listing_Phone_Number_Inquiry__c));
		}
		return null;
	}

	static Vehicle_Interest__c createVehicleInterestFromVinInquiry(Lead lead, Map<String, Id> vinToVehicleId) {
		if (lead.VIN_Inquiry__c != null) {
			return new Vehicle_Interest__c(Vehicle_ID__c = vinToVehicleId.get(lead.VIN_Inquiry__c));
		}
		return null;
	}

	static Vehicle_Interest__c createVehicleInterest(Lead lead, Map<String, Id> vinToVehicleId, Map<String, Id> craigslistEmailToVehicleId, Map<String, Id> craigslistPhoneNumberToVehicleId) {
		Vehicle_Interest__c vehicleInterest;
		if (lead.LeadSource == ShiftConstants.LEAD_SOURCE_CRAIGSLIST) {
			vehicleInterest = createVehicleInterestFromCraigslistData(lead, craigslistEmailToVehicleId, craigslistPhoneNumberToVehicleId);
		} else {
			vehicleInterest = createVehicleInterestFromVinInquiry(lead, vinToVehicleId);
		}
		if (vehicleInterest == null || vehicleInterest.Vehicle_ID__c == null) {
			return null;
		}
		if (lead.Inquiry_Type__c == ShiftConstants.LEAD_INQUIRY_TYPE_OFF_COMING_SOON) {
			vehicleInterest.Contact_When_Available_For_Sale__c = true;
		} else if (lead.Inquiry_Type__c == ShiftConstants.LEAD_INQUIRY_TYPE_OFF_SALE_PENDING) {
			vehicleInterest.Contact_If_Deposit_Falls_Through__c = true;
		}
		return vehicleInterest;
	}

	static Test_Drive__c createTestDrive(Lead lead) {
		if (lead.Inquiry_Type__c != ShiftConstants.LEAD_INQUIRY_TYPE_TEST_DRIVE &&
				lead.Inquiry_Type__c != ShiftConstants.LEAD_INQUIRY_TYPE_TEST_DRIVE_REJECTED) {
			return null;
		}
		return new Test_Drive__c(
			Test_Drive_By_ID__c = ShiftUsers.unownedUserId(),
			Original_Time_Requested__c = lead.Requested_Test_Drive_Time__c,
			Location__c = lead.Requested_Test_Drive_Location__c,
			Selected_Geolocation__latitude__s = lead.Requested_Test_Drive_Geolocation__latitude__s,
			Selected_Geolocation__longitude__s = lead.Requested_Test_Drive_Geolocation__longitude__s
		);
	}

	static Boolean checkForConversionFailures(List<Database.LeadConvertResult> leadConvertResults, Map<Id, Lead> leadIdToLead) {
		Boolean hadConversionFailure = false;
		for (Database.LeadConvertResult leadConvertResult : leadConvertResults) {
			Database.Error[] errors = leadConvertResult.getErrors();
			if (errors.size() > 0) {
				Lead lead = leadIdToLead.get(leadConvertResult.getLeadId());
				for (Database.Error error : errors) {
					lead.addError('Failed to auto-convert lead ' + lead.Id + ' with error: ' + error.getMessage());
				}
				hadConversionFailure = true;
			}
		}
		return hadConversionFailure;
	}

	// Returns an object that represents a buyer/vehicle pair.
	// This method can be used to determine whether two vehicle interests represent
	// the same buyer expressing interest in the same vehicle.
	static Object vehicleInterestTestKey(Id buyerOpportunityId, Id vehicleId) {
		return new Vehicle_Interest__c(
			Buyer_Opportunity_ID__c = buyerOpportunityId,
			Vehicle_ID__c = vehicleId
		);
	}

	static Map<Object, Id> createVehicleInterestTestKeyToIdMap(List<Opportunity> opportunities, List<Id> vehicleIds) {
		// If a vehicle interest already exists for a given buyer opportunity/vehicle
		// pair, we don't want to create another, so we fetch the existing vehicle interests.
		List<Vehicle_Interest__c> existingVehicleInterests = [
			SELECT Buyer_Opportunity_ID__c, Vehicle_ID__c
			FROM Vehicle_Interest__c
			WHERE Buyer_Opportunity_ID__c IN :opportunities AND Vehicle_ID__c IN :vehicleIds
		];

		// Even though we didn't select Id in the above query, it's included in the resulting
		// vehicle interests, so we can't just turn the List into a Set and call `contains` to
		// find existing buyer/vehicle pairs. Instead, we create vehicle interest test keys,
		// which contain only buyer and vehicle IDs, map them to their vehicle interest IDs,
		// and use that map to detect existing buyer/vehicle pairs.
		Map<Object, Id> vehicleInterestTestKeyToId = new Map<Object, Id>();
		for (Vehicle_Interest__c vehicleInterest : existingVehicleInterests) {
			vehicleInterestTestKeyToId.put(
				vehicleInterestTestKey(vehicleInterest.Buyer_Opportunity_ID__c, vehicleInterest.Vehicle_ID__c),
				vehicleInterest.Id
			);
		}
		return vehicleInterestTestKeyToId;
	}

	static Map<Object, Case> createVehicleInterestTestKeyToCaseMap(List<Opportunity> opportunities, Map<String, Id> vinToVehicleId) {
		// If a case already exists for a given buyer opportunity/vehicle pair, we don't
		// want to create another, so we fetch the existing cases.
		List<Case> existingCases = [
			SELECT Opportunity_ID__c, VIN_Inquiry__c, Initial_Buyer_Outreach__c
			FROM Case
			WHERE Opportunity_ID__c IN :opportunities AND VIN_Inquiry__c IN :vinToVehicleId.keySet()
		];

		// Even though we didn't select Id in the above query, it's included in the resulting
		// cases, so we can't just turn the List into a Set and call `contains` to find
		// existing buyer/vehicle pairs. Instead, we create vehicle interest test keys,
		// which contain only buyer and vehicle IDs, map them to case IDs, and use that map
		// to detect existing buyer/vehicle pairs.
		Map<Object, Case> vehicleInterestTestKeyToCase = new Map<Object, Case>();
		for (Case supportCase : existingCases) {
			vehicleInterestTestKeyToCase.put(
				vehicleInterestTestKey(supportCase.Opportunity_ID__c, vinToVehicleId.get(supportCase.VIN_Inquiry__c)),
				supportCase
			);
		}
		return vehicleInterestTestKeyToCase;
	}

	static String createInitialBuyerOutreach(Lead lead) {
		String initialBuyerOutreach = DateTime.now() + '\n';
		initialBuyerOutreach += 'Source: ' + lead.LeadSource + '\n';
		initialBuyerOutreach += '\n';
		initialBuyerOutreach += Lead.Initial_Email_Content__c;
		return initialBuyerOutreach;
	}

	static Case createNewCase(Lead lead, Id opportunityId, Id contactId, Id vehicleId) {
		return new Case(
			ContactId = contactId,
			Craigslist_Listing_Email_Inquiry__c = lead.Craigslist_Listing_Email_Inquiry__c,
			Craigslist_Listing_Phone_Number_Inquiry__c = lead.Craigslist_Listing_Phone_Number_Inquiry__c,
			Initial_Buyer_Outreach__c = createInitialBuyerOutreach(lead),
			Inquiry_Type__c = lead.Inquiry_Type__c,
			Opportunity_ID__c = opportunityId,
			Origin = lead.Contact_Method__c,
			OwnerId = ShiftUsers.unownedUserId(),
			Requested_Test_Drive_Time__c = lead.Requested_Test_Drive_Time__c,
			Requested_Test_Drive_Location__c = lead.Requested_Test_Drive_Location__c,
			Source__c = lead.LeadSource,
			Vehicle_ID__c = vehicleId,
			VIN_Inquiry__c = lead.VIN_Inquiry__c
		);
	}

	static Case createUpdatedCase(Case existingCase, Lead lead) {
		String newInitialBuyerOutreach = existingCase.Initial_Buyer_Outreach__c + '\n';
		newInitialBuyerOutreach += '\n';
		newInitialBuyerOutreach += '- - - - - - - - - - - - - - - -\n';
		newInitialBuyerOutreach += '\n';
		newInitialBuyerOutreach += createInitialBuyerOutreach(lead);
		return new Case(
			Id = existingCase.Id,
			Initial_Buyer_Outreach__c = newInitialBuyerOutreach,
			Status = ShiftConstants.CASE_STATUS_NEEDS_ACTION
		);
	}

	static Map<Id, Vehicle_Interest__c> insertAndUpdateVehicleInterests(
			List<Database.LeadConvertResult> leadConvertResults,
			Map<Id, Lead> leadIdToLead,
			Map<Id, Opportunity> accountIdToExistingBuyerOpportunity,
			Map<String, Id> vinToVehicleId,
			Map<String, Id> craigslistEmailToVehicleId,
			Map<String, Id> craigslistPhoneNumberToVehicleId) {
		// These maps allow us to access existing vehicle interests associated with
		// a given buyer/vehicle pair.
		Map<Object, Id> vehicleInterestTestKeyToId = createVehicleInterestTestKeyToIdMap(accountIdToExistingBuyerOpportunity.values(), vinToVehicleId.values());

		List<Vehicle_Interest__c> vehicleInterestsToInsert = new List<Vehicle_Interest__c>();
		List<Vehicle_Interest__c> vehicleInterestsToUpdate = new List<Vehicle_Interest__c>();
		Map<Id, Vehicle_Interest__c> leadIdToVehicleInterest = new Map<Id, Vehicle_Interest__c>();
		for (Database.LeadConvertResult leadConvertResult : leadConvertResults) {
			Vehicle_Interest__c vehicleInterest = createVehicleInterest(leadIdToLead.get(leadConvertResult.getLeadId()), vinToVehicleId, craigslistEmailToVehicleId, craigslistPhoneNumberToVehicleId);
			if (vehicleInterest == null) {
				continue;
			}
			leadIdToVehicleInterest.put(leadConvertResult.getLeadId(), vehicleInterest);
			Id buyerOpportunityId = leadConvertResult.getOpportunityId();
			if (buyerOpportunityId == null) {
				buyerOpportunityId = accountIdToExistingBuyerOpportunity.get(leadConvertResult.getAccountId()).Id;
			}
			Object vehicleInterestTestKey = vehicleInterestTestKey(buyerOpportunityId, vehicleInterest.Vehicle_ID__c);
			Id existingVehicleInterestId = vehicleInterestTestKeyToId.get(vehicleInterestTestKey);
			if (existingVehicleInterestId == null) {
				vehicleInterest.Buyer_Opportunity_ID__c = buyerOpportunityId;
				vehicleInterestsToInsert.add(vehicleInterest);
			} else {
				vehicleInterest.Id = existingVehicleInterestId;
				vehicleInterestsToUpdate.add(vehicleInterest);
			}
		}
		insert vehicleInterestsToInsert;
		update vehicleInterestsToUpdate;
		return leadIdToVehicleInterest;
	}

	static Map<Id, Test_Drive__c> insertTestDrives(
			List<Database.LeadConvertResult> leadConvertResults,
			Map<Id, Lead> leadIdToLead,
			Map<Id, Vehicle_Interest__c> leadIdToVehicleInterest) {
		List<Test_Drive__c> testDrivesToInsert = new List<Test_Drive__c>();
		Map<Id, Test_Drive__c> leadIdToTestDrive = new Map<Id, Test_Drive__c>();
		for (Database.LeadConvertResult leadConvertResult : leadConvertResults) {
			Id leadId = leadConvertResult.getLeadId();
			Test_Drive__c testDrive = createTestDrive(leadIdToLead.get(leadId));
			if (testDrive == null) {
				continue;
			}
			testDrive.Vehicle_Interest_ID__c = leadIdToVehicleInterest.get(leadId).Id;
			leadIdToTestDrive.put(leadId, testDrive);
			testDrivesToInsert.add(testDrive);
		}
		insert testDrivesToInsert;
		return leadIdToTestDrive;
	}

	static void insertAndUpdateCases(
			List<Database.LeadConvertResult> leadConvertResults,
			Map<Id, Lead> leadIdToLead,
			Map<Id, Vehicle_Interest__c> leadIdToVehicleInterest,
			Set<Id> leadIdsWithNewTestDrives,
			Map<Id, Opportunity> accountIdToExistingBuyerOpportunity,
			Map<String, Id> vinToVehicleId) {
		// These maps allow us to access existing cases associated with a given buyer/vehicle pair.
		Map<Object, Case> vehicleInterestTestKeyToCase = createVehicleInterestTestKeyToCaseMap(accountIdToExistingBuyerOpportunity.values(), vinToVehicleId);

		List<Case> casesToInsert = new List<Case>();
		List<Case> casesToUpdate = new List<Case>();
		for (Database.LeadConvertResult leadConvertResult : leadConvertResults) {
			Lead lead = leadIdToLead.get(leadConvertResult.getLeadId());
			if (lead.LeadSource == ShiftConstants.LEAD_SOURCE_DRIVESHIFT && INQUIRY_TYPES_TO_SKIP_FOR_CASE_CREATION.contains(lead.Inquiry_Type__c)) {
				continue;
			}
			if (CONTACT_METHODS_TO_SKIP_FOR_CASE_CREATION.contains(lead.Contact_Method__c)) {
				continue;
			}
			Id buyerOpportunityId = leadConvertResult.getOpportunityId();
			Id vehicleId = vinToVehicleId.get(lead.VIN_Inquiry__c);
			if (buyerOpportunityId != null) {
				casesToInsert.add(createNewCase(lead, buyerOpportunityId, leadConvertResult.getContactId(), vehicleId));
				continue;
			}
			Vehicle_Interest__c vehicleInterest = leadIdToVehicleInterest.get(leadConvertResult.getLeadId());
			if (vehicleInterest == null) {
				continue;
			}
			buyerOpportunityId = accountIdToExistingBuyerOpportunity.get(leadConvertResult.getAccountId()).Id;
			Object vehicleInterestTestKey = vehicleInterestTestKey(buyerOpportunityId, vehicleInterest.Vehicle_ID__c);
			Case existingCase = vehicleInterestTestKeyToCase.get(vehicleInterestTestKey);


			// If a case exists, but we've just created a test drive from this lead,
			// we still want to create a new case.  See https://shift.phacility.com/T2551.
			if (existingCase == null || leadIdsWithNewTestDrives.contains(lead.Id)) {
				casesToInsert.add(createNewCase(lead, buyerOpportunityId, leadConvertResult.getContactId(), vehicleId));
			} else {
				casesToUpdate.add(createUpdatedCase(existingCase, lead));
			}
		}
		insert casesToInsert;
		update casesToUpdate;
	}

	static Boolean updatePhone(Lead lead, Contact contact) {
		Boolean wasUpdated = false;
		if (contact.Phone == null && lead.Phone != null) {
			contact.Phone = lead.Phone;
			wasUpdated = true;
		}
		if (contact.MobilePhone == null && lead.MobilePhone != null) {
			contact.MobilePhone = lead.MobilePhone;
			wasUpdated = true;
		}
		return wasUpdated;
	}

	static Boolean updateEmail(Lead lead, Contact contact) {
		Boolean wasUpdated = false;
		if (contact.Email == null && lead.Email != null) {
			contact.Email = lead.Email;
			wasUpdated = true;
		}
		return wasUpdated;
	}

	static Boolean updateOpportunity(Lead lead, Opportunity opportunity) {
		Boolean wasUpdated = false;
		Boolean allFieldsPresentInLead =
			lead.HTTP_Referrer__c != null &&
			lead.UTM_Campaign__c != null &&
			lead.UTM_Content__c != null &&
			lead.UTM_Source__c != null &&
			lead.UTM_Term__c != null &&
			lead.UTM_Medium__c != null;
		Boolean allFieldsNotPresentInOpportunity =
			opportunity.HTTP_Referrer__c == null &&
			opportunity.UTM_Campaign__c == null &&
			opportunity.UTM_Content__c == null &&
			opportunity.UTM_Source__c == null &&
			opportunity.UTM_Term__c == null &&
			opportunity.UTM_Medium__c == null;
		if (allFieldsNotPresentInOpportunity && allFieldsPresentInLead) {
			opportunity.HTTP_Referrer__c = lead.HTTP_Referrer__c;
			opportunity.UTM_Campaign__c = lead.UTM_Campaign__c;
			opportunity.UTM_Content__c = lead.UTM_Content__c;
			opportunity.UTM_Source__c = lead.UTM_Source__c;
			opportunity.UTM_Term__c = lead.UTM_Term__c;
			opportunity.UTM_Medium__c = lead.UTM_Medium__c;
			wasUpdated = true;
		}
		return wasUpdated;
	}

	static void updateRelatedObjects(List<Database.LeadConvertResult> leadConvertResults, Map<Id, Lead> leadIdToLead, Map<Id, Opportunity> accountIdToExistingBuyerOpportunity, Map<Id, Contact> contactIdToContact) {
		List<Contact> contactsToUpdate = new List<Contact>();
		List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
		Map<Id, Lead> opportunityIdToLead = new Map<Id, Lead>();
		for (Database.LeadConvertResult leadConvertResult : leadConvertResults) {
			Lead lead = leadIdToLead.get(leadConvertResult.getLeadId());
			Id opportunityId = leadConvertResult.getOpportunityId();
			if (opportunityId != null) {
				opportunityIdToLead.put(opportunityId, lead);
			}
			Contact contact = contactIdToContact.get(leadConvertResult.getContactId());
			Boolean contactWasUpdated = false;
			if (contact != null) {
				contactWasUpdated = updateEmail(lead, contact) || contactWasUpdated;
				contactWasUpdated = updatePhone(lead, contact) || contactWasUpdated;
				if (contactWasUpdated) {
					contactsToUpdate.add(contact);
				}
				Opportunity opportunity = accountIdToExistingBuyerOpportunity.get(contact.Account.Id);
				if (opportunity != null && updateOpportunity(lead, opportunity)) {
					opportunitiesToUpdate.add(opportunity);
				}
			}
		}
		update contactsToUpdate;
		update opportunitiesToUpdate;

		List<Opportunity> opportunitiesToUpdateStageToLead = new List<Opportunity>();
		for (Id opportunityId : opportunityIdToLead.keySet()) {
			Lead lead = opportunityIdToLead.get(opportunityId);
			if (lead.LeadSource == ShiftConstants.LEAD_SOURCE_DRIVESHIFT && INQUIRY_TYPES_TO_SET_OPPORTUNITY_STAGE_NAME_TO_LEAD.contains(lead.Inquiry_Type__c)) {
				opportunitiesToUpdateStageToLead.add(new Opportunity (
					Id = opportunityId,
					StageName = ShiftConstants.BUYER_OPPORTUNITY_STAGE_LEADS
				));
			}
		}

		update opportunitiesToUpdateStageToLead;
	}

	static void applyIncentives(List<Database.LeadConvertResult> leadConvertResults, Map<Id, Lead> leadIdToLead, Set<String> incentiveTokens) {
		List<Incentive__c> incentives = [SELECT Id, Token__c, Email__c FROM Incentive__c WHERE Token__c IN :incentiveTokens];
		Map<String, Incentive__c> incentiveTokenToIncentive = new Map<String, Incentive__c>();
		for (Incentive__c i : incentives) {
			incentiveTokenToIncentive.put(i.Token__c, i);
		}
		List<Applied_Incentive__c> appliedIncentives = new List<Applied_Incentive__c>();
		for (Database.LeadConvertResult leadConvertResult : leadConvertResults) {
			Lead lead = leadIdToLead.get(leadConvertResult.getLeadId());
			if (lead.Incentive_Token__c == null) {
				continue;
			}
			Incentive__c incentive = incentiveTokenToIncentive.get(lead.Incentive_Token__c);
			if (lead.Email == incentive.Email__c) {
				continue;
			}
			Id opportunityId = leadConvertResult.getOpportunityId();
			if (opportunityId == null) {
				continue;
			}
			appliedIncentives.add(new Applied_Incentive__c(
				Opportunity_ID__c = opportunityId,
				Incentive_ID__c = incentive.Id
			));
		}
		insert appliedIncentives;
	}

	static void autoConvertLeads(List<Lead> leads) {
		Map<Id, Lead> leadIdToLead = new Map<Id, Lead>();
		Set<String> emails = new Set<String>();
		Set<String> phoneNumbers = new Set<String>();
		Set<String> vins = new Set<String>();
		Set<String> craigslistEmails = new Set<String>();
		Set<String> craigslistPhoneNumbers = new Set<String>();
		Set<String> incentiveTokens = new Set<String>();
		for (Lead lead : leads) {
			leadIdToLead.put(lead.Id, lead);
			if (lead.Email != null) {
				emails.add(lead.Email);
			}
			if (lead.Phone != null) {
				phoneNumbers.add(ShiftUtil.normalizePhone(lead.Phone));
			}
			if (lead.VIN_Inquiry__c != null) {
				vins.add(lead.VIN_Inquiry__c);
			}
			if (lead.Craigslist_Listing_Email_Inquiry__c != null) {
				craigslistEmails.add(lead.Craigslist_Listing_Email_Inquiry__c);
			}
			if (lead.Craigslist_Listing_Phone_Number_Inquiry__c != null) {
				craigslistPhoneNumbers.add(lead.Craigslist_Listing_Phone_Number_Inquiry__c);
			}
			if (lead.Incentive_Token__c != null) {
				incentiveTokens.add(lead.Incentive_Token__c);
			}
		}

		Map<Id, Contact> contactIdToContact = createContactIdToContactMap(emails, phoneNumbers);
		// When converting a lead, we want to determine whether a contact, account, or opportunity
		// already exists for that lead. This map allows us to easily retrieve the existing
		// buyer opportunity for a given account ID, if one exists.
		Map<Id, Opportunity> accountIdToExistingBuyerOpportunity = createAccountIdToExistingBuyerOpportunityMap(contactIdToContact.values());
		List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();
		for (Lead lead : leads) {
			leadConverts.add(createLeadConvert(
				lead,
				createEmailToContactMap(contactIdToContact.values()),
				createPhoneNumberToContactMap(contactIdToContact.values()),
				accountIdToExistingBuyerOpportunity
			));
		}
		if (leadConverts.isEmpty()) {
			return;
		}

		List<Database.LeadConvertResult> leadConvertResults = Database.convertLead(leadConverts);
		Boolean hadConversionFailure = checkForConversionFailures(leadConvertResults, leadIdToLead);
		if (hadConversionFailure) {
			return;
		}

		updateRelatedObjects(leadConvertResults, leadIdToLead, accountIdToExistingBuyerOpportunity, contactIdToContact);
		applyIncentives(leadConvertResults, leadIdToLead, incentiveTokens);

		// If a lead contains a VIN Inquiry or Craigslist contact information,
		// we can create a vehicle interest. We need the vehicle ID associated
		// with that data in order to do so, so we create maps from that data
		// to the associated vehicle IDs.
		// Only vehicles associated with a seller opportunity in stage
		// "Prepare Car for Sale" or "Sell Car" are desired.
		List<Vehicle__c> vehicles = [
			SELECT Id, VIN__c, Craigslist_Listing_Email__c, Listing_Phone_Number__c
			FROM Vehicle__c
			WHERE
				(VIN__c IN :vins OR Craigslist_Listing_Email__c IN :craigslistEmails OR Listing_Phone_Number__c IN :craigslistPhoneNumbers) AND
				Seller_Opportunity_ID__r.StageName IN (:ShiftConstants.SELLER_OPPORTUNITY_STAGE_PREPARE, :ShiftConstants.SELLER_OPPORTUNITY_STAGE_SELL)
		];
		Map<String, Id> vinToVehicleId = new Map<String, Id>();
		Map<String, Id> craigslistEmailToVehicleId = new Map<String, Id>();
		Map<String, Id> craigslistPhoneNumberToVehicleId = new Map<String, Id>();
		for (Vehicle__c vehicle : vehicles) {
			if (vehicle.VIN__c != null) {
				System.assert(vinToVehicleId.put(vehicle.VIN__c, vehicle.Id) == null, 'multiple active vehicles with vin: ' + vehicle.VIN__c);
			}
			if (vehicle.Craigslist_Listing_Email__c != null) {
				System.assert(craigslistEmailToVehicleId.put(vehicle.Craigslist_Listing_Email__c, vehicle.Id) == null, 'multiple active vehicles with Craigslist email: ' + vehicle.Craigslist_Listing_Email__c);
			}
			if (vehicle.Listing_Phone_Number__c != null) {
				System.assert(craigslistPhoneNumberToVehicleId.put(vehicle.Listing_Phone_Number__c, vehicle.Id) == null, 'multiple active vehicles with Craigslist phone number: ' + vehicle.Listing_Phone_Number__c);
			}
		}

		// Test drives require a vehicle interest. When we create a test drive from
		// a lead, we need that lead's associated vehicle interest, so our vehicle
		// interest creation method returns a map from lead ID to vehicle interest.
		Map<Id, Vehicle_Interest__c> leadIdToVehicleInterest = insertAndUpdateVehicleInterests(leadConvertResults, leadIdToLead, accountIdToExistingBuyerOpportunity, vinToVehicleId, craigslistEmailToVehicleId, craigslistPhoneNumberToVehicleId);

		// We need to create additional cases for new test drives, so our test drive
		// creation method returns a map from lead ID to vehicle interest.
		Map<Id, Test_Drive__c> leadIdToTestDrive = insertTestDrives(leadConvertResults, leadIdToLead, leadIdToVehicleInterest);

		insertAndUpdateCases(leadConvertResults, leadIdToLead, leadIdToVehicleInterest, leadIdToTestDrive.keySet(), accountIdToExistingBuyerOpportunity, vinToVehicleId);
	}

	public static void afterInsert(List<Lead> newList) {
		autoConvertLeads(newList);
	}
}