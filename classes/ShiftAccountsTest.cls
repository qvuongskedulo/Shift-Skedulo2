@IsTest
class ShiftAccountsTest {
	@TestSetup static void setup() { ShiftTesting.setup(); }

	static void assertAccountNameEquals(Id accountId, String expected){
		Account a1 = [SELECT Name from Account where Id = :accountId];
		System.assertEquals(expected, a1.Name);
	}

	static void accountMergeExceptionExpected(Account a1, Account a2, String errorMessage, String expectedException) {
		try {
			Database.merge(a1, a2);
			System.assert(false, errorMessage);
		} catch(DmlException e) {
			ShiftTesting.expectExceptionContains(e, expectedException);
		}
	}

	static Contact selectContactForAccount(Id accountId) {
		return [
			SELECT
				Id, FirstName, LastName, Email, Phone,  AccountId, Analytics_ID__c, Merged_Analytics_IDs__c,
				MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
			FROM Contact
			WHERE AccountId = :accountId
		];
	}

	static Case createCase(Contact contact) {
		return new Case(
			ContactId = contact.Id,
			AccountId = contact.AccountId
		);
	}

	@IsTest
	static void testAccountUpdateNameOverridden() {
		Account a1 = ShiftTesting.createAccount();
		insert a1;

		Contact c1 = ShiftTesting.createContact(a1);
		insert c1;
		assertAccountNameEquals(a1.Id, c1.FirstName + ' ' + c1.LastName);

		a1.Name = 'foo2';
		update a1;
		assertAccountNameEquals(a1.Id, c1.FirstName + ' ' + c1.LastName);
	}

	@IsTest
	static void testContactLastNameOnly() {
		Account a1 = ShiftTesting.createAccount();
		insert a1;

		Contact c1 = ShiftTesting.createContact(a1);
		c1.FirstName = '';
		insert c1;

		assertAccountNameEquals(a1.Id, c1.LastName);
	}

	@IsTest
	static void testContactUpdate() {
		Account a1 = ShiftTesting.createAccount();
		insert a1;

		Contact c1 = ShiftTesting.createContact(a1);
		insert c1;

		c1.FirstName = 'Bar2';
		c1.LastName = 'Baz2';
		update c1;
		assertAccountNameEquals(a1.Id, 'Bar2 Baz2');
	}

	@IsTest
	static void testCommunityAccountName() {
		Account a1 = ShiftTesting.selectCommunityAccount();
		String accountName = a1.Name;

		Contact c1 = ShiftTesting.createContact(a1);
		insert c1;
		assertAccountNameEquals(a1.Id, accountName);

		c1.FirstName = 'Bar';
		update c1;
		assertAccountNameEquals(a1.Id, accountName);
	}

	@IsTest
	static void testMergingAccountsSingleContact() {
		// test a valid merge (only one contact total)
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact a1c1 = ShiftTesting.createContact(a1);
		insert a1c1;

		Database.MergeResult result = Database.merge(a1, a2);
		System.assert(result.isSuccess(), result.getErrors());
	}

	@IsTest
	static void testMergingAccountsMultipleContacts() {
		// test a valid merge (only one contact remains)
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);

		c1.Email = 'test@test.com';
		c1.MailingStreet = '123 Test Circle';
		c1.MailingCity = 'San Francisco';
		c1.MailingState = 'California';
		c1.MailingPostalCode = '12345';
		c1.MailingCountry = 'United States';
		c1.Analytics_ID__c = 'testing';
		c1.Phone = '223-456-7890';

		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		c2.Email = 'test@test.com';
		c2.Phone = '223.456.7890';

		insert new List<Contact>{c1, c2};
		insert new List<Case>{
				createCase(c1),
				createCase(c2)
		};

		Database.MergeResult result = Database.merge(a1, a2);
		System.assert(result.isSuccess(), result.getErrors());

		Contact merged = selectContactForAccount(a1.Id);

		System.assertEquals(c1.Email, merged.Email);
		System.assertEquals(ShiftUtil.normalizePhone(c2.Phone), ShiftUtil.normalizePhone(merged.Phone));
		System.assertEquals(c1.FirstName, merged.FirstName);
		System.assertEquals(c1.LastName, merged.LastName);
		System.assertEquals(c1.MailingStreet, merged.MailingStreet);
		System.assertEquals(c1.MailingCity, merged.MailingCity);
		System.assertEquals(c1.MailingState, merged.MailingState);
		System.assertEquals(c1.MailingPostalCode, merged.MailingPostalCode);
		System.assertEquals(c1.MailingCountry, merged.MailingCountry);
		System.assertEquals(c1.Analytics_ID__c, merged.Analytics_ID__c);
		assertAccountNameEquals(a1.Id, merged.FirstName + ' ' + merged.LastName);

