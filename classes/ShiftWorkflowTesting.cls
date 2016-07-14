// Provides functionality for testing workflows, as well as a reference implementation used to
// drive development of ShiftWorkflow itself.
public class ShiftWorkflowTesting {

	public virtual class Expector {
		public String identifier;
		public SObject state;

		public Expector(String identifier, SObject state) {
			this.identifier = identifier;
			this.state = state;
		}

		public ShiftTesting.TaskExpector expectTask(String expectSubject) {
			List<ShiftTesting.TaskExpector> tasks = getAllTasks();
			ShiftTesting.TaskExpector taskExpectorForSubject;
			for (ShiftTesting.TaskExpector taskExpector : tasks) {
				if (taskExpector.task.Subject == expectSubject) {
					System.assert(taskExpectorForSubject == null, 'found more than one task with subject: ' + expectSubject);
					taskExpectorForSubject = taskExpector;
				}
			}

			System.assert(taskExpectorForSubject != null);
			return taskExpectorForSubject;
		}

		public ShiftTesting.TaskExpector expectAndCompleteNewTask(String expectName) {
			return expectTask(expectName).
				expectNotStarted().
				updateComplete();
		}

		public ShiftTesting.TaskExpector expectAndCompleteNewTask(String expectName, String expectTeam) {
			return expectTask(expectName).
				expectTeam(expectTeam).
				expectNotStarted().
				updateComplete();
		}

		public Expector expectOpenTaskCount(Integer expect) {
			Integer act = [
				SELECT COUNT() 
				FROM Task
				WHERE 
					Workflow_Identifier__c = :identifier AND
					WhatId = :state.Id AND
					IsClosed = FALSE
			];
			System.assertEquals(expect, act);
			return this;
		}

		public Expector insertTaskDirect(String subject, String team, Date holdUntilDate) {
			insert new Task(
				WhatId = state.Id,
				Subject = subject,
				Team__c = team,
				Workflow_Identifier__c = identifier,
				Hold_Until__c = holdUntilDate
			);
			return this;
		}

		public Expector insertTaskDirect(String subject, String team) {
			return insertTaskDirect(subject, team, null);
		}

		public List<ShiftTesting.TaskExpector> getAllTasks () {
			List<Task> tasks = [
				SELECT 
					Id, Status, Team__c, Region_ID__c, Workflow_Identifier__c, 
          			Workflow_Version__c, WhatId, Subject
				FROM Task 
				WHERE Workflow_Identifier__c = :identifier AND WhatId = :state.Id
			];

			List<ShiftTesting.TaskExpector> expectors = new List<ShiftTesting.TaskExpector>();
			for (Task task : tasks) {
				expectors.add(new ShiftTesting.TaskExpector(task));
			}

			return expectors;
		}

		public Expector expectTaskStatusCounts (List<ShiftTesting.TaskExpector> taskExpectors, Map<String, Integer> expectedTaskStatusesToCount) {
			Map<String, Integer> actualTaskStatusToCount = new Map<String, Integer> ();

			for (ShiftTesting.TaskExpector taskExpector : taskExpectors) {
				String status = taskExpector.task.Status;
				Integer count = actualTaskStatusToCount.get(status);
				if (count == null){
					count = 0;
				} 

				actualTaskStatusToCount.put(status, count + 1);
			}

			System.assertEquals(expectedTaskStatusesToCount, actualTaskStatusToCount);

			return this;
		}
	}
	
	public static final String TEST_IDENTIFIER = 'test-object1-workflow';
	@TestVisible static final Integer TEST_VERSION = 1;

	@TestVisible static final String TASK_TEST1 = 'test task1';
	@TestVisible static final String TASK_TEST2 = 'test task2';
	@TestVisible static final String TASK_TEST3A = 'test task3a';
	@TestVisible static final String TASK_TEST3B = 'test task3b';
	@TestVisible static final String TASK_TEST4 = 'test task4';

	@TestVisible static final String TEAM_TEAM1 = 'test team1';
	@TestVisible static final String TEAM_TEAM2 = 'test team2';
	@TestVisible static final String TEAM_TEAM3 = 'test team3';
	@TestVisible static final String TEAM_TEAM4 = 'test team4';

	@TestVisible static final Integer INT64_F1_EXPECT_VAL = 1;
	@TestVisible static final Integer INT64_F1_FAIL_VAL = 2;

	@TestVisible static final String TEST_TEXT_FIND = 'find-value';
	@TestVisible static final String TEST_TEXT_REPLACE = 'replace-value';

	@TestVisible static Boolean simulateFailures = true;

