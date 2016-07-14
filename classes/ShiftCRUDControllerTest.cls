@IsTest
private with sharing class ShiftCRUDControllerTest {	

	@TestSetup static void setup() { ShiftTesting.setup(); }

	static List<Account> getAccountList(Integer n) {
		List<Account> accounts = new List<Account>();
		for (Integer i = 0; i < n; i++) {
			accounts.add(ShiftTesting.createAccount());
		}
		return accounts;
	}

	static List<Account> getInsertedAccountList(Integer n) {
		List<Account> accounts = getAccountList(n);
		insert accounts;
		return accounts;
	}

	static void setupRestContext(String op, Object data) {
		RestRequest req = new RestRequest();
		req.requestURI = 'ShiftCRUD?'+ShiftCRUDController.PARAM_OPERATION+'='+op;
		System.debug('Setting up rest context with request URI: ' + req.requestURI);
		req.addParameter(ShiftCRUDController.PARAM_OPERATION, op);
		req.httpMethod = 'POST';
		req.requestBody = Blob.valueOf(JSON.serialize(data));

		RestResponse resp = new RestResponse();

		RestContext.request = req;
		RestContext.response = resp;
	}

	static ShiftCRUDController.OperationResponse getAndCheckResponseOfPost() {
		ShiftCRUDController.OperationResponse response = ShiftCRUDController.doPost(); //TODO test against contents of response?
		System.assertEquals(200, RestContext.response.statusCode);
		System.assertEquals(null, response.error);
		return response;
	}

	static void expectCRUDError(ShiftCRUDController.CRUDError error, String expErrorType, String expMessageSubstring) {
		System.assert(error != null);
		System.assertEquals(expErrorType, error.errorType);
		System.assert(error.message.contains(expMessageSubstring));
	}

	static List<Database.SaveResult> deserializeAndCheckSaveResults(String data, Integer expectedSize) {
		List<Database.SaveResult> saveResults = (List<Database.SaveResult>)JSON.deserializeStrict(data, List<Database.SaveResult>.class);
		System.assertEquals(expectedSize, saveResults.size());
		for (Database.SaveResult result : saveResults) {
			System.assertEquals(true, result.isSuccess());
		}
		return saveResults;
	}

	static List<Id> getIdList(List<SObject> objects) {
		List<Id> ids = new List<Id>();
		for (SObject obj : objects) {
			ids.add(obj.Id);
		}
		return ids;
	}

	@IsTest
	static void testCreateSObjects() {
		List<Account> accounts = getAccountList(5);
		ShiftCRUDController.CreateSObjectsRequest req = new ShiftCRUDController.CreateSObjectsRequest();
		req.objects = accounts;

		setupRestContext(ShiftCRUDController.OP_CREATE, req);
		ShiftCRUDController.OperationResponse response = getAndCheckResponseOfPost();

		ShiftCRUDController.CreateSObjectsResult result = (ShiftCRUDController.CreateSObjectsResult)response.result;
		System.assertEquals(accounts.size(), result.results.size());
		for (Database.SaveResult r : result.results) {
		  System.assertEquals(true, r.isSuccess());
		}
		for (Account a : accounts) {
			System.assertEquals(1, [SELECT COUNT() FROM Account WHERE Name = :a.Name]);
		}
	}

	@IsTest
	static void testReadSObjects() {
		List<Account> accounts = getInsertedAccountList(5);
		Map<Id, Account> accountMap = new Map<Id, Account>();
		accountMap.putAll(accounts);
		Set<Id> ids = accountMap.keySet();
		ShiftCRUDController.ReadSObjectsRequest req = new ShiftCRUDController.ReadSObjectsRequest();
		req.type = 'Account';
		req.ids = new List<Id>(ids);

		setupRestContext(ShiftCRUDController.OP_READ, req);
		ShiftCRUDController.OperationResponse response = getAndCheckResponseOfPost();

		ShiftCRUDController.ReadSObjectsResult result = (ShiftCRUDController.ReadSObjectsResult)response.result;
		System.assertEquals(ids.size(), result.results.size());
		for (SObject obj : result.results) {
			Account accountForCrossCheck = accountMap.get(obj.Id);
			System.assertEquals(accountForCrossCheck.Name, ((Account) obj).Name);
		}
	}

	@IsTest
	static void testUpdateSObjects() {
		List<Account> accounts = getInsertedAccountList(5);

		for (Account a : accounts) {
			a.Name = 'BARFOO Test';
		}
		ShiftCRUDController.UpdateSObjectsRequest req = new ShiftCRUDController.UpdateSObjectsRequest();
		req.objects = accounts;
		setupRestContext(ShiftCRUDController.OP_UPDATE, req);
		ShiftCRUDController.OperationResponse response = getAndCheckResponseOfPost();

		ShiftCRUDController.UpdateSObjectsResult result = (ShiftCRUDController.UpdateSObjectsResult)response.result;
		System.assertEquals(accounts.size(), result.results.size());
		for (Database.SaveResult r : result.results) {
			System.assertEquals(true, r.isSuccess());
		}

		System.AssertEquals(accounts.size(), [SELECT COUNT() FROM Account WHERE Name = 'BARFOO Test']);
	}

	@IsTest
	static void testDeleteSObjects() {
		List<Account> accounts = getInsertedAccountList(5);
		List<Id> ids = getIdList(accounts);

		ShiftCRUDController.DeleteSObjectsRequest req = new ShiftCRUDController.DeleteSObjectsRequest();
		req.ids = ids;
		setupRestContext(ShiftCRUDController.OP_DELETE, req);
		ShiftCRUDController.OperationResponse response = getAndCheckResponseOfPost();

		ShiftCRUDController.DeleteSObjectsResult result = (ShiftCRUDController.DeleteSObjectsResult)response.result;
		System.assertEquals(ids.size(), result.results.size());
		for (Database.DeleteResult r : result.results) {
			System.assertEquals(true, r.isSuccess());
		}

		System.assertEquals(0, [SELECT COUNT() FROM USER WHERE Id IN :ids]);
	}

	@IsTest
	static void testNoOpParam() {
		List<Account> accounts = getAccountList(5);
		ShiftCRUDController.CreateSObjectsRequest req = new ShiftCRUDController.CreateSObjectsRequest();
		req.objects = accounts;

		setupRestContext(ShiftCRUDController.OP_CREATE, req);
		RestContext.request.addParameter(ShiftCRUDController.PARAM_OPERATION, null); // Overwrite parameter
		ShiftCRUDController.OperationResponse response = ShiftCRUDController.doPost();
		System.assertEquals(200, RestContext.response.statusCode);
		expectCRUDError(response.error, ShiftCRUDController.ShiftCRUDException.class.getName(), ShiftCRUDController.MISSING_PARAM_PREFIX);
	}

	@IsTest
	static void testNonCRUDOpParam() {
		List<Account> accounts = getAccountList(5);
		ShiftCRUDController.CreateSObjectsRequest req = new ShiftCRUDController.CreateSObjectsRequest();
		req.objects = accounts;

		setupRestContext(ShiftCRUDController.OP_CREATE, req);
		RestContext.request.addParameter(ShiftCRUDController.PARAM_OPERATION, 'not CRUD op');
		ShiftCRUDController.OperationResponse response = ShiftCRUDController.doPost();
		System.assertEquals(200, RestContext.response.statusCode);
		expectCRUDError(response.error, ShiftCRUDController.ShiftCRUDException.class.getName(), ShiftCRUDController.BAD_PARAM_PREFIX);
	}
}