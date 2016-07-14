public class ShiftAccounts{
	@TestVisible static final string ERROR_TOO_MANY_CONTACTS = 'Account has more than 3 contacts combined';
	@TestVisible static final string ERROR_CONTACT_CONFLICT = 'Contacts have conflict: ';

	public static Set<Id> selectNonCommunityAccountIds(Set<Id> accountIds){
		List<Account> accounts = [
				SELECT Id
				FROM Account
				WHERE
					Id IN :accountIds AND
					Shift_Key__c != :ShiftConstants.ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY
		];
		return new Map<Id,Account>(accounts).keySet();
	}

	static void mergeAccountContacts(Map<Id, Account> newMap) {

		// Order by created date because we want the oldest contact to be treated as the master contact for the merge.
		// We can't pull MailingAddress here because any account updates from a class which is using API version
		// older than v30 will throw a column not found error on MailingAddress.
		List<Contact> contactsForAccounts = [
				SELECT
					Id, Name, Email, Phone, AccountId, Analytics_ID__c, Merged_Analytics_IDs__c,
					MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, Incentive_ID__c
				FROM Contact
				WHERE
					AccountId IN :newMap.keySet() AND
					Account.Shift_Key__c != :ShiftConstants.ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY
				ORDER BY CreatedDate ASC
		];

		// map each accountId to a list of contacts for each account that has been updated.
		Map<Id, List<Contact>> accountContacts = new Map<Id, List<Contact>>();
		for (Contact contact : contactsForAccounts) {
			if (!accountContacts.containsKey(contact.AccountId)) {
				accountContacts.put(contact.AccountId, new List<Contact>{ contact });
			} else {
				accountContacts.get(contact.AccountId).add(contact);
			}
		}

		// try to merge any contacts where we need to
		for (Id accountId : accountContacts.keySet()) {
			List<Contact> contacts = accountContacts.get(accountId);
			if (contacts.size() == 1) {
				continue;
			}
			try {
				mergeContacts(contacts, newMap.get(accountId).Primary_Contact_ID__c);
			} catch (Exception e) {
				newMap.get(accountId).addError(e);
			}
		}
	}

	static void mergeContacts(List<Contact> contacts, Id primaryContactId){
		// don't want to merge more than 3 records together right now.
		if (contacts.size() > 3) {
			throw new ShiftException(ERROR_TOO_MANY_CONTACTS);
		}

		Map<Id,Contact> contactMap = new Map<Id,Contact>(contacts);
		// We need to check these fields for conflicts
		String name;
		Set<String> emails = new Set<String>();
		Set<String> craigslistEmails = new Set<String>();
		Set<String> phones = new Set<String>();
		Set<Id> incentiveIds = new Set<Id>();
		// this one is a list to preserve order
		List<String> analyticsIds = new List<String>();
		AddressHolder addressHolder;

		for (Contact contact : contacts) {
			if (name == null) {
				name = contact.Name;
			} else if (!name.equals(contact.Name)) {
				throw new ShiftException(ERROR_CONTACT_CONFLICT + 'Name');
			}

			if (!String.isBlank(contact.Email)) {
				if (contact.Email.contains('@sale.craigslist.org')) {
					craigslistEmails.add(contact.Email);
				} else {
					emails.add(contact.Email);
				}
			}

			if (!String.isBlank(contact.Phone)) {
				phones.add(ShiftUtil.normalizePhone(contact.Phone));
			}

			if (!String.isBlank(contact.Analytics_ID__c)) {
				analyticsIds.add(contact.Analytics_ID__c);
			}
			if (!String.isBlank(contact.Merged_Analytics_IDs__c)) {
				analyticsIds.addAll(contact.Merged_Analytics_IDs__c.split(','));
			}

			if (contact.Incentive_ID__c != null) {
				incentiveIds.add(contact.Incentive_ID__c);
			}

			// If more than one contact we are merging has an address set, throw an error and let the user deconflict
			// all the fields on the address.
			AddressHolder currentAddress = new AddressHolder(contact);
			if (!currentAddress.isEmpty()) {
				if (addressHolder != null) {
					throw new ShiftException(ERROR_CONTACT_CONFLICT + 'Address');
				}
				addressHolder = currentAddress;
			}
		}

		if (primaryContactId == null) {
			primaryContactId = contacts.get(0).Id;
		}
		Contact master = new Contact(Id = primaryContactId);

		// Make sure there is only one important email address accross all the contacts we are merging
		// Ensure that non-craigslist email is retained during merge. Extra craigslist emails can be thrown out.
		if (emails.size() > 1) {
			throw new ShiftException(ERROR_CONTACT_CONFLICT + 'Emails:' + String.join(new List<String>(emails),','));
		} else if (emails.size() == 1) {
			master.Email = emails.iterator().next();
		} else if (craigslistEmails.size() > 0) {
			master.Email = craigslistEmails.iterator().next();
		}

		if (phones.size() > 1) {
			throw new ShiftException(ERROR_CONTACT_CONFLICT + 'Phones:' + String.join(new List<String>(phones),','));
		} else if (phones.size() == 1) {
			master.Phone = phones.iterator().next();
		}

		if (incentiveIds.size() > 1) {
			throw new ShiftException(ERROR_CONTACT_CONFLICT + 'Incentive IDs:' + String.join(new List<Id>(incentiveIds),','));
		} else if (incentiveIds.size() == 1) {
			master.Incentive_ID__c = incentiveIds.iterator().next();
		}

		if (analyticsIds.size() > 0) {
			Set<String> analyticsIdSet = new Set<String>();
			String masterAnalyticsId = contactMap.get(master.Id).Analytics_ID__c;
			if (masterAnalyticsId == null) {
				masterAnalyticsId = analyticsIds.remove(0);
			}
			analyticsIdSet.add(masterAnalyticsId);

			// remove any possible duplicates
			List<String> finalMergedIds = new List<String>();
			for (String analyticsId : analyticsIds) {
				if (analyticsIdSet.add(analyticsId)) {
					finalMergedIds.add(analyticsId);
				}
			}

			master.Merged_Analytics_IDs__c = String.join(finalMergedIds, ',');
		}

		if (addressHolder != null) {
			addressHolder.populateContact(master);
		}

		// Merge using Ids so any fields which weren't pulled in the initial query can be merged as well
		List<Id> contactIds = new List<Id>();
		for (Contact contact : contacts) {
			if (contact.Id == master.Id) {
				continue;
			}
			contactIds.add(contact.Id);
		}
		Database.merge(master, contactIds);
	}

	static void updateAccountNamesAndPrimaryContact(Map<Id, Account> newMap) {
		List<Contact> contacts = [
				SELECT Id, FirstName, LastName, AccountId
				FROM Contact
				WHERE
					AccountId IN :newMap.keySet() AND
					Account.Shift_Key__c != :ShiftConstants.ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY
		];

		Map<Id, List<Contact>> accountIdToContacts = new Map<Id, List<Contact>>();
		for (Contact contact : contacts) {
			Account account = newMap.get(contact.AccountId);

			List<String> nameParts = new List<String>();
			if (String.isNotEmpty(contact.FirstName)) {
				nameParts.add(contact.FirstName);
			}
			if (String.isNotEmpty(contact.LastName)) {
				nameParts.add(contact.LastName);
			}
			account.Name = String.join(nameParts, ' ');

			if (accountIdToContacts.get(account.Id) == null) {
				accountIdToContacts.put(account.Id, new List<Contact>());
			}
			accountIdToContacts.get(account.Id).add(contact);
		}

		// Only update primary contact if there is a single contact on the account...otherwise it is likely
		// the account is in the middle of a merge and we do not want to override the existing primary contact.
		for (Id accountId : accountIdToContacts.keySet()) {
			if (accountIdToContacts.get(accountId).size() == 1) {
				newMap.get(accountId).Primary_Contact_ID__c = accountIdToContacts.get(accountId)[0].Id;
			}
		}

		Set<Id> contactRemovedIds = new Set<Id>(newMap.keySet());
		contactRemovedIds.removeAll(accountIdToContacts.keySet());
		for (Id accountId : contactRemovedIds) {
			newMap.get(accountId).Primary_Contact_ID__c = null;
		}
	}

	static void triggerOpportunityUpdates(Set<Id> accountIds) {
		update [SELECT Id FROM Opportunity WHERE AccountId IN :accountIds];
	}

	public static void beforeUpdate(List<Account> accounts, Map<Id, Account> newMap){
		updateAccountNamesAndPrimaryContact(newMap);
	}

	public static void afterUpdate(List<Account> accounts, Map<Id, Account> newMap) {
		triggerOpportunityUpdates(newMap.keySet());
		mergeAccountContacts(newMap);
	}

	class AddressHolder {
		String street;
		String city;
		String state;
		String postalCode;
		String country;

		AddressHolder(Contact contact) {
			this.street = contact.MailingStreet;
			this.city = contact.MailingCity;
			this.state = contact.MailingState;
			this.postalCode = contact.MailingPostalCode;
			this.country = contact.MailingCountry;
		}

		void populateContact(Contact contact) {
			contact.MailingStreet = street;
			contact.MailingCity = city;
			contact.MailingState = state;
			contact.MailingPostalCode = postalCode;
			contact.MailingCountry = country;
		}

		boolean isEmpty() {
			return
				String.isBlank(street) &&
				String.isBlank(city) &&
				String.isBlank(state) &&
				String.isBlank(postalCode) &&
				String.isBlank(country);
		}
	}
}