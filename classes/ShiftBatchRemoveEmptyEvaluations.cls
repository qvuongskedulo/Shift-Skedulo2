// Removes empty evaluations incorrectly created as part of the migration
// (https://shift.phacility.com/T1396).
public class ShiftBatchRemoveEmptyEvaluations implements Database.Batchable<Evaluation__c> {
	
	public Iterable<Evaluation__c> start(Database.BatchableContext bc) {
		return (Iterable<Evaluation__c>) Database.getQueryLocator([
			SELECT Id, Next_Steps_After_Evaluation__c
			FROM Evaluation__c
			WHERE 
				Canceled__c != TRUE AND
				Evaluated_At__c = NULL AND
				Evaluated_By_ID__c = NULL AND 
				Location__c = NULL AND 
				Migration_Tree_ID__c != NULL AND 
				Scheduled_By_ID__c = NULL
		]);
	}

	public void execute(Database.BatchableContext bc, List<Evaluation__c> evals) {
		List<Evaluation__c> toDel = new List<Evaluation__c>();
		for (Evaluation__c eval : evals) {
			if (eval.Next_Steps_After_Evaluation__c == null) {
				toDel.add(eval);
			}
		}
		delete toDel;
		// not checking/failing on errors from emptyRecycleBin() since they'll
		// be removed by salesforce if we can't for some reason. The delete()
		// call above is the critical one for correctness and will fail fast.
		Database.emptyRecycleBin(toDel); 
	}

	public void finish(Database.BatchableContext bc) {}
}