		System.assertEquals(2, [SELECT COUNT() FROM Case WHERE ContactId = :merged.Id]);
	}

	@IsTest
	static void testMergingAccountsCraigslistSecondContact() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		// keep primary contact
		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		c1.Email = 'test@test.com';
		c2.Email = 'something@sale.craigslist.org';
		insert new List<Contact>{c1, c2};

		Database.MergeResult result = Database.merge(a1, a2);
		System.assert(result.isSuccess(), result.getErrors());

		Contact merged = selectContactForAccount(a1.id);

		System.assertEquals(c1.email, merged.Email);
	}

	@IsTest
	static void testMergingAccountsCraigslistFirstContact() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		// keep secondary contact
		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		c1.Email = 'something@sale.craigslist.org';
		c2.Email = 'test@test.com';
		insert new List<Contact>{c1, c2};

		Database.MergeResult result = Database.merge(a1, a2);
		System.assert(result.isSuccess(), result.getErrors());

		Contact merged = selectContactForAccount(a1.id);

		System.assertEquals(c2.email, merged.Email);
	}

	@IsTest
	static void testMergingAccountsEmailConflict() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		c1.Email = 'test@test.com';
		c2.Email = 'test@example.com';
		insert new List<Contact>{c1, c2};

		accountMergeExceptionExpected(a1, a2, 'Email conflict expected', ShiftAccounts.ERROR_CONTACT_CONFLICT + 'Email');
	}

	@IsTest
	static void testMergingAccountsPhoneConflict() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		c1.Phone = '123.456.7890';
		c2.Phone = '111.222.3333';
		insert new List<Contact>{c1, c2};

		accountMergeExceptionExpected(a1, a2, 'Phone conflict expected', ShiftAccounts.ERROR_CONTACT_CONFLICT + 'Phone');
	}

	@IsTest
	static void testMergingAccountsAddressConflict() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		c1.MailingStreet = '123 Test Circle';
		c2.MailingStreet = '456 Verify Drive';
		insert new List<Contact>{c1, c2};

		accountMergeExceptionExpected(a1, a2, 'Address conflict expected', ShiftAccounts.ERROR_CONTACT_CONFLICT + 'Address');
	}

	@IsTest
	static void testMergingAccountsMultipleAnalyticsIds() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		c1.Analytics_ID__c = 'abc';
		c2.Analytics_ID__c = '123';
		c1.Merged_Analytics_IDs__c = 'def,hij,lmnop';
		c2.Merged_Analytics_IDs__c = '111,222,333,4567890';
		insert new List<Contact>{c1, c2};

		Set<String> expectedMergedIds = new Set<String>();
		expectedMergedIds.add(c2.Analytics_ID__c);
		expectedMergedIds.addAll(c1.Merged_Analytics_IDs__c.split(','));
		expectedMergedIds.addAll(c2.Merged_Analytics_IDs__c.split(','));

		Database.merge(a1, a2);
		Contact merged = selectContactForAccount(a1.Id);

		System.assertEquals(c1.Analytics_ID__c, merged.Analytics_ID__c);
		expectedMergedIds.removeAll(merged.Merged_Analytics_IDs__c.split(','));
		System.assertEquals(0, expectedMergedIds.size());
	}

	@IsTest
	static void testMergingAccountsAddressSecondary() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c2.FirstName = c1.FirstName;
		c2.LastName = c1.LastName;
		c2.MailingStreet = '456 Verify Drive';
		insert new List<Contact>{c1, c2};

		Database.merge(a1, a2);
		Contact merged = selectContactForAccount(a1.Id);
		System.assertEquals(c2.MailingStreet, merged.MailingStreet);
	}

	@IsTest
	static void testMergingAccountsNoFirstName() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c1.FirstName = null;
		c2.FirstName = null;
		c2.LastName = c1.LastName;
		insert new List<Contact>{c1, c2};

		Database.MergeResult result = Database.merge(a1, a2);
		System.assert(result.isSuccess(), result.getErrors());

		Contact merged = selectContactForAccount(a1.id);
		System.assertEquals(c1.LastName, merged.LastName);
		System.assert(String.isBlank(merged.FirstName));
	}

	@IsTest
	static void testMergingAccountsOneEmptyFirstName() {
		Account a1 = ShiftTesting.createAccount();
		Account a2 = ShiftTesting.createAccount();
		insert new List<Account>{a1, a2};

		Contact c1 = ShiftTesting.createContact(a1);
		Contact c2 = ShiftTesting.createContact(a2);
		c1.FirstName = '';
		c2.LastName = c1.LastName;
		insert new List<Contact>{c1, c2};

		accountMergeExceptionExpected(a1, a2, 'Name Conflict Expected', ShiftAccounts.ERROR_CONTACT_CONFLICT + 'Name');
	}
}