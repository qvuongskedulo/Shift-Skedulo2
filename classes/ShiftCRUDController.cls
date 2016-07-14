@RestResource(urlMapping='/ShiftCRUD/*')
global with sharing class ShiftCRUDController {

	public static final String PARAM_OPERATION = 'operation';
	public static final String OP_CREATE       = 'create-sobjects';
	public static final String OP_READ         = 'read-sobjects';
	public static final String OP_UPDATE       = 'update-sobjects';
	public static final String OP_DELETE       = 'delete-sobjects';

	@TestVisible
	class ShiftCRUDException extends Exception {}
	
	@TestVisible
	class CRUDError {
		@TestVisible String errorType;
		@TestVisible String message;
		@TestVisible String stackTrace;
	}

	static CRUDError createCRUDError(Exception e) {
		CRUDError error = new CRUDError();
		error.errorType = e.getTypeName();
		error.message = e.getMessage();
		error.stackTrace = e.getStackTraceString();
		return error;
	}

	interface CRUDResult {} // cannot JSON.serialize generic Object

	global class OperationResponse {
		@TestVisible CRUDResult result;
		@TestVisible CRUDError error;
	}

	@TestVisible
	class CreateSObjectsRequest {
		@TestVisible List<SObject> objects;
	}

	@TestVisible
	class CreateSObjectsResult implements CRUDResult {
		@TestVisible List<Database.SaveResult> results;
	}

	@TestVisible
	class ReadSObjectsRequest {
		@TestVisible String type;
		@TestVisible List<Id> ids;
	}

	@TestVisible
	class ReadSObjectsResult implements CRUDResult {
		@TestVisible List<SObject> results;
	}

	@TestVisible
	class UpdateSObjectsRequest {
		@TestVisible List<SObject> objects;
	}

	@TestVisible
	class UpdateSObjectsResult implements CRUDResult {
		@TestVisible List<Database.SaveResult> results;
	}

	@TestVisible
	class DeleteSObjectsRequest {
		@TestVisible List<Id> ids;
	}

	@TestVisible
	class DeleteSObjectsResult implements CRUDResult {
		@TestVisible List<Database.DeleteResult> results;
	}

	static Object deserializeRequest(System.Type t) {
		return JSON.deserializeStrict(RestContext.request.requestBody.toString(), t);
	}

	static CreateSObjectsResult handleCreateSObjects() {
		CreateSObjectsRequest req = (CreateSObjectsRequest) deserializeRequest(CreateSObjectsRequest.class);
		CreateSObjectsResult res = new CreateSObjectsResult();
		res.results = Database.insert(req.objects);
		return res;
	}

	static SObjectType getSObjectType(String typeName) {
		SObjectType objType = Schema.getGlobalDescribe().get(typeName);
		if (objType == null) {
			throw new ShiftCRUDException('specified SObject type not found: '+typeName);
		}
		return objType;
	}

	static ReadSObjectsResult handleReadSObjects() {
		ReadSObjectsRequest data = (ReadSObjectsRequest) deserializeRequest(ReadSObjectsRequest.class);
		if (data.type == null) {
			throw new ShiftCRUDException('missing field in read request: "type"');
		}
		if (data.ids == null) {
		  throw new ShiftCRUDException('missing field in read request: "ids"');
		}

		String fieldListForSelect = String.join(new List<String>(getSObjectType(data.type).getDescribe().fields.getMap().keySet()), ', ');
		ReadSObjectsResult res = new ReadSObjectsResult();
		List<Id> bindVarIds = data.ids; // Database.query doesn't support fields in bind variables
		res.results = Database.query('SELECT '+fieldListForSelect+' FROM '+data.type+' WHERE Id IN :bindVarIds');
		return res;
	}

	static UpdateSObjectsResult handleUpdateSObjects() {
		UpdateSObjectsRequest req = (UpdateSObjectsRequest) deserializeRequest(UpdateSObjectsRequest.class);
		UpdateSObjectsResult res = new UpdateSObjectsResult();
		res.results = Database.update(req.objects);
		return res;
	}

	static DeleteSObjectsResult handleDeleteSObjects() {
		DeleteSObjectsRequest req = (DeleteSObjectsRequest) deserializeRequest(DeleteSObjectsRequest.class);
		DeleteSObjectsResult res = new DeleteSObjectsResult();
		res.results = Database.delete(req.ids);
		return res;
	}

	@TestVisible static final String MISSING_PARAM_PREFIX = 'missing parameter: ';
	@TestVisible static final String BAD_PARAM_PREFIX = 'Expected value for param "'+PARAM_OPERATION+'" to be one of ['+OP_CREATE+','+OP_READ+','+OP_UPDATE+','+OP_DELETE+'] but found: ';

	@HttpPost
	global static OperationResponse doPost() {
		OperationResponse resp = new OperationResponse();
		try {
			String op = RestContext.request.params.get(PARAM_OPERATION);
			if (op == null) {
				throw new ShiftCRUDException(MISSING_PARAM_PREFIX + PARAM_OPERATION);
			} else if (op.equals(OP_CREATE)) {
				resp.result = handleCreateSObjects();
			} else if (op.equals(OP_READ)) {
				resp.result = handleReadSObjects();
			} else if (op.equals(OP_UPDATE)) {
				resp.result = handleUpdateSObjects();
			} else if (op.equals(OP_DELETE)) {
				resp.result = handleDeleteSObjects();
			} else if (op.equals('testError')) {
				throw new ShiftCRUDException('Test Error');
			} else {
				throw new ShiftCRUDException(BAD_PARAM_PREFIX + op);
			}
		} catch (System.Exception e) {
			System.debug(e);
			resp.error = createCRUDError(e);
		}
		RestContext.response.statusCode = 200;
		return resp;
	}
}