	// Must be inserted by test setup code
	@TestVisible static final Region__c TEST_REGION = new Region__c(
		Name = 'workflow testing region',
		Shift_Key__c = 'testing/workflow',
		Timezone__c = ShiftTesting.REGION_TIMEZONE_TESTING
	);

	// A workflow representing the following flow:
	//
	//	- Node0 ready --> fire Task1
	//
	//	- Task1 complete --> Node1 made ready
	//
	//	- Node1 ready --> fire Task2
	//
	//	- Task2 complete --> Node2 made ready
	//
	//	- Node2 ready --> fire Task3a, Task3b
	//
	//	- Task3a complete --> Node3a made ready
	//	- Task3b complete --> Node3b made ready
	// 
	// 	- Node3a AND Node3b ready --> fire Task4 and run Test4Completer
	//
	//	- Task4 complete -- Node4 made ready 
	//
	// The implementation generates errors under certain conditions in order to test coverage of
	// error generation.
	class TestObject1WorkflowInstance extends ShiftWorkflow.AbstractInstance {
		final Set<Id> test4Completions = new Set<Id>();

		public TestObject1WorkflowInstance() { 
			super(Test_Object1__c.class, TEST_IDENTIFIER, TEST_VERSION); 
			startTaskOnFields(TASK_TEST1, TEAM_TEAM1, Schema.Test_Object1__c.Workflow_Node0__c);
			setFieldOnTask(Schema.Test_Object1__c.Workflow_Node1__c, TASK_TEST1);
			startTaskOnFields(TASK_TEST2, TEAM_TEAM2, Schema.Test_Object1__c.Workflow_Node1__c);
			setFieldOnTask(Schema.Test_Object1__c.Workflow_Node2__c, TASK_TEST2);
			startActionOnFields(
				actionList(
					actionAddTask(TASK_TEST3A, TEAM_TEAM3),
					actionAddTask(TASK_TEST3B, TEAM_TEAM3)
				),
				Schema.Test_Object1__c.Workflow_Node2__c
			);
			setFieldOnTask(Schema.Test_Object1__c.Workflow_Node3a__c, TASK_TEST3A);
			setFieldOnTask(Schema.Test_Object1__c.Workflow_Node3b__c, TASK_TEST3B);
			startActionOnFields(
				actionList(actionAddTask(TASK_TEST4, TEAM_TEAM4), new Test4Completer()),
				Schema.Test_Object1__c.Workflow_Node3a__c,
				Schema.Test_Object1__c.Workflow_Node3b__c
			);
			setFieldOnTask(Schema.Test_Object1__c.Workflow_Node4__c, TASK_TEST4);
		}

		void setTest4Completions() {
			for (Id id : test4Completions) {
				Test_Object1__c obj = (Test_Object1__c) getStateUpdate(id);
				obj.Int64_F1__c = INT64_F1_EXPECT_VAL;
			}
		}

		void setTestErrors() {
			if (!simulateFailures) {
				return;
			}
			List<Test_Object1__c> l = [
				SELECT Id, Int64_F1__c
				FROM Test_Object1__c
				WHERE Id IN :errorTargets.keySet()
			];
			for (Test_Object1__c o : l) {
				if (o.Int64_F1__c == INT64_F1_FAIL_VAL) {
					errorTargets.get(o.Id).addError('testing-error-target');
				}
			}
		}

		protected override void handleUpdates() {
			super.handleUpdates();
			setTest4Completions();
			setTestErrors();
			for (Task t : tasks) {
				t.Region_ID__c = TEST_REGION.Id;
			}
		}

		public override void stateObjectsUpdated(Map<Id, SObject> oldStates, List<SObject> newStates) {
			for (SObject newState : newStates) {
				String s = ((Test_Object1__c) newState).Text_F1__c;
				if (s == TEST_TEXT_FIND) {
					Test_Object1__c o = (Test_Object1__c) getStateUpdate(newState.Id);
					o.Text_F1__c = TEST_TEXT_REPLACE;
				}
			}
			super.stateObjectsUpdated(oldStates, newStates);
		}
	}

	// adds the id of the updated state object to test4Completions, to ensure
	// that handleUpdates() is called correctly (admittedly the end result
	// effected there could just as easily be done directly here).
	class Test4Completer implements ShiftWorkflow.Action {
		public void execute(SObject state, ShiftWorkflow.Instance instance) {
			((TestObject1WorkflowInstance) instance).test4Completions.add(state.id);
		}
	}

	public static void loadWorkflows() { 
		ShiftWorkflow.registerInstanceType(TEST_IDENTIFIER, TestObject1WorkflowInstance.class); 
	}
}