@IsTest
class ShiftContactsTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	static void expectMultipleContactsFailure(List<Contact> l, Boolean isInsert) {
		if (isInsert) {
			ShiftTesting.expectInsertExceptionContains(l, ShiftContacts.ERROR_ACCOUNT_HAS_CONTACT);
		} else {
			ShiftTesting.expectUpdateExceptionContains(l, ShiftContacts.ERROR_ACCOUNT_HAS_CONTACT);
		}
	}

	static void assertPrimaryContactOnAccount(Id contactId, Id accountId) {
		Account a = [SELECT Primary_Contact_ID__c from Account where Id = :accountId];
		System.assertEquals(contactId, a.Primary_Contact_ID__c);
	}

	@IsTest
	static void testDisallowMultipleAccountContacts() {
		// test failure on two contacts inserted in separate transactions
		Account a1 = ShiftTesting.createAccount();
		insert a1;
		Contact a1C1 = ShiftTesting.createContact(a1);
		insert a1C1;
		Contact a1C2 = ShiftTesting.createContact(a1);
		expectMultipleContactsFailure(new List<Contact>{a1C2}, true);
		a1C1.AccountId = a1.Id;
		update a1C1; // check idempotency ok

		// test failure when updating a contact to point at an account with an
		// existing contact
		Contact a1C3 = ShiftTesting.createContact();
		insert a1C3;
		a1C3.AccountId = a1.Id;
		expectMultipleContactsFailure(new List<Contact>{a1C3}, false);

		// test failure when inserting two contacts for same account in same
		// batch
		Account a2 = ShiftTesting.createAccount();
		insert a2;
		List<Contact> l2 = new List<Contact> {
				ShiftTesting.createContact(a2),
				ShiftTesting.createContact(a2)
		};
		expectMultipleContactsFailure(l2, true);
	}

	@IsTest
	static void testCommunityAccountAllowsMultipleContacts() {
		Account a1 = ShiftTesting.selectCommunityAccount();
		Integer beforeCount = [
				SELECT COUNT()
				FROM Contact
				WHERE Account.Shift_Key__c = :ShiftConstants.ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY
		];

		insert new List<Contact> {
				ShiftTesting.createContact(a1),
				ShiftTesting.createContact(a1)
		};

		Integer afterCount = [
				SELECT COUNT()
				FROM Contact
				WHERE Account.Shift_Key__c = :ShiftConstants.ACCOUNT_SHIFT_KEY_SHIFT_COMMUNITY
		];
		System.assertEquals(2, afterCount - beforeCount);
	}

	@IsTest
	static void testInsertContactToCommunityAndExisting() {
		Account a1 = ShiftTesting.createAccount();
		insert a1;
		Account a2 = ShiftTesting.selectCommunityAccount();

		List<Contact> contacts = new List<Contact> {
				ShiftTesting.createContact(a1),
				ShiftTesting.createContact(a2),
				ShiftTesting.createContact(a2)
		};
		insert contacts;

		Contact c1 = ShiftTesting.createContact(a1);
		ShiftTesting.expectInsertExceptionContains(c1, ShiftContacts.ERROR_ACCOUNT_HAS_CONTACT);
	}

	@IsTest
	static void testPrimaryContactOnInsertContact() {
		Account a1 = ShiftTesting.createAccount();
		insert a1;
		Contact c1 = ShiftTesting.createContact(a1);
		insert c1;
		assertPrimaryContactOnAccount(c1.Id, a1.Id);
	}

	@IsTest
	static void testPrimaryContactOnMoveContact() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1,a2};
		Contact c1 = ShiftTesting.createContact(a1);
		insert c1;

		c1.AccountId = a2.Id;
		update c1;
		assertPrimaryContactOnAccount(c1.Id, a2.Id);
		assertPrimaryContactOnAccount(null, a1.Id);
	}

	@IsTest
	static void testPrimaryContactOnDeleteContact() {
		Account a1 = ShiftTesting.createAccount();
		insert a1;
		Contact c1 = ShiftTesting.createContact(a1);
		insert c1;
		delete c1;
		assertPrimaryContactOnAccount(null, a1.Id);
	}

	@IsTest
	static void testPrimaryContactOnMergeAccounts() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		insert new List<Contact>{c1, c2};

		Database.MergeResult result = Database.merge(a1, a2);
		System.assert(result.isSuccess(), result.getErrors());
		assertPrimaryContactOnAccount(c1.Id, a1.Id);
	}

	@IsTest
	static void testIncentiveImmutability() {
		Incentive_Program__c program = ShiftTesting.createIncentiveProgram();
		insert program;
		Incentive__c incentive1 = ShiftTesting.createIncentive('token1', program.Id);
		Incentive__c incentive2 = ShiftTesting.createIncentive('token2', program.Id);
		insert new List<Incentive__c>{incentive1, incentive2};

		Contact contact = ShiftTesting.createContact();
		contact.Incentive_ID__c = incentive1.Id;
		insert contact;
		contact.Incentive_ID__c = incentive2.Id;
		ShiftTesting.expectUpdateExceptionContains(contact, 'Attempt to change Incentive_ID__c from ' + incentive1.Id + ' to ' + incentive2.Id);
	}
}