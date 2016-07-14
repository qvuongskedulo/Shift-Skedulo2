public class ShiftContacts {
	@TestVisible
	static final string ERROR_ACCOUNT_HAS_CONTACT = 'Cannot create contact: Account already has a contact';

	static void updateAccounts(List<Contact> oldContacts, List<Contact> newContacts) {
		Map<Id, Account> accounts = new Map<Id, Account>();
		List<Contact> contacts = new List<Contact>();
		if (newContacts != null) {
			contacts.addAll(newContacts);
		}
		if (oldContacts != null) {
			contacts.addAll(oldContacts);
		}
		for (Contact contact : contacts) {
			Id acctId = contact.AccountId;
			if (acctId != null && accounts.get(acctId) == null) {
				accounts.put(acctId, new Account(Id = acctId));
			}
		}
		update accounts.values();
	}

	static void normalizePhoneNumbers(List<Contact> contacts) {
		for (Contact c: contacts) {
			c.Normalized_Phone__c = ShiftUtil.normalizePhone(c.Phone);
			c.Normalized_MobilePhone__c = ShiftUtil.normalizePhone(c.MobilePhone);
			c.Normalized_HomePhone__c = ShiftUtil.normalizePhone(c.HomePhone);
			c.Normalized_OtherPhone__c = ShiftUtil.normalizePhone(c.OtherPhone);
			c.Normalized_AssistantPhone__c = ShiftUtil.normalizePhone(c.AssistantPhone);
		}
	}

	static void validateAccountsHaveNoContacts(List<Contact> contacts) {
		Set<Id> allAccountIds = new Set<Id>();
		for (Contact contact: contacts) {
			allAccountIds.add(contact.AccountId);
		}
		Set<Id> nonCommunityAccountIds = ShiftAccounts.selectNonCommunityAccountIds(allAccountIds);

		// Build map of accounts to contacts, and check for multiple contacts being added to same account
		// Ignore contacts which are being added to the community account.
		Map<Id, Contact> accountContactMap = new Map<Id, Contact>();
		for (Contact contact : contacts) {
			Id acctId = contact.AccountId;
			if (nonCommunityAccountIds.contains(acctId)) {
				if (!accountContactMap.containsKey(acctId)) {
					accountContactMap.put(acctId, contact);
				} else {
					contact.addError(ERROR_ACCOUNT_HAS_CONTACT);
				}
			}
		}

		// check the accounts to see if they already have contacts
		List<AggregateResult> accountsInError = [
				SELECT AccountId
				FROM Contact
				WHERE
					AccountId IN :accountContactMap.keySet() AND
					Account.Shift_Key__c != :ShiftConstants.ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY
				GROUP BY AccountId
		];
		for (AggregateResult result : accountsInError) {
			accountContactMap.get((Id) result.get('AccountId')).addError(ERROR_ACCOUNT_HAS_CONTACT);
		}
	}

	static void validateAccountsBeforeMovingContacts(Map<Id,Contact> oldMap, Map<Id,Contact> newMap) {
		Set<Id> allAccountIds = new Set<Id>();
		Map<Id, Contact> movedMap = new Map<Id, Contact>();

		// only care about contacts which were moved to another account
		for (Contact newContact : newMap.values()) {
			if (newContact.AccountId != null &&
				oldMap.get(newContact.Id).AccountId != newContact.AccountId) {
				movedMap.put(newContact.Id, newContact);
				allAccountIds.add(newContact.AccountId);
			}
		}

		// We only care about contacts which are being moved to non-community accounts
		// There is no need to filter them out of movedMap as they won't be checked
		Set<Id> accountIds = ShiftAccounts.selectNonCommunityAccountIds(allAccountIds);

		List<Contact> existingContacts = [
				SELECT AccountId, Id
				FROM Contact
				WHERE AccountId IN :accountIds
		];
		Set<Id> conflictAccountIds = new Set<Id>();
		for (Contact existing : existingContacts) {
			if (!movedMap.containsKey(existing.Id)) {
				conflictAccountIds.add(existing.AccountId);
			}
		}
		// now error out any contacts which can't be moved.
		for (Contact contact: movedMap.values()) {
			if (conflictAccountIds.contains(contact.AccountId)) {
				contact.addError(ERROR_ACCOUNT_HAS_CONTACT);
			}
		}
	}

	static void validateIncentive(Map<Id, Contact> oldMap, Map<Id, Contact> newMap) {
	  for (Contact contact : newMap.values()) {
	    if (oldMap.get(contact.Id).Incentive_ID__c != null && contact.Incentive_ID__c != oldMap.get(contact.Id).Incentive_ID__c) {
	      contact.addError('Attempt to change Incentive_ID__c from ' + oldMap.get(contact.Id).Incentive_ID__c + ' to ' + contact.Incentive_ID__c);
	    }
	  }
	}

	public static void beforeInsert(List<Contact> newContacts) {
		// This check has to be done before insert, because if it is done after insert, the after update account
		// trigger will try to merge the contacts together.
		validateAccountsHaveNoContacts(newContacts);
		normalizePhoneNumbers(newContacts);
	}

	public static void beforeUpdate(Map<Id,Contact> oldMap, Map<Id,Contact> newMap) {
		// This check has to be done before update, because if it is done after update, the after update account
		// trigger will try to merge the contacts together.
		validateAccountsBeforeMovingContacts(oldMap, newMap);
		validateIncentive(oldMap, newMap);
		normalizePhoneNumbers(newMap.values());
	}

	public static void afterUpdate(List<Contact> newContacts, Map<Id,Contact> oldMap) {
		updateAccounts(oldMap.values(), newContacts);
	}

	public static void afterInsert(List<Contact> newContacts) {
		updateAccounts(null, newContacts);
	}

	public static void afterDelete(List<Contact> oldContacts) {
		updateAccounts(oldContacts, null);
	}
}