@IsTest public class ShiftWorkflowTest {
	@TestSetup static void setup() { 
		ShiftTesting.setup(); 
		insert ShiftWorkflowTesting.TEST_REGION;
	}

	@IsTest static void testWorkflow() {
		Test_Object1__c t = new Test_Object1__c(Workflow_Node0__c = true);
		insert t;
		t.Text_F1__c = ShiftWorkflowTesting.TEST_TEXT_FIND;
		update t;
		System.assertEquals(ShiftWorkflowTesting.TEST_TEXT_REPLACE, [SELECT Text_F1__c FROM Test_Object1__c WHERE Id = :t.Id].Text_F1__c);
		ShiftWorkflowTesting.Expector e = new ShiftWorkflowTesting.Expector(ShiftWorkflowTesting.TEST_IDENTIFIER, t);
		insert new Task(Subject = 'ignored-by-workflows');
		e.expectTask(ShiftWorkflowTesting.TASK_TEST1).
			expectTeam(ShiftWorkflowTesting.TEAM_TEAM1).
			expectRegion(ShiftWorkflowTesting.TEST_REGION.Id).
			expectWorkflowIdentifier(ShiftWorkflowTesting.TEST_IDENTIFIER).
			expectWorkflowVersion(ShiftWorkflowTesting.TEST_VERSION).
			updateComplete();
		e.expectAndCompleteNewTask(ShiftWorkflowTesting.TASK_TEST2, ShiftWorkflowTesting.TEAM_TEAM2);
		e.expectOpenTaskCount(2);
		e.expectAndCompleteNewTask(ShiftWorkflowTesting.TASK_TEST3A, ShiftWorkflowTesting.TEAM_TEAM3);
		e.expectOpenTaskCount(1);
		e.expectAndCompleteNewTask(ShiftWorkflowTesting.TASK_TEST3B, ShiftWorkflowTesting.TEAM_TEAM3);
		e.expectAndCompleteNewTask(ShiftWorkflowTesting.TASK_TEST4, ShiftWorkflowTesting.TEAM_TEAM4);
		e.expectOpenTaskCount(0);
		t = [
			SELECT
				Workflow_Node1__c,
				Workflow_Node2__c,
				Workflow_Node3a__c,
				Workflow_Node3b__c,
				Workflow_Node4__c,
				Int64_F1__c
			FROM Test_Object1__c
			WHERE Id = :t.Id
		];
		System.assert(t.Workflow_Node1__c);
		System.assert(t.Workflow_Node2__c);
		System.assert(t.Workflow_Node3a__c);
		System.assert(t.Workflow_Node3b__c);
		System.assert(t.Workflow_Node4__c);
		System.assertEquals(ShiftWorkflowTesting.INT64_F1_EXPECT_VAL, t.Int64_F1__c);
	}

	private static Boolean containsTaskWithSubject(List<ShiftWorkflowsController.TaskDetail> taskDetails, String taskSubject) {
		for (ShiftWorkflowsController.TaskDetail taskDetail : taskDetails){
			if (taskDetail.taskSubject == taskSubject){
				return true;
			}
		}

		return false;
	}

	private static void doHoldUntilDateTest(String taskSubject, Date holdUntilDate, String assertionMessage, Boolean taskShouldBeFound) {
		Test_Object1__c t = new Test_Object1__c();
		insert t;

		ShiftWorkflowTesting.Expector e = new ShiftWorkflowTesting.Expector(ShiftWorkflowTesting.TEST_IDENTIFIER, t);
		e.insertTaskDirect(taskSubject, ShiftWorkflowTesting.TEAM_TEAM1, holdUntilDate);

		Test.setCurrentPage(Page.ShiftWorkflows);
		ApexPages.currentPage().getParameters().put(ShiftWorkflowsController.PARAM_WORKFLOW_IDENTIFIER, ShiftWorkflowTesting.TEST_IDENTIFIER);
		ShiftWorkflowsController c = new ShiftWorkflowsController();
		List<ShiftWorkflowsController.TaskDetail> taskDetails = c.getTasks();

		System.assertEquals(containsTaskWithSubject(taskDetails, taskSubject), taskShouldBeFound, assertionMessage);		
	}

	@IsTest static void testThatTaskWithFutureHoldDateShouldNotBeFound() {
		doHoldUntilDateTest('FutureTask', Date.today() + 2, 'Task with future hold date was found.', false);
	}

	@IsTest static void testThatTaskWithNullHoldDateShouldBeFound() {
		doHoldUntilDateTest('NoHoldDateTask', null, 'Task with null hold date was not found.', true);
	}

	@IsTest static void testThatTaskWithPastHoldDateShouldBeFound () {
		doHoldUntilDateTest('PastTask', Date.today() - 2, 'Task with past hold date was not found.', true);
	}

	static void assertErrorTargetException(DmlException ex) {
		if (ex.getMessage().contains('testing-error-target')) {
			return;
		}
		throw ex;
	}

	@IsTest static void testErrorTargetOnUpdate() {
		Test_Object1__c t = new Test_Object1__c();
		insert t;
		t.Workflow_Node4__c = true;
		t.Int64_F1__c = ShiftWorkflowTesting.INT64_F1_FAIL_VAL;
		try {
			update t;
			System.assert(false, 'expected failure');
		} catch (DmlException ex) {
			assertErrorTargetException(ex);
		}
	}

	@IsTest static void testErrorTargetOnTaskCompletion() {
		Test_Object1__c t = new Test_Object1__c();
		t.Int64_F1__c = ShiftWorkflowTesting.INT64_F1_FAIL_VAL;
		ShiftWorkflowTesting.simulateFailures = false;
		try {
			insert t;
		} finally {
			ShiftWorkflowTesting.simulateFailures = true;
		}
		ShiftWorkflowTesting.Expector e = new ShiftWorkflowTesting.Expector(ShiftWorkflowTesting.TEST_IDENTIFIER, t);
		e.insertTaskDirect(ShiftWorkflowTesting.TASK_TEST1, ShiftWorkflowTesting.TEAM_TEAM1);
		try {
			e.expectAndCompleteNewTask(ShiftWorkflowTesting.TASK_TEST1);
			System.assert(false, 'expected failure');
		} catch (DmlException ex) {
			assertErrorTargetException(ex);
		}
	}

	@IsTest static void testCoverageForWorkflowsController() {
		Test_Object1__c t = new Test_Object1__c(Workflow_Node0__c = true);
		insert t;
		ShiftWorkflowTesting.Expector e = new ShiftWorkflowTesting.Expector(ShiftWorkflowTesting.TEST_IDENTIFIER, t);
		Id taskId = e.expectTask(ShiftWorkflowTesting.TASK_TEST1).task.Id;
		Test.setCurrentPage(Page.ShiftWorkflows);
		ApexPages.currentPage().getParameters().put(ShiftWorkflowsController.PARAM_WORKFLOW_IDENTIFIER, ShiftWorkflowTesting.TEST_IDENTIFIER);
		ShiftWorkflowsController c = new ShiftWorkflowsController();
		c.getTasks(); 
		c.doUpdateOptions();
		c.getWorkflowIdentifierSelectOptions();
		c.getRegionSelectOptions();
		c.getTeamSelectOptions();
		c.taskIdToClaim = taskId;
		c.doClaim();
		Test.setCurrentPage(Page.ShiftWorkflowTask);
		ApexPages.currentPage().getParameters().put('id', taskId);
		new ShiftWorkflowTaskComponentController().doComplete();
	}